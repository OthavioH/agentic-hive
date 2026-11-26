@Timeout(Duration(seconds: 90))
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';
import '../websocket/support/ws_harness.dart';

Future<void> _git(String dir, List<String> args) async {
  final result = await Process.run('git', [
    '-c',
    'user.name=Test',
    '-c',
    'user.email=test@example.com',
    ...args,
  ], workingDirectory: dir);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

/// Reads frames until one of [type] arrives.
Future<WsEnvelope> _nextOfType(WsTestClient client, String type) async {
  for (var i = 0; i < 20; i++) {
    final envelope = await client.next();
    if (envelope.type == type) return envelope;
  }
  fail('No "$type" frame arrived.');
}

void main() {
  late SocketHttpClient http;
  late WsTestClient ws;
  late Directory repo;

  setUp(() async {
    final dataDir = (await createTempDir()).path;
    repo = await createTempDir();
    await _git(repo.path, ['init', '-b', 'main']);
    File(p.join(repo.path, 'a.txt')).writeAsStringSync('a');
    await _git(repo.path, ['add', '.']);
    await _git(repo.path, ['commit', '-m', 'init']);
    final backend = await startBackend(dataDir);
    http = SocketHttpClient(backend.socketPath);
    addTearDown(http.close);
    ws = await WsTestClient.connect(backend.socketPath);
    addTearDown(ws.close);
    await ws.next(); // server.hello
  });

  test('registering, renaming and unregistering a workspace broadcast '
      'workspaces.changed', () async {
    final created = await http.post(
      '/api/v1/workspaces',
      body: jsonEncode(CreateWorkspaceRequest(rootPath: repo.path).toJson()),
    );
    expect(created.statusCode, 201);
    final workspace = Workspace.fromJson(created.json);

    final createdEvent = WorkspacesChangedPayload.fromJson(
      (await _nextOfType(ws, WsMessageType.workspacesChanged)).payload,
    );
    expect(createdEvent.kind, WorkspaceChangeKind.created);
    expect(createdEvent.id, workspace.id);
    expect(createdEvent.workspace, workspace);

    final renamed = await http.patch(
      '/api/v1/workspaces/${workspace.id}',
      body: jsonEncode(const UpdateWorkspaceRequest(name: 'Renamed').toJson()),
    );
    expect(renamed.statusCode, 200);
    final updatedEvent = WorkspacesChangedPayload.fromJson(
      (await _nextOfType(ws, WsMessageType.workspacesChanged)).payload,
    );
    expect(updatedEvent.kind, WorkspaceChangeKind.updated);
    expect(updatedEvent.workspace?.name, 'Renamed');

    final deleted = await http.delete('/api/v1/workspaces/${workspace.id}');
    expect(deleted.statusCode, 200);
    final deletedEvent = WorkspacesChangedPayload.fromJson(
      (await _nextOfType(ws, WsMessageType.workspacesChanged)).payload,
    );
    expect(deletedEvent.kind, WorkspaceChangeKind.deleted);
    expect(deletedEvent.id, workspace.id);
    expect(deletedEvent.workspace, isNull);
  });

  test('creating and removing a worktree broadcast worktrees.changed, and '
      'a failed creation broadcasts nothing', () async {
    final registered = await http.post(
      '/api/v1/workspaces',
      body: jsonEncode(CreateWorkspaceRequest(rootPath: repo.path).toJson()),
    );
    final workspace = Workspace.fromJson(registered.json);
    await _nextOfType(ws, WsMessageType.workspacesChanged);
    final base = '/api/v1/workspaces/${workspace.id}/worktrees';

    final rejected = await http.post(
      base,
      body: jsonEncode(const CreateWorktreeRequest(name: '../evil').toJson()),
    );
    expect(rejected.statusCode, 400);

    final created = await http.post(
      base,
      body: jsonEncode(const CreateWorktreeRequest(name: 'feat').toJson()),
    );
    expect(created.statusCode, 201);
    final createdEvent = WorktreesChangedPayload.fromJson(
      (await _nextOfType(ws, WsMessageType.worktreesChanged)).payload,
    );
    expect(createdEvent.kind, WorktreeChangeKind.created);
    expect(createdEvent.workspaceId, workspace.id);
    expect(createdEvent.worktreeId, 'feat');
    expect(createdEvent.worktree, Worktree.fromJson(created.json));

    final removed = await http.delete('$base/feat');
    expect(removed.statusCode, 200);
    final removedEvent = WorktreesChangedPayload.fromJson(
      (await _nextOfType(ws, WsMessageType.worktreesChanged)).payload,
    );
    expect(removedEvent.kind, WorktreeChangeKind.removed);
    expect(removedEvent.worktreeId, 'feat');
    expect(removedEvent.worktree, isNull);
  });

  test(
    'failed worktree removal (409) still broadcasts worktrees.changed',
    () async {
      final registered = await http.post(
        '/api/v1/workspaces',
        body: jsonEncode(CreateWorkspaceRequest(rootPath: repo.path).toJson()),
      );
      final workspace = Workspace.fromJson(registered.json);
      await _nextOfType(ws, WsMessageType.workspacesChanged);
      final base = '/api/v1/workspaces/${workspace.id}/worktrees';

      final created = await http.post(
        base,
        body: jsonEncode(const CreateWorktreeRequest(name: 'held').toJson()),
      );
      expect(created.statusCode, 201);
      final worktree = Worktree.fromJson(created.json);
      await _nextOfType(ws, WsMessageType.worktreesChanged);

      await _git(repo.path, ['worktree', 'lock', worktree.path]);
      addTearDown(() async {
        await Process.run('git', [
          '-C',
          repo.path,
          'worktree',
          'unlock',
          worktree.path,
        ]);
      });

      final removed = await http.delete('$base/held');
      expect(removed.statusCode, 409);
      final event = WorktreesChangedPayload.fromJson(
        (await _nextOfType(ws, WsMessageType.worktreesChanged)).payload,
      );
      expect(event.kind, WorktreeChangeKind.removed);
      expect(event.workspaceId, workspace.id);
      expect(event.worktreeId, 'held');
    },
  );
}
