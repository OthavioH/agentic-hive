import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Interpreted output from a harness CLI run.
final class HarnessOutputAnalysis {
  /// Creates an output analysis.
  const new({
    this.isAuthenticationError = false,
    this.isRateLimitError = false,
    this.errorMessage,
    this.metadata = const <String, Object?>{},
  });

  /// Whether the CLI output indicates missing or expired authentication.
  final bool isAuthenticationError;

  /// Whether the CLI output indicates rate limiting or exhausted quota.
  final bool isRateLimitError;

  /// Human-readable error message extracted from the CLI output.
  final String? errorMessage;

  /// Structured metadata extracted from the CLI output.
  final Map<String, Object?> metadata;
}

/// Abstract Template Method base for all agent harness nodes (ADR 0006).
abstract base class HarnessNode extends Node {
  /// Creates a harness node.
  const new({required this.resultContract, required this.agentPromptResolver});

  /// Port used to instruct and read the ADR 0003 result contract.
  final ResultContract resultContract;

  /// Port used to resolve an `agentId` into prompt text.
  final AgentPromptResolver agentPromptResolver;

  /// Builds the full prompt from an optional `agentId`,
  /// `additionalInstructions`, execution context, and result contract
  /// instructions.
  Future<Result<String>> buildPrompt(
    NodeExecutionContext context, {
    String? agentId,
    String? additionalInstructions,
  }) async {
    final sections = <String>[];

    final trimmedAgentId = agentId?.trim();
    if (trimmedAgentId != null && trimmedAgentId.isNotEmpty) {
      final agentResult = await agentPromptResolver.resolvePrompt(
        trimmedAgentId,
      );
      if (agentResult case FailureResult<String>(:final failure)) {
        return FailureResult(failure);
      }
      final agentPrompt = agentResult.valueOrNull!.trim();
      if (agentPrompt.isNotEmpty) {
        sections.add(agentPrompt);
      }
    }

    final trimmedInstructions = additionalInstructions?.trim();
    if (trimmedInstructions != null && trimmedInstructions.isNotEmpty) {
      sections.add(trimmedInstructions);
    }

    final contextBuffer = StringBuffer()
      ..writeln('## Execution Context')
      ..writeln('- Run ID: ${context.runId}')
      ..writeln('- Node ID: ${context.nodeId}')
      ..writeln('- Workspace: ${context.workspacePath}');
    if (context.inputs.isNotEmpty) {
      contextBuffer.writeln('- Inputs: ${context.inputs}');
    }
    sections.add(contextBuffer.toString().trimRight());

    final contractInstructions = resultContract.instructionsFor(context).trim();
    if (contractInstructions.isNotEmpty) {
      sections.add(contractInstructions);
    }

    return Success(sections.join('\n\n'));
  }

  /// Resolves the ADR 0003 result contract after a harness process exits 0.
  ///
  /// Exit code 0 without a submitted report is always a failure.
  Future<Result<NodeOutcome>> resolveResultContract(
    NodeExecutionContext context, {
    Map<String, Object?> extraData = const <String, Object?>{},
  }) async {
    final reportResult = await resultContract.readReport(context);
    if (reportResult case FailureResult<ResultContractReport?>(
      :final failure,
    )) {
      return FailureResult(failure);
    }

    final report = reportResult.valueOrNull;
    if (report == null) {
      return FailureResult(
        NodeExecutionFailure(
          'Harness "$typeId" exited with code 0 without submitting a '
          'result contract report.',
          exitCode: 0,
        ),
      );
    }

    final outputLabel = switch (report.status) {
      ResultContractStatus.success ||
      ResultContractStatus.approved => NodeOutput.onSuccess,
      ResultContractStatus.failure ||
      ResultContractStatus.changesRequested => NodeOutput.onFailure,
    };

    return Success(
      NodeOutcome(
        outputLabel: outputLabel,
        data: <String, Object?>{
          ...extraData,
          ...report.output,
          'contractStatus': report.status.name,
          if (report.summary != null) 'summary': report.summary,
        },
        artifacts: report.artifacts,
      ),
    );
  }

  /// Runs the underlying harness process or PTY session and returns its raw
  /// execution result.
  Future<Result<ProcessExecutionResult>> runHarness(
    NodeExecutionContext context, {
    required String workingDirectory,
    required String prompt,
  });

  /// Interprets stdout/stderr from [result] to detect auth/quota failures and
  /// extract structured metadata.
  HarnessOutputAnalysis parseOutput(ProcessExecutionResult result);

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) async {
    final issues = validateConfig(context.config);
    if (issues.isNotEmpty) {
      return FailureResult(
        ValidationFailure(
          issues.map((i) => '${i.field}: ${i.message}').join('; '),
        ),
      );
    }

    final config = HarnessNodeConfig.fromJson(context.config);
    final workingDirResult = resolveWorkspacePath(
      context.workspacePath,
      config.workingDirectory,
    );
    if (workingDirResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }
    final workingDirectory = workingDirResult.valueOrNull!;

    final promptResult = await buildPrompt(
      context,
      agentId: config.agentId,
      additionalInstructions: config.additionalInstructions,
    );
    if (promptResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }
    final prompt = promptResult.valueOrNull!;

    final runResult = await runHarness(
      context,
      workingDirectory: workingDirectory,
      prompt: prompt,
    );
    if (runResult case FailureResult<ProcessExecutionResult>(:final failure)) {
      return FailureResult(failure);
    }
    final processResult = runResult.valueOrNull!;

    final analysis = parseOutput(processResult);
    if (analysis.isAuthenticationError) {
      return FailureResult(
        HarnessAuthenticationFailure(
          analysis.errorMessage ??
              'Authentication required for "$typeId". Sign in to the CLI and '
                  'retry.',
          harnessType: typeId,
        ),
      );
    }
    if (analysis.isRateLimitError) {
      return FailureResult(
        HarnessRateLimitFailure(
          analysis.errorMessage ??
              'Rate limit or quota exhausted for "$typeId".',
          harnessType: typeId,
        ),
      );
    }

    if (processResult.timedOut) {
      return FailureResult(
        NodeExecutionFailure(
          'Harness "$typeId" timed out after ${config.timeoutSeconds}s.',
        ),
      );
    }

    if (processResult.exitCode != 0) {
      return FailureResult(
        NodeExecutionFailure(
          'Harness "$typeId" exited with code ${processResult.exitCode}.',
          exitCode: processResult.exitCode,
        ),
      );
    }

    return await resolveResultContract(context, extraData: analysis.metadata);
  }
}

/// Template Method base for headless CLI harness nodes (`claude`, `codex`,
/// `gemini`, `agy`).
abstract base class HeadlessHarnessNode extends HarnessNode {
  /// Creates a headless harness node.
  const new({
    required this.processRunner,
    required super.resultContract,
    required super.agentPromptResolver,
  });

  /// Process runner used to invoke the harness CLI.
  final NodeProcessRunner processRunner;

  /// Builds the CLI [ProcessInvocation] for this harness.
  ///
  /// Subclasses must deliver [prompt] via `stdinContent` (or a file), never
  /// inside [ProcessInvocation.arguments] (ADR 0005).
  ProcessInvocation buildInvocation({
    required HarnessNodeConfig config,
    required String workingDirectory,
    required String prompt,
  });

  @override
  Future<Result<ProcessExecutionResult>> runHarness(
    NodeExecutionContext context, {
    required String workingDirectory,
    required String prompt,
  }) {
    final config = HarnessNodeConfig.fromJson(context.config);
    final invocation = buildInvocation(
      config: config,
      workingDirectory: workingDirectory,
      prompt: prompt,
    );
    return processRunner.run(invocation, onOutput: context.onOutput);
  }
}

/// Shared pattern-based auth/quota detector for CLI output.
///
/// Only classifies authentication or rate-limit errors when the process failed
/// (`exitCode != 0`), so normal agent output mentioning status codes or terms
/// like `401` or `429` never overrides a successful run.
HarnessOutputAnalysis analyzeCliOutput(
  ProcessExecutionResult result, {
  required RegExp authPattern,
  required RegExp rateLimitPattern,
}) {
  final metadata = <String, Object?>{
    if (result.stdout.isNotEmpty) 'stdout': result.stdout,
    if (result.stderr.isNotEmpty) 'stderr': result.stderr,
  };

  if (result.exitCode == 0 && !result.timedOut) {
    return HarnessOutputAnalysis(metadata: metadata);
  }

  final combined = '${result.stderr}\n${result.stdout}'.trim();
  if (authPattern.hasMatch(combined)) {
    return HarnessOutputAnalysis(
      isAuthenticationError: true,
      errorMessage: _firstMatchingLine(combined, authPattern),
      metadata: metadata,
    );
  }
  if (rateLimitPattern.hasMatch(combined)) {
    return HarnessOutputAnalysis(
      isRateLimitError: true,
      errorMessage: _firstMatchingLine(combined, rateLimitPattern),
      metadata: metadata,
    );
  }
  return HarnessOutputAnalysis(metadata: metadata);
}

String? _firstMatchingLine(String text, RegExp pattern) {
  for (final line in text.split('\n')) {
    if (pattern.hasMatch(line)) {
      return line.trim();
    }
  }
  return null;
}
