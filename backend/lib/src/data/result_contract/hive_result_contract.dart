import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_coordinator.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_validator.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:path/path.dart' as p;

/// Per-attempt execution session prepared by [HiveResultContract].
final class HiveResultContractSession implements ResultContractSession {
  /// Creates a session.
  new({
    required this.runId,
    required this.nodeId,
    required this.attempt,
    required this.instructions,
    required this.mcpConfigPath,
    required this.resultJsonPath,
    required this.command,
    required this.arguments,
    required this.environment,
    required this._onResolveOutcome,
    required this._onDispose,
  });

  @override
  final String runId;

  @override
  final String nodeId;

  @override
  final int attempt;

  @override
  final String instructions;

  @override
  final String mcpConfigPath;

  /// Backend-managed fallback `result.json` path outside the user's workspace.
  final String resultJsonPath;

  @override
  String get resultFilePath => resultJsonPath;

  /// Command executable to launch `hive-mcp`.
  final String command;

  /// Full CLI arguments for `hive-mcp`.
  final List<String> arguments;

  /// Environment variables containing the `hive-mcp` execution context.
  final Map<String, String> environment;

  @override
  Map<String, String> get env => environment;

  final Future<Result<ResultContractReport>> Function({
    required int exitCode,
    bool timedOut,
  })
  _onResolveOutcome;
  final Future<void> Function() _onDispose;
  bool _disposed = false;

  @override
  Future<Result<ResultContractReport>> resolveOutcome({
    required int exitCode,
    bool timedOut = false,
  }) => _onResolveOutcome(exitCode: exitCode, timedOut: timedOut);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _onDispose();
  }
}

/// Concrete ADR 0003 [ResultContract] implementation backed by `hive-mcp` and
/// a backend-managed `result.json` fallback outside the workspace.
final class HiveResultContract implements ResultContract {
  /// Creates a concrete result contract.
  new({
    required this.coordinator,
    required this.dataDir,
    required this.socketPath,
    required this._mcpLocator,
    this._humanPauseGateway,
    ResultContractValidator? validator,
    p.Context? pathContext,
  }) : _validator =
           validator ?? ResultContractValidator(pathContext: pathContext),
       _path = pathContext ?? p.context;

  /// Coordinator holding active attempt state and locked MCP reports.
  final ResultContractCoordinator coordinator;

  /// Backend data directory where run metadata and fallback results live.
  final String dataDir;

  /// Backend Unix domain socket path.
  final String socketPath;

  final HiveMcpLocator _mcpLocator;
  final HumanPauseGateway? _humanPauseGateway;
  final ResultContractValidator _validator;
  final p.Context _path;

  /// Returns the backend-managed fallback `result.json` path outside the
  /// user's workspace: `<dataDir>/runs/<runId>/results/<nodeId>-attempt-<n>.json`.
  String fallbackResultJsonPath({
    required String runId,
    required String nodeId,
    int attempt = 1,
  }) => _path.join(
    dataDir,
    'runs',
    _safeSegment(runId),
    'results',
    '${_safeSegment(nodeId)}-attempt-$attempt.json',
  );

  String _mcpConfigPath({
    required String runId,
    required String nodeId,
    required int attempt,
  }) => _path.join(
    dataDir,
    'runs',
    _safeSegment(runId),
    'mcp',
    '${_safeSegment(nodeId)}-attempt-$attempt.json',
  );

  @override
  Future<Result<HiveResultContractSession>> openSession(
    NodeExecutionContext context,
  ) async {
    final registration = coordinator.registerAttempt(
      runId: context.runId,
      nodeId: context.nodeId,
      attempt: context.attempt,
      workspacePath: context.workspacePath,
      availableOutputs: context.availableOutputs,
    );
    if (registration case FailureResult<void>(:final failure)) {
      return FailureResult(failure);
    }

    try {
      final launchResult = _mcpLocator.resolve();
      if (launchResult case FailureResult<HiveMcpLaunchCommand>(
        :final failure,
      )) {
        coordinator.unregisterAttempt(
          runId: context.runId,
          nodeId: context.nodeId,
          attempt: context.attempt,
        );
        return FailureResult(failure);
      }
      final launch = launchResult.valueOrNull!;

      final resultJsonPath =
          context.resultJsonPath ??
          fallbackResultJsonPath(
            runId: context.runId,
            nodeId: context.nodeId,
            attempt: context.attempt,
          );
      await Directory(_path.dirname(resultJsonPath)).create(recursive: true);

      final staleResultFile = File(resultJsonPath);
      if (staleResultFile.existsSync()) {
        await staleResultFile.delete();
      }

      final arguments = launch.argumentsFor(
        socketPath: socketPath,
        runId: context.runId,
        nodeId: context.nodeId,
        attempt: context.attempt,
      );
      final environment = Map<String, String>.unmodifiable(<String, String>{
        'HIVE_SOCKET_PATH': socketPath,
        'HIVE_RUN_ID': context.runId,
        'HIVE_NODE_ID': context.nodeId,
        'HIVE_ATTEMPT': context.attempt.toString(),
      });

      final mcpConfigPath = _mcpConfigPath(
        runId: context.runId,
        nodeId: context.nodeId,
        attempt: context.attempt,
      );
      final mcpConfigFile = File(mcpConfigPath);
      await mcpConfigFile.parent.create(recursive: true);
      await mcpConfigFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'mcpServers': <String, Object?>{
            'hive': <String, Object?>{
              'command': launch.executable,
              'args': arguments,
              'env': environment,
            },
          },
        }),
      );

      return Success(
        HiveResultContractSession(
          runId: context.runId,
          nodeId: context.nodeId,
          attempt: context.attempt,
          instructions: instructionsFor(context),
          mcpConfigPath: mcpConfigPath,
          resultJsonPath: resultJsonPath,
          command: launch.executable,
          arguments: arguments,
          environment: environment,
          onResolveOutcome: ({required exitCode, timedOut = false}) =>
              resolveOutcome(
                context: context,
                processResult: ProcessExecutionResult(
                  exitCode: exitCode,
                  timedOut: timedOut,
                ),
              ),
          onDispose: () async {
            coordinator.unregisterAttempt(
              runId: context.runId,
              nodeId: context.nodeId,
              attempt: context.attempt,
            );
            _humanPauseGateway?.cancelAttempt(
              runId: context.runId,
              nodeId: context.nodeId,
              attempt: context.attempt,
            );
            if (mcpConfigFile.existsSync()) {
              try {
                await mcpConfigFile.delete();
              } on FileSystemException {
                // Best-effort cleanup of temporary MCP config.
              }
            }
          },
        ),
      );
    } catch (_) {
      coordinator.unregisterAttempt(
        runId: context.runId,
        nodeId: context.nodeId,
        attempt: context.attempt,
      );
      rethrow;
    }
  }

  @override
  String instructionsFor(NodeExecutionContext context) {
    final allowedStatuses = ResultContractValidator.allowedStatusesFor(
      context.availableOutputs,
    );
    final resultPath =
        context.resultJsonPath ??
        fallbackResultJsonPath(
          runId: context.runId,
          nodeId: context.nodeId,
          attempt: context.attempt,
        );
    final statusList = allowedStatuses.map((s) => '"$s"').join(', ');

    return '''
## Result Contract (Required)
You must explicitly report your final outcome before exiting.

### Preferred: `report_result` MCP tool
Call the `report_result` tool from the `hive` MCP server with:
- `status` (required string): one of $statusList
- `summary` (required non-blank string): concise summary of what you did
- `data` (optional JSON object): structured output for downstream nodes
- `artifacts` (optional array of strings): workspace-relative file paths

### Clarification: `ask_human` MCP tool
If you need user input to proceed, call `ask_human` with:
- `question` (required non-blank string)
- `options` (optional array of suggested answer strings)

### Fallback (when MCP is unavailable): `result.json`
Write a JSON object with the exact same schema (`status`, `summary`, optional `data`, optional `artifacts`) to:
`$resultPath`''';
  }

  @override
  Future<Result<ResultContractReport?>> readReport(
    NodeExecutionContext context,
  ) async {
    final mcpReport = coordinator.getLockedMcpReport(
      runId: context.runId,
      nodeId: context.nodeId,
      attempt: context.attempt,
    );
    if (mcpReport != null) {
      return Success(mcpReport);
    }

    final resultPath =
        context.resultJsonPath ??
        fallbackResultJsonPath(
          runId: context.runId,
          nodeId: context.nodeId,
          attempt: context.attempt,
        );
    final file = File(resultPath);
    if (!file.existsSync()) {
      return const Success(null);
    }

    final String raw;
    try {
      raw = await file.readAsString();
    } on FileSystemException catch (error) {
      return FailureResult(
        NodeExecutionFailure(
          'Failed to read fallback result.json at "$resultPath": '
          '${error.message}',
          cause: error,
        ),
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      return FailureResult(
        ValidationFailure(
          'Invalid JSON in fallback result.json at "$resultPath": '
          '${error.message}',
        ),
      );
    }

    if (decoded is! Map<String, Object?>) {
      return FailureResult(
        ValidationFailure(
          'Fallback result.json at "$resultPath" must be a JSON object.',
        ),
      );
    }

    final validation = _validator.validate(
      decoded,
      workspacePath: context.workspacePath,
      availableOutputs: context.availableOutputs,
    );
    return switch (validation) {
      Success<ResultContractReport>(:final value) => Success(value),
      FailureResult<ResultContractReport>(:final failure) => FailureResult(
        failure,
      ),
    };
  }

  /// Resolves the final [ResultContractReport] after a process finishes,
  /// enforcing ADR 0003 precedence:
  /// 1. Non-zero exit code / timeout -> infrastructure failure (even if
  ///    `result.json` exists).
  /// 2. Accepted MCP `report_result` -> wins (any `result.json` is ignored).
  /// 3. Exit code 0 with no MCP report -> reads and validates `result.json`;
  ///    missing or invalid -> failure.
  Future<Result<ResultContractReport>> resolveOutcome({
    required NodeExecutionContext context,
    required ProcessExecutionResult processResult,
  }) async {
    if (processResult.timedOut) {
      return const FailureResult(
        NodeExecutionFailure('Process timed out before completing.'),
      );
    }
    if (processResult.exitCode != 0) {
      return FailureResult(
        NodeExecutionFailure(
          'Process exited with non-zero code ${processResult.exitCode}.',
          exitCode: processResult.exitCode,
        ),
      );
    }

    final reportResult = await readReport(context);
    if (reportResult case FailureResult<ResultContractReport?>(
      :final failure,
    )) {
      return FailureResult(failure);
    }
    final report = reportResult.valueOrNull;
    if (report == null) {
      return const FailureResult(
        NodeExecutionFailure(
          'Process exited with code 0 without submitting a result contract '
          'report.',
          exitCode: 0,
        ),
      );
    }
    return Success(report);
  }

  static String _safeSegment(String raw) {
    if (raw.isEmpty) return '%00';
    if (raw == '.') return '%2E';
    if (raw == '..') return '%2E%2E';
    return Uri.encodeComponent(raw);
  }
}
