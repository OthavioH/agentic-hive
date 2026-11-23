import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/agents/workspace_agent_watchers.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Workspace _workspace(String id, String root) => Workspace(
  id: id,
  name: id,
  rootPath: root,
  isGit: false,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late Directory tempDir;
  late ConnectionRegistry registry;
  late _Channel channel;
  late List<Workspace> registered;
  late WorkspaceAgentWatchers watchers;
  final events = <AgentsChangedPayload>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ws_watchers_');
    addTearDown(() async {
      await watchers.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    registry = ConnectionRegistry();
    channel = _Channel();
    registry.add(WsConnection(id: 'c', channel: channel));
    events.clear();
    final sub = channel.outgoing.listen((frame) {
      final envelope = WsEnvelope.decode(frame! as String);
      if (envelope.type == WsMessageType.agentsChanged) {
        events.add(AgentsChangedPayload.fromJson(envelope.payload));
      }
    });
    addTearDown(sub.cancel);
    registered = [];
    watchers = WorkspaceAgentWatchers(
      listWorkspaces: () async => Success(registered),
      repositoryFor: (root) => LocalAgentRepository(
        agentsDir: p.join(root, '.agents', 'agents'),
        scope: AgentScope.workspace,
      ),
      registry: registry,
      debounceDuration: const Duration(milliseconds: 30),
    );
  });

  test('an external edit in a workspace folder is broadcast live', () async {
    final root = p.join(tempDir.path, 'repo');
    final agents = Directory(p.join(root, '.agents', 'agents'));
    await agents.create(recursive: true);
    registered = [_workspace('ws-1', root)];
    await watchers.sync();

    await File(p.join(agents.path, 'reviewer.md'))
        .writeAsString('---\nname: Reviewer\n---\nReview.');
    await _waitFor(() => events.isNotEmpty);

    expect(events.first.id, 'reviewer');
    expect(events.first.workspaceId, 'ws-1');
    expect(events.first.agent?.scope, AgentScope.workspace);
  });

  test(
    'a workspace without an agents folder is not watched or created',
    () async {
      final root = p.join(tempDir.path, 'plain');
      await Directory(root).create();
      registered = [_workspace('ws-1', root)];

      await watchers.sync();

      expect(watchers.watchedWorkspaceIds, isEmpty);
      expect(Directory(p.join(root, '.agents')).existsSync(), isFalse);
    },
  );

  test('sync starts new workspaces and stops unregistered ones', () async {
    final rootA = p.join(tempDir.path, 'a');
    final rootB = p.join(tempDir.path, 'b');
    await Directory(p.join(rootA, '.agents', 'agents')).create(recursive: true);
    await Directory(p.join(rootB, '.agents', 'agents')).create(recursive: true);

    registered = [_workspace('a', rootA)];
    await watchers.sync();
    expect(watchers.watchedWorkspaceIds, {'a'});

    registered = [_workspace('a', rootA), _workspace('b', rootB)];
    await watchers.sync();
    expect(watchers.watchedWorkspaceIds, {'a', 'b'});

    registered = [_workspace('b', rootB)];
    await watchers.sync();
    expect(watchers.watchedWorkspaceIds, {'b'});
  });
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for event.');
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

final class _Channel implements WebSocketChannel {
  final _outgoing = StreamController<Object?>.broadcast();

  Stream<Object?> get outgoing => _outgoing.stream;

  @override
  Stream<Object?> get stream => const Stream<Object?>.empty();

  @override
  WebSocketSink get sink => _Sink(_outgoing);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Sink implements WebSocketSink {
  new(this._controller);

  final StreamController<Object?> _controller;

  @override
  void add(Object? data) => _controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<Object?> stream) =>
      _controller.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) =>
      _controller.close();

  @override
  Future<void> get done => _controller.done;
}
