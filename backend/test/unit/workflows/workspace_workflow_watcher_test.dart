import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workflows/file_workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/data/workflows/workspace_workflow_watcher.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_web_socket_channel.dart';

final class _Workspaces implements WorkspaceRepository {
  final known = <Workspace>[];

  @override
  Future<Result<List<Workspace>>> list() async => Success(List.of(known));

  @override
  Future<Result<Workspace>> getById(String id) async {
    for (final workspace in known) {
      if (workspace.id == id) return Success(workspace);
    }
    return FailureResult(NotFoundFailure('Workspace "$id" not found.'));
  }

  @override
  Future<Result<Workspace>> create(Workspace workspace) async =>
      Success(workspace);

  @override
  Future<Result<void>> delete(String id) async => const Success<void>(null);

  @override
  Future<Result<Workspace>> rename(
    String id, {
    required String name,
    required DateTime updatedAt,
  }) async => Success(known.first);
}

Map<String, Object?> _workflowJson(String name) => {
  'id': 'ignored',
  'name': name,
  'nodes': <Object?>[],
  'edges': <Object?>[],
  'createdAt': DateTime.utc(2026, 11, 23).toIso8601String(),
  'updatedAt': DateTime.utc(2026, 11, 23).toIso8601String(),
};

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  late Directory root;
  late _Workspaces workspaces;
  late FakeWebSocketChannel channel;
  late WorkspaceWorkflowWatcher watcher;
  late List<WorkflowsChangedPayload> events;

  String workflowsDir() => p.join(root.path, '.agentic-hive', 'workflows');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hive_wf_watch_');
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });
    workspaces = _Workspaces()
      ..known.add(
        Workspace(
          id: 'ws-1',
          name: 'Repo',
          rootPath: root.path,
          isGit: false,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
    final registry = ConnectionRegistry();
    channel = FakeWebSocketChannel();
    registry.add(WsConnection(id: 'conn-1', channel: channel));
    events = [];
    final sub = channel.outgoing.listen((frame) {
      final envelope = WsEnvelope.decode(frame! as String);
      if (envelope.type == WsMessageType.workflowsChanged) {
        events.add(WorkflowsChangedPayload.fromJson(envelope.payload));
      }
    });
    addTearDown(sub.cancel);
    watcher = WorkspaceWorkflowWatcher(
      workspaces: workspaces,
      repository: FileWorkspaceWorkflowRepository(),
      validator: const WorkflowValidator(),
      registry: registry,
      debounceDuration: const Duration(milliseconds: 30),
      rescanInterval: const Duration(milliseconds: 100),
    );
    addTearDown(watcher.close);
  });

  test('an external create, edit and delete are broadcast live', () async {
    await Directory(workflowsDir()).create(recursive: true);
    await watcher.start();
    final file = File(p.join(workflowsDir(), 'deploy.json'));

    await file.writeAsString(jsonEncode(_workflowJson('Deploy')));
    await _waitFor(
      () => events.any((e) => e.kind == WorkflowChangeKind.created),
    );
    final created = events.firstWhere(
      (e) => e.kind == WorkflowChangeKind.created,
    );
    expect(created.id, 'deploy');
    expect(created.workspaceId, 'ws-1');
    expect(created.workflow?.name, 'Deploy');
    expect(created.workflow?.scope, const WorkspaceScope('ws-1'));
    expect(created.workflow?.revision, matches(RegExp(r'^[0-9a-f]{16}$')));

    await file.writeAsString(jsonEncode(_workflowJson('Deploy v2')));
    await _waitFor(
      () => events.any((e) => e.kind == WorkflowChangeKind.updated),
    );
    expect(
      events
          .firstWhere((e) => e.kind == WorkflowChangeKind.updated)
          .workflow
          ?.name,
      'Deploy v2',
    );

    await file.delete();
    await _waitFor(
      () => events.any((e) => e.kind == WorkflowChangeKind.deleted),
    );
    final deleted = events.firstWhere(
      (e) => e.kind == WorkflowChangeKind.deleted,
    );
    expect(deleted.id, 'deploy');
    expect(deleted.workflow, isNull);
  });

  test('ignores files that are not .json', () async {
    await Directory(workflowsDir()).create(recursive: true);
    await watcher.start();

    await File(p.join(workflowsDir(), 'notes.txt')).writeAsString('x');
    await File(p.join(workflowsDir(), 'real.json'))
        .writeAsString(jsonEncode(_workflowJson('Real')));
    await _waitFor(() => events.isNotEmpty);

    expect(events.map((e) => e.id), everyElement('real'));
  });

  test('a workflows folder created after start is picked up', () async {
    await watcher.start();
    expect(Directory(workflowsDir()).existsSync(), isFalse);

    await Directory(workflowsDir()).create(recursive: true);
    // Let the periodic rescan notice the folder before the file lands.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await File(p.join(workflowsDir(), 'late.json'))
        .writeAsString(jsonEncode(_workflowJson('Late')));

    await _waitFor(() => events.any((e) => e.id == 'late'));
  });
}
