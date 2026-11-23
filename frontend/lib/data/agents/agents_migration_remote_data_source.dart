import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote data source for `/api/v1/agent-library/migration` via
/// [BackendClient].
final class AgentsMigrationRemoteDataSource {
  /// Creates an [AgentsMigrationRemoteDataSource].
  const new(this._client);

  static const String _path = '/api/v1/agent-library/migration';

  final BackendClient _client;

  /// Fetches the migration status (`GET /api/v1/agent-library/migration`).
  Future<Result<AgentsMigrationStatus>> getStatus() async {
    final result = await _client.getJson(_path);
    return result.flatMap(_decode);
  }

  /// Dismisses the conflicts (`POST /api/v1/agent-library/migration/dismiss`).
  Future<Result<AgentsMigrationStatus>> dismiss() async {
    final result = await _client.postJson('$_path/dismiss');
    return result.flatMap(_decode);
  }

  Result<AgentsMigrationStatus> _decode(JsonMap json) {
    try {
      return Success(AgentsMigrationStatus.fromJson(json));
    } on FormatException catch (error) {
      return FailureResult(
        BackendFailure('Invalid agents migration response: ${error.message}'),
      );
    }
  }
}
