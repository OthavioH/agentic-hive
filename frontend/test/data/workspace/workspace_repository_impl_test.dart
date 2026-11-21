import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  String? lastMethod;
  String? lastPath;
  Result<JsonMap> nextResponse = const Success(<String, Object?>{});

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async {
    lastMethod = method;
    lastPath = path;
    return nextResponse;
  }

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) =>
      sendJsonRequest('GET', path);

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) => sendJsonRequest('POST', path, body: body);

  @override
  Future<Result<JsonMap>> putJson(String path, JsonMap body) =>
      sendJsonRequest('PUT', path, body: body);

  @override
  Future<Result<void>> delete(String path) async => const Success(null);

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<StatusResponse>> checkStatus() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<void> close() async {}
}

Map<String, Object?> _snapshotJson(String id) => <String, Object?>{
  'id': id,
  'runId': 'run-1',
  'nodeId': 'node-a',
  'commitHash': 'abc',
  'kind': 'pre_node',
  'addedCount': 1,
  'modifiedCount': 2,
  'deletedCount': 3,
  'createdAt': '2026-11-21T04:30:00.000Z',
};

void main() {
  late _FakeBackendClient client;
  late ProviderContainer container;

  setUp(() {
    client = _FakeBackendClient();
    container = ProviderContainer.test(
      overrides: [backendClientProvider.overrideWithValue(client)],
    );
  });

  test('getCapabilities sends the path query and decodes it', () async {
    client.nextResponse = const Success(<String, Object?>{
      'gitAvailable': true,
      'gitVersion': '2.50.0',
      'isGitRepo': true,
      'hasCommits': false,
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .getCapabilities(path: '/work space');
    expect(client.lastMethod, 'GET');
    expect(
      client.lastPath,
      '/api/v1/workspace/capabilities?path=%2Fwork+space',
    );
    expect(result.valueOrNull?.gitAvailable, isTrue);
    expect(result.valueOrNull?.hasCommits, isFalse);
  });

  test('getCapabilities without a path omits the query', () async {
    client.nextResponse = const Success(<String, Object?>{
      'gitAvailable': false,
      'isGitRepo': false,
      'hasCommits': false,
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .getCapabilities();
    expect(client.lastPath, '/api/v1/workspace/capabilities');
    expect(result.valueOrNull?.gitAvailable, isFalse);
  });

  test('listSnapshots decodes the items list', () async {
    client.nextResponse = Success(<String, Object?>{
      'items': <Object?>[_snapshotJson('s1'), _snapshotJson('s2')],
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .listSnapshots('run-1');
    expect(client.lastMethod, 'GET');
    expect(client.lastPath, '/api/v1/runs/run-1/snapshots');
    expect(result.valueOrNull?.map((s) => s.id), <String>['s1', 's2']);
  });

  test('getSnapshotDiff hits the diff route', () async {
    client.nextResponse = const Success(<String, Object?>{
      'snapshotId': 's1',
      'files': <Object?>[
        <String, Object?>{'path': 'a.txt', 'changeType': 'added'},
      ],
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .getSnapshotDiff('run-1', 's1');
    expect(client.lastPath, '/api/v1/runs/run-1/snapshots/s1/diff');
    expect(result.valueOrNull?.files.single.path, 'a.txt');
  });

  test('restoreSnapshot POSTs to the restore route', () async {
    client.nextResponse = Success(<String, Object?>{
      'restoredSnapshotId': 's1',
      'safetySnapshot': _snapshotJson('safety'),
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .restoreSnapshot('run-1', 's1');
    expect(client.lastMethod, 'POST');
    expect(client.lastPath, '/api/v1/runs/run-1/snapshots/s1/restore');
    expect(result.valueOrNull?.safetySnapshot.id, 'safety');
  });

  test('maps a malformed payload to a BackendFailure', () async {
    client.nextResponse = const Success(<String, Object?>{'items': 'nope'});
    final result = await container
        .read(workspaceRepositoryProvider)
        .listSnapshots('run-1');
    expect(result.failureOrNull, isA<BackendFailure>());
  });

  test('propagates a conflict failure from the backend client', () async {
    client.nextResponse = const FailureResult<JsonMap>(
      BackendFailure('conflict', statusCode: 409),
    );
    final result = await container
        .read(workspaceRepositoryProvider)
        .restoreSnapshot('run-1', 's1');
    expect((result.failureOrNull! as BackendFailure).statusCode, 409);
  });
}
