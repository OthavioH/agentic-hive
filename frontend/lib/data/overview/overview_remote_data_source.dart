import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remote data source communicating with `/api/v1/overview` via [BackendClient].
final class OverviewRemoteDataSource {
  /// Creates an [OverviewRemoteDataSource].
  const new(this._client);

  static const String _overviewPath = '/api/v1/overview';

  final BackendClient _client;

  /// Fetches `GET /api/v1/overview` and decodes the [OverviewSnapshot].
  Future<Result<OverviewSnapshot>> getOverview() async {
    final result = await _client.getJson(_overviewPath);
    return switch (result) {
      FailureResult<JsonMap>(:final failure) => FailureResult(failure),
      Success<JsonMap>(:final value) => _decodeSnapshot(value),
    };
  }

  Result<OverviewSnapshot> _decodeSnapshot(JsonMap json) {
    try {
      return Success(OverviewSnapshot.fromJson(json));
    } on FormatException catch (error) {
      return FailureResult(
        BackendFailure('Invalid overview response: ${error.message}'),
      );
    }
  }
}
