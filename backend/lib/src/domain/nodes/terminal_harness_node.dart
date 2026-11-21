import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Interactive PTY fallback harness (`harness.terminal`, ADR 0005).
final class TerminalHarnessNode extends HarnessNode {
  /// Creates a terminal harness node.
  const new({
    required this.ptyRunner,
    required this.defaultShellProvider,
    required super.resultContract,
    required super.agentPromptResolver,
  });

  /// PTY runner port (implemented by F12).
  final PtyRunner ptyRunner;

  /// OS-specific fallback shell provider when `command` is omitted.
  final DefaultShellProvider defaultShellProvider;

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
    Map<String, String> environment = const <String, String>{},
  }) {
    final config = TerminalHarnessNodeConfig.fromJson(context.config);
    final configuredCommand = config.command?.trim();
    final executable =
        (configuredCommand != null && configuredCommand.isNotEmpty)
        ? configuredCommand
        : defaultShellProvider.defaultShell;

    return ptyRunner.run(
      PtyInvocation(
        executable: executable,
        arguments: <String>[...config.args, ...config.extraArgs],
        workingDirectory: workingDirectory,
        environment: environment,
        initialInput: prompt,
        timeout: config.timeoutSeconds != null
            ? Duration(seconds: config.timeoutSeconds!)
            : null,
      ),
      onOutput: context.onOutput,
    );
  }

  @override
  HarnessOutputAnalysis parseOutput(ProcessExecutionResult result) =>
      analyzeCliOutput(
        result,
        authPattern: _authPattern,
        rateLimitPattern: _rateLimitPattern,
      );
}
