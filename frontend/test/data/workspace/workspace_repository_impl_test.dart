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
  JsonMap? lastBody;
  Result<JsonMap> nextResponse = const Success(<String, Object?>{});

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async {
    lastMethod = method;
    lastPath = path;
    lastBody = body;
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

  test('listWorkspaces GETs /api/v1/workspaces and decodes items', () async {
    client.nextResponse = const Success(<String, Object?>{
      'items': <Object?>[
        <String, Object?>{
          'id': 'ws-1',
          'name': 'Repo One',
          'rootPath': '/tmp/repo-one',
          'isGit': true,
          'createdAt': '2026-11-22T10:00:00.000Z',
          'updatedAt': '2026-11-22T10:00:00.000Z',
          'activeRunCount': 2,
        },
      ],
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .listWorkspaces();
    expect(client.lastMethod, 'GET');
    expect(client.lastPath, '/api/v1/workspaces');
    expect(result.valueOrNull?.single.id, 'ws-1');
    expect(result.valueOrNull?.single.activeRunCount, 2);
  });

  test(
    'createWorkspace POSTs to /api/v1/workspaces with rootPath and name',
    () async {
      client.nextResponse = const Success(<String, Object?>{
        'id': 'ws-2',
        'name': 'Custom',
        'rootPath': '/tmp/repo-two',
        'isGit': false,
        'createdAt': '2026-11-22T10:00:00.000Z',
        'updatedAt': '2026-11-22T10:00:00.000Z',
      });
      final result = await container
          .read(workspaceRepositoryProvider)
          .createWorkspace(rootPath: '/tmp/repo-two', name: 'Custom');
      expect(client.lastMethod, 'POST');
      expect(client.lastPath, '/api/v1/workspaces');
      expect(client.lastBody, <String, Object?>{
        'rootPath': '/tmp/repo-two',
        'name': 'Custom',
      });
      expect(result.valueOrNull?.name, 'Custom');
      expect(result.valueOrNull?.isGit, isFalse);
    },
  );

  test('renameWorkspace PATCHes /api/v1/workspaces/:id', () async {
    client.nextResponse = const Success(<String, Object?>{
      'id': 'ws-1',
      'name': 'Renamed',
      'rootPath': '/tmp/repo-one',
      'isGit': true,
      'createdAt': '2026-11-22T10:00:00.000Z',
      'updatedAt': '2026-11-22T11:00:00.000Z',
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .renameWorkspace('ws-1', name: 'Renamed');
    expect(client.lastMethod, 'PATCH');
    expect(client.lastPath, '/api/v1/workspaces/ws-1');
    expect(client.lastBody, <String, Object?>{'name': 'Renamed'});
    expect(result.valueOrNull?.name, 'Renamed');
  });

  test('unregisterWorkspace DELETEs /api/v1/workspaces/:id', () async {
    client.nextResponse = const Success(<String, Object?>{
      'id': 'ws-1',
      'deleted': true,
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .unregisterWorkspace('ws-1');
    expect(client.lastMethod, 'DELETE');
    expect(client.lastPath, '/api/v1/workspaces/ws-1');
    expect(result.isSuccess, isTrue);
  });

  test('listWorktrees GETs /api/v1/workspaces/:id/worktrees', () async {
    client.nextResponse = const Success(<String, Object?>{
      'items': <Object?>[
        <String, Object?>{
          'id': 'primary',
          'name': 'primary',
          'path': '/tmp/repo-one',
          'isPrimary': true,
          'hasUncommittedChanges': false,
          'branch': 'main',
        },
        <String, Object?>{
          'id': 'feat-a',
          'name': 'feat-a',
          'path': '/data/worktrees/ws-1/feat-a',
          'isPrimary': false,
          'hasUncommittedChanges': true,
          'branch': 'feature/a',
        },
      ],
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .listWorktrees('ws-1');
    expect(client.lastMethod, 'GET');
    expect(client.lastPath, '/api/v1/workspaces/ws-1/worktrees');
    final items = result.valueOrNull;
    expect(items, hasLength(2));
    expect(items![0].isPrimary, isTrue);
    expect(items[0].branch, 'main');
    expect(items[1].hasUncommittedChanges, isTrue);
  });

  test('removeWorktree DELETEs /api/v1/workspaces/:id/worktrees/:wtId', () async {
    client.nextResponse = const Success(<String, Object?>{
      'id': 'feat-a',
      'deleted': true,
      'branchDeleted': false,
      'notice': 'Branch kept because it is not merged.',
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .removeWorktree('ws-1', 'feat-a');
    expect(client.lastMethod, 'DELETE');
    expect(client.lastPath, '/api/v1/workspaces/ws-1/worktrees/feat-a');
    expect(result.valueOrNull?.deleted, isTrue);
    expect(result.valueOrNull?.branchDeleted, isFalse);
    expect(
      result.valueOrNull?.notice,
      'Branch kept because it is not merged.',
    );
  });

  test('removeWorktree passes force=true query parameter', () async {
    client.nextResponse = const Success(<String, Object?>{
      'id': 'feat-a',
      'deleted': true,
      'branchDeleted': true,
    });
    final result = await container
        .read(workspaceRepositoryProvider)
        .removeWorktree('ws-1', 'feat-a', force: true);
    expect(client.lastMethod, 'DELETE');
    expect(
      client.lastPath,
      '/api/v1/workspaces/ws-1/worktrees/feat-a?force=true',
    );
    expect(result.valueOrNull?.branchDeleted, isTrue);
  });
}
