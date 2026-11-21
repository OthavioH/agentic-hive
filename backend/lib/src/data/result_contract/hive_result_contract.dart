import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_coordinator.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_validator.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:path/path.dart' as p;

/// Per-attempt execution session prepared by [HiveResultContract].
final class ResultContractSession {
  /// Creates a session.
  new({
    required this.runId,
    required this.nodeId,
    required this.attempt,
    required this.mcpConfigPath,
    required this.resultJsonPath,
    required this.command,
    required this.arguments,
    required this.environment,
    required this._onDispose,
  });

  /// Active run identifier.
  final String runId;

  /// Active node identifier.
  final String nodeId;

  /// 1-based attempt number.
  final int attempt;

  /// Temporary MCP config JSON file path for harnesses requiring file config.
  final String mcpConfigPath;

  /// Backend-managed fallback `result.json` path outside the user's workspace.
  final String resultJsonPath;

  /// Command executable to launch `hive-mcp`.
  final String command;

  /// Full CLI arguments for `hive-mcp`.
  final List<String> arguments;

  /// Environment variables containing the `hive-mcp` execution context.
  final Map<String, String> environment;

  final Future<void> Function() _onDispose;
  bool _disposed = false;

  /// Cleans up the temporary MCP config file and unregisters the attempt.
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

  /// Prepares an execution session for [context], registering the attempt,
  /// ensuring the fallback directory exists, and writing a temporary MCP
  /// config file that is deleted when [ResultContractSession.dispose] runs.
  Future<ResultContractSession> openSession(
    NodeExecutionContext context,
  ) async {
    coordinator.registerAttempt(
      runId: context.runId,
      nodeId: context.nodeId,
      attempt: context.attempt,
      workspacePath: context.workspacePath,
      availableOutputs: context.availableOutputs,
    );

    final resultJsonPath =
        context.resultJsonPath ??
        fallbackResultJsonPath(
          runId: context.runId,
          nodeId: context.nodeId,
          attempt: context.attempt,
        );
    await Directory(_path.dirname(resultJsonPath)).create(recursive: true);

    final launch = _mcpLocator.resolve();
    final arguments = launch.argumentsFor(
      socketPath: socketPath,
      runId: context.runId,
      nodeId: context.nodeId,
      attempt: context.attempt,
    );
    final environment = <String, String>{
      'HIVE_SOCKET_PATH': socketPath,
      'HIVE_RUN_ID': context.runId,
      'HIVE_NODE_ID': context.nodeId,
      'HIVE_ATTEMPT': context.attempt.toString(),
    };

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

    return ResultContractSession(
      runId: context.runId,
      nodeId: context.nodeId,
      attempt: context.attempt,
      mcpConfigPath: mcpConfigPath,
      resultJsonPath: resultJsonPath,
      command: launch.executable,
      arguments: arguments,
      environment: environment,
      onDispose: () async {
        coordinator.unregisterAttempt(
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
    );
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

  static String _safeSegment(String raw) =>
      raw.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
}
