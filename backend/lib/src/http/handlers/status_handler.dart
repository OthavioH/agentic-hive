import 'package:agentic_hive_backend/src/db/database_health_check.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// `GET /api/v1/status`: version, uptime, data folder and a real database
/// check. Answers `503` when a dependency is down.
final class StatusHandler {
  /// Creates the handler; [now] is injectable for tests.
  new({
    required this._databaseHealthCheck,
    required this._version,
    required this._dataDir,
    required this._startedAt,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DatabaseHealthCheck _databaseHealthCheck;
  final String _version;
  final String _dataDir;
  final DateTime _startedAt;
  final DateTime Function() _now;

  /// Handles one status request.
  Future<Response> call(Request request) async {
    final database = await _databaseHealthCheck.check();
    final status = database.ok ? BackendStatus.ok : BackendStatus.degraded;
    return jsonResponse(
      database.ok ? 200 : 503,
      StatusResponse(
        status: status,
        version: _version,
        uptimeSeconds: _now().difference(_startedAt).inSeconds,
        dataDir: _dataDir,
        database: database,
      ),
    );
  }
}
