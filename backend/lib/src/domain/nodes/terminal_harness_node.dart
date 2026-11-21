import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Interactive PTY fallback harness (`harness.terminal`, ADR 0005).
final class TerminalHarnessNode extends HarnessNode {
  /// Creates a terminal harness node.
  const new({
    required this.ptyRunner,
    required this.defaultShellProvider,
    required super.resultContract,
    required super.agentPromptResolver,
    this.processTreeKiller,
    this.mcpGracePeriod = defaultMcpGracePeriod,
  });

  /// Default grace period to wait for an interactive CLI to exit on its own
  /// after `report_result` is accepted over MCP.
  static const Duration defaultMcpGracePeriod = Duration(seconds: 3);

  /// PTY runner port (implemented by F12).
  final PtyRunner ptyRunner;

  /// OS-specific fallback shell provider when `command` is omitted.
  final DefaultShellProvider defaultShellProvider;

  /// Optional process-tree killer used to terminate interactive CLIs that
  /// remain alive after [mcpGracePeriod] following an accepted MCP report.
  final ProcessTreeKiller? processTreeKiller;

  /// Grace period before terminating an interactive PTY after MCP report
  /// acceptance.
  final Duration mcpGracePeriod;

  static final RegExp _authPattern = RegExp(
    r'\b(not logged in|not authenticated|authentication failed|unauthorized|'
    r'http\s*401|status(?:\s+code)?[:\s]+401|error[:\s]+401|'
    r'401\s+unauthorized)\b',
    caseSensitive: false,
  );

  static final RegExp _rateLimitPattern = RegExp(
    r'\b(rate limit|quota exceeded|too many requests|http\s*429|'
    r'status(?:\s+code)?[:\s]+429|error[:\s]+429|'
    r'429\s+too\s+many\s+requests)\b',
    caseSensitive: false,
  );

  @override
  String get typeId => NodeTypeId.terminal;

  @override
  Future<Result<ProcessExecutionResult>> runHarness(
    NodeExecutionContext context, {
    required String workingDirectory,
    required String prompt,
    String? mcpConfigPath,
    String? resultFilePath,
    Future<ResultContractReport>? onMcpReportAccepted,
    Map<String, String> environment = const <String, String>{},
  }) async {
    final config = TerminalHarnessNodeConfig.fromJson(context.config);
    final configuredCommand = config.command?.trim();
    final executable =
        (configuredCommand != null && configuredCommand.isNotEmpty)
        ? configuredCommand
        : defaultShellProvider.defaultShell;

    Directory? promptDir;
    var terminatedAfterMcp = false;
    var finished = false;
    Failure? killFailure;
    Future<void>? pendingKill;
    Timer? graceTimer;

    try {
      promptDir = await Directory.systemTemp.createTemp('hive_pty_prompt_');
      final promptFile = File(p.join(promptDir.path, 'prompt.md'));
      await promptFile.writeAsString(prompt);

      final mergedEnv = <String, String>{
        'TERM': 'xterm-256color',
        'COLORTERM': 'truecolor',
        ...environment,
        'HIVE_PROMPT_FILE': promptFile.path,
        'HIVE_RESULT_PATH': ?resultFilePath,
        'HIVE_MCP_CONFIG': ?mcpConfigPath,
      };

      if (onMcpReportAccepted != null) {
        unawaited(
          onMcpReportAccepted.then((_) {
            if (finished) return;
            graceTimer = Timer(mcpGracePeriod, () {
              if (finished) return;
              final killer = processTreeKiller;
              if (killer == null) return;
              pendingKill = () async {
                final killResult = await killer.killTree(
                  runId: context.runId,
                  nodeId: context.nodeId,
                );
                if (killResult case FailureResult<void>(:final failure)) {
                  killFailure = failure;
                } else {
                  terminatedAfterMcp = true;
                }
              }();
            });
          }),
        );
      }

      final result = await ptyRunner.run(
        PtyInvocation(
          executable: executable,
          arguments: <String>[...config.args, ...config.extraArgs],
          workingDirectory: workingDirectory,
          environment: mergedEnv,
          initialInput: config.sendPromptToStdin
              ? _formatStdinPrompt(prompt)
              : null,
          timeout: config.timeoutSeconds != null
              ? Duration(seconds: config.timeoutSeconds!)
              : null,
          runId: context.runId,
          nodeId: context.nodeId,
          attempt: context.attempt,
        ),
        onOutput: context.onOutput,
      );
      finished = true;
      graceTimer?.cancel();
      if (pendingKill != null) {
        await pendingKill;
      }

      if (killFailure != null) {
        return FailureResult(killFailure!);
      }

      if (terminatedAfterMcp) {
        if (result case Success<ProcessExecutionResult>(:final value)) {
          return Success(
            ProcessExecutionResult(
              exitCode: 0,
              stdout: value.stdout,
              stderr: value.stderr,
            ),
          );
        }
      }
      return result;
    } finally {
      finished = true;
      graceTimer?.cancel();
      if (promptDir != null && promptDir.existsSync()) {
        try {
          await promptDir.delete(recursive: true);
        } on FileSystemException {
          // Best-effort cleanup of temporary prompt file.
        }
      }
    }
  }

  /// Formats [prompt] for PTY stdin submission.
  ///
  /// ConPTY (Windows) and raw-mode TUIs require `\r` (CR) rather than `\n` to
  /// trigger Enter, so a trailing `\n`/`\r\n` is normalized to `\r` and a
  /// missing trailing `\r` is appended.
  static String _formatStdinPrompt(String prompt) {
    if (prompt.endsWith('\r\n')) {
      return '${prompt.substring(0, prompt.length - 2)}\r';
    }
    if (prompt.endsWith('\n')) {
      return '${prompt.substring(0, prompt.length - 1)}\r';
    }
    if (prompt.endsWith('\r')) {
      return prompt;
    }
    return '$prompt\r';
  }

  @override
  HarnessOutputAnalysis parseOutput(ProcessExecutionResult result) =>
      analyzeCliOutput(
        result,
        authPattern: _authPattern,
        rateLimitPattern: _rateLimitPattern,
      );
}
