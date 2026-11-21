import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Interactive PTY fallback harness (`harness.terminal`, ADR 0005).
final class TerminalHarnessNode extends HarnessNode {
  /// Creates a terminal harness node.
  const new({
    required this.ptyRunner,
    required super.resultContract,
    required super.agentPromptResolver,
    this.defaultExecutable = 'sh',
  });

  /// PTY runner port (implemented by F12).
  final PtyRunner ptyRunner;

  /// Fallback executable when `command` is omitted from config.
  final String defaultExecutable;

  static final RegExp _authPattern = RegExp(
    '(not logged in|not authenticated|authentication failed|unauthorized|401)',
    caseSensitive: false,
  );

  static final RegExp _rateLimitPattern = RegExp(
    '(rate limit|quota exceeded|too many requests|429)',
    caseSensitive: false,
  );

  @override
  String get typeId => NodeTypeId.terminal;

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

    final config = TerminalHarnessNodeConfig.fromJson(context.config);
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

    final configuredCommand = config.command?.trim();
    final executable =
        (configuredCommand != null && configuredCommand.isNotEmpty)
        ? configuredCommand
        : defaultExecutable;

    final ptyResult = await ptyRunner.run(
      PtyInvocation(
        executable: executable,
        arguments: <String>[...config.args, ...config.extraArgs],
        workingDirectory: workingDirectory,
        initialInput: prompt,
        timeout: config.timeoutSeconds != null
            ? Duration(seconds: config.timeoutSeconds!)
            : null,
      ),
      onOutput: context.onOutput,
    );
    if (ptyResult case FailureResult<ProcessExecutionResult>(:final failure)) {
      return FailureResult(failure);
    }
    final processResult = ptyResult.valueOrNull!;

    final analysis = analyzeCliOutput(
      processResult,
      authPattern: _authPattern,
      rateLimitPattern: _rateLimitPattern,
    );
    if (analysis.isAuthenticationError) {
      return FailureResult(
        HarnessAuthenticationFailure(
          analysis.errorMessage ??
              'Authentication required for "$typeId". Sign in and retry.',
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
