import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

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

  /// Builds the full prompt from an optional `agentId` (or pre-resolved
  /// [agentPrompt]), `additionalInstructions`, execution context, and result
  /// contract instructions.
  Future<Result<String>> buildPrompt(
    NodeExecutionContext context, {
    String? agentId,
    String? agentPrompt,
    String? additionalInstructions,
    String? contractInstructions,
  }) async {
    final sections = <String>[];

    final preResolved = agentPrompt?.trim();
    if (preResolved != null) {
      if (preResolved.isNotEmpty) {
        sections.add(preResolved);
      }
    } else {
      final trimmedAgentId = agentId?.trim();
      if (trimmedAgentId != null && trimmedAgentId.isNotEmpty) {
        final agentResult = await agentPromptResolver.resolvePrompt(
          trimmedAgentId,
        );
        if (agentResult case FailureResult<String>(:final failure)) {
          return FailureResult(failure);
        }
        final resolvedPrompt = agentResult.valueOrNull!.trim();
        if (resolvedPrompt.isNotEmpty) {
          sections.add(resolvedPrompt);
        }
      }
    }

    final trimmedInstructions = additionalInstructions?.trim();
    if (trimmedInstructions != null && trimmedInstructions.isNotEmpty) {
      sections.add(trimmedInstructions);
    }

    final runInput = context.runInput?.trim();
    if (runInput != null && runInput.isNotEmpty) {
      sections.add('## Run input\n$runInput');
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

    final humanAnswer = context.humanAnswer?.trim();
    if (humanAnswer != null && humanAnswer.isNotEmpty) {
      sections.add(
        '## Human Answer\n'
        'You paused to ask a human for input. Their answer is:\n'
        '$humanAnswer',
      );
    }

    final resolvedInstructions =
        (contractInstructions ?? resultContract.instructionsFor(context))
            .trim();
    if (resolvedInstructions.isNotEmpty) {
      sections.add(resolvedInstructions);
    }

    return Success(sections.join('\n\n'));
  }

  /// Maps a validated [report] and optional [extraData] to a [NodeOutcome].
  NodeOutcome outcomeFromReport(
    ResultContractReport report, {
    Map<String, Object?> extraData = const <String, Object?>{},
  }) {
    final outputLabel = switch (report.status) {
      ResultContractStatus.success ||
      ResultContractStatus.approved => NodeOutput.onSuccess,
      ResultContractStatus.failure ||
      ResultContractStatus.changesRequested => NodeOutput.onFailure,
    };

    return NodeOutcome(
      outputLabel: outputLabel,
      data: <String, Object?>{
        ...extraData,
        ...report.output,
        'contractStatus': report.status.name,
        if (report.summary != null) 'summary': report.summary,
      },
      artifacts: report.artifacts,
    );
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

    return Success(outcomeFromReport(report, extraData: extraData));
  }

  /// Runs the underlying harness process or PTY session and returns its raw
  /// execution result.
  Future<Result<ProcessExecutionResult>> runHarness(
    NodeExecutionContext context, {
    required String workingDirectory,
    required String prompt,
    String? mcpConfigPath,
    String? resultFilePath,
    Future<ResultContractReport>? onMcpReportAccepted,
    Map<String, String> environment = const <String, String>{},
    List<String> allowedTools = const <String>[],
    List<String> deniedTools = const <String>[],
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

    final sessionResult = await resultContract.openSession(context);
    if (sessionResult case FailureResult<ResultContractSession>(
      :final failure,
    )) {
      return FailureResult(failure);
    }
    final session = sessionResult.valueOrNull!;

    try {
      ResolvedAgent? resolvedAgent;
      final trimmedAgentId = config.agentId?.trim();
      if (trimmedAgentId != null && trimmedAgentId.isNotEmpty) {
        final agentResult = await agentPromptResolver.resolveAgent(
          trimmedAgentId,
        );
        if (agentResult case FailureResult<ResolvedAgent>(:final failure)) {
          return FailureResult(failure);
        }
        resolvedAgent = agentResult.valueOrNull;
      }

      final promptResult = await buildPrompt(
        context,
        agentId: config.agentId,
        agentPrompt: resolvedAgent?.prompt,
        additionalInstructions: config.additionalInstructions,
        contractInstructions: session.instructions,
      );
      if (promptResult case FailureResult<String>(:final failure)) {
        return FailureResult(failure);
      }
      final prompt = promptResult.valueOrNull!;

      final runResult = await runHarness(
        context,
        workingDirectory: workingDirectory,
        prompt: prompt,
        mcpConfigPath: session.mcpConfigPath,
        resultFilePath: session.resultFilePath,
        onMcpReportAccepted: session.onMcpReportAccepted,
        environment: session.env,
        allowedTools: resolvedAgent?.allowedTools ?? const <String>[],
        deniedTools: resolvedAgent?.deniedTools ?? const <String>[],
      );
      if (runResult case FailureResult<ProcessExecutionResult>(
        :final failure,
      )) {
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
        await session.resolveOutcome(
          exitCode: processResult.exitCode,
          timedOut: true,
        );
        return FailureResult(
          NodeExecutionFailure(
            'Harness "$typeId" timed out after ${config.timeoutSeconds}s.',
          ),
        );
      }

      final outcomeResult = await session.resolveOutcome(
        exitCode: processResult.exitCode,
        timedOut: processResult.timedOut,
      );
      return switch (outcomeResult) {
        Success<ResultContractReport>(:final value) => Success(
          outcomeFromReport(value, extraData: analysis.metadata),
        ),
        // Exit code 0 with a missing or malformed report breaks the result
        // contract (ADR 0003): an infrastructure failure, not a bad config.
        FailureResult<ResultContractReport>(
          failure: ValidationFailure(:final message),
        ) =>
          FailureResult(
            NodeExecutionFailure(
              'Invalid result contract from "$typeId": $message',
              exitCode: processResult.exitCode,
            ),
          ),
        FailureResult<ResultContractReport>(:final failure) => FailureResult(
          failure,
        ),
      };
    } finally {
      await session.dispose();
    }
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

  static final Logger _log = Logger('headless_harness_node');
  static final Set<String> _loggedPolicyGaps = <String>{};

  /// Process runner used to invoke the harness CLI.
  final NodeProcessRunner processRunner;

  /// Normalizes and filters [allowedTools] against [deniedTools] so denied
  /// tools always take precedence, returning deduplicated lists in order.
  static ({List<String> allowed, List<String> denied}) resolveToolLists({
    List<String> allowedTools = const <String>[],
    List<String> deniedTools = const <String>[],
  }) {
    final denied = <String>[];
    final deniedSeen = <String>{};
    for (final raw in deniedTools) {
      final tool = raw.trim();
      if (tool.isNotEmpty && deniedSeen.add(tool)) {
        denied.add(tool);
      }
    }

    final allowed = <String>[];
    final allowedSeen = <String>{};
    for (final raw in allowedTools) {
      final tool = raw.trim();
      if (tool.isNotEmpty &&
          !deniedSeen.contains(tool) &&
          allowedSeen.add(tool)) {
        allowed.add(tool);
      }
    }

    return (allowed: allowed, denied: denied);
  }

  /// Logs a permission-policy CLI gap at most once per `(runId, typeId,
  /// gapKey)` so unsupported flags are never silently ignored or spammed.
  void logPolicyGapOnce({
    required String? runId,
    required String gapKey,
    required String message,
  }) {
    final effectiveRunId = runId ?? '<no-run>';
    final key = '$effectiveRunId|$typeId|$gapKey';
    if (_loggedPolicyGaps.length > 1000) {
      _loggedPolicyGaps.clear();
    }
    if (_loggedPolicyGaps.add(key)) {
      _log.warning(message);
    }
  }

  /// Builds the CLI permission-policy arguments for this harness (ADR 0021).
  List<String> buildPermissionArgs({
    required WorkspaceIsolationMode isolationMode,
    String? resultsDir,
    List<String> allowedTools = const <String>[],
    List<String> deniedTools = const <String>[],
    String? runId,
  });

  /// Builds the CLI [ProcessInvocation] for this harness.
  ///
  /// Subclasses must deliver [prompt] via `stdinContent` (or a file), never
  /// inside [ProcessInvocation.arguments] (ADR 0005).
  ProcessInvocation buildInvocation({
    required HarnessNodeConfig config,
    required String workingDirectory,
    required String prompt,
    String? mcpConfigPath,
    Map<String, String> environment = const <String, String>{},
    WorkspaceIsolationMode isolationMode = WorkspaceIsolationMode.direct,
    String? resultsDir,
    List<String> allowedTools = const <String>[],
    List<String> deniedTools = const <String>[],
    String? runId,
  });

  @override
  Future<Result<ProcessExecutionResult>> runHarness(
    NodeExecutionContext context, {
    required String workingDirectory,
    required String prompt,
    String? mcpConfigPath,
    String? resultFilePath,
    Future<ResultContractReport>? onMcpReportAccepted,
    Map<String, String> environment = const <String, String>{},
    List<String> allowedTools = const <String>[],
    List<String> deniedTools = const <String>[],
  }) {
    final config = HarnessNodeConfig.fromJson(context.config);
    final effectiveResultPath = resultFilePath ?? context.resultJsonPath;
    final resultsDir =
        effectiveResultPath != null && effectiveResultPath.isNotEmpty
        ? p.dirname(effectiveResultPath)
        : null;
    final invocation = buildInvocation(
      config: config,
      workingDirectory: workingDirectory,
      prompt: prompt,
      mcpConfigPath: mcpConfigPath,
      environment: environment,
      isolationMode: context.isolationMode,
      resultsDir: resultsDir,
      allowedTools: allowedTools,
      deniedTools: deniedTools,
      runId: context.runId,
    );
    return processRunner.run(
      ProcessInvocation(
        executable: invocation.executable,
        workingDirectory: invocation.workingDirectory,
        arguments: invocation.arguments,
        environment: invocation.environment,
        stdinContent: invocation.stdinContent,
        timeout: invocation.timeout,
        runId: invocation.runId ?? context.runId,
        nodeId: invocation.nodeId ?? context.nodeId,
      ),
      onOutput: context.onOutput,
    );
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
