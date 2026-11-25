import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agents_migration_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/agents/agents_migration_repository_impl.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  String? lastMethod;
  String? lastPath;
  Result<JsonMap> next = const Success(<String, Object?>{});

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) async {
    lastMethod = 'GET';
    lastPath = path;
    return next;
  }

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    return next;
  }

  @override
  Future<Result<StatusResponse>> checkStatus() => throw UnimplementedError();

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() =>
      throw UnimplementedError();

  @override
  Future<Result<JsonMap>> putJson(String path, JsonMap body) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> delete(String path) => throw UnimplementedError();

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) =>
      throw UnimplementedError();

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) => throw UnimplementedError();

  @override
  Future<void> close() async {}
}

void main() {
  const status = AgentsMigrationStatus(
    legacyDir: '/data/agents',
    targetDir: '/home/me/.agents/agents',
    conflicts: <String>['reviewer.md'],
  );

  late _FakeBackendClient client;
  late AgentsMigrationRepositoryImpl repository;

  setUp(() {
    client = _FakeBackendClient();
    repository = AgentsMigrationRepositoryImpl(
      AgentsMigrationRemoteDataSource(client),
    );
  });

  test('getStatus reads the migration status', () async {
    client.next = Success(status.toJson());

    final result = await repository.getStatus();

    expect(client.lastMethod, 'GET');
    expect(client.lastPath, '/api/v1/agent-library/migration');
    expect(result.valueOrNull, status);
    expect(result.valueOrNull?.hasPendingConflicts, isTrue);
  });

  test('dismiss posts to the dismiss route', () async {
    client.next = Success(status.copyWith(dismissed: true).toJson());

    final result = await repository.dismiss();

    expect(client.lastMethod, 'POST');
    expect(client.lastPath, '/api/v1/agent-library/migration/dismiss');
    expect(result.valueOrNull?.hasPendingConflicts, isFalse);
  });

  test('a malformed body becomes a failure', () async {
    client.next = const Success(<String, Object?>{'legacyDir': 1});

    final result = await repository.getStatus();

    expect(result, isA<FailureResult<AgentsMigrationStatus>>());
  });

  test('a backend failure is passed through', () async {
    client.next = const FailureResult(NetworkFailure('down'));

    final result = await repository.dismiss();

    expect(result, isA<FailureResult<AgentsMigrationStatus>>());
  });
}
