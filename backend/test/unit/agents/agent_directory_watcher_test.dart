import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/data/agents/agent_directory_watcher.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  late Directory tempDir;
  late ConnectionRegistry registry;
  late _FakeWebSocketChannel channel;
  late AgentDirectoryWatcher watcher;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agents_watch_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    registry = ConnectionRegistry();
    channel = _FakeWebSocketChannel();
    registry.add(WsConnection(id: 'conn-1', channel: channel));

    final repository = LocalAgentRepository(agentsDir: tempDir.path);
    watcher = AgentDirectoryWatcher(
      agentsDir: tempDir.path,
      repository: repository,
      registry: registry,
      debounceDuration: const Duration(milliseconds: 30),
    );
    addTearDown(() => watcher.close());
    await watcher.start();
  });

  test(
    'broadcasts agents.changed on external create, modify, and delete',
    () async {
      final events = <AgentsChangedPayload>[];
      final sub = channel.outgoing.listen((frame) {
        final envelope = WsEnvelope.decode(frame! as String);
        if (envelope.type == WsMessageType.agentsChanged) {
          events.add(AgentsChangedPayload.fromJson(envelope.payload));
        }
      });
      addTearDown(sub.cancel);

      final file = File(p.join(tempDir.path, 'reviewer.md'));
      await file.writeAsString('---\nname: Reviewer\n---\nInitial.');
      await _waitFor(
        () => events.any((e) => e.kind == AgentChangeKind.created),
      );

      final created = events.firstWhere(
        (e) => e.kind == AgentChangeKind.created,
      );
      expect(created.id, 'reviewer');
      expect(created.agent?.name, 'Reviewer');

      await file.writeAsString('---\nname: Reviewer v2\n---\nUpdated.');
      await _waitFor(
        () => events.any((e) => e.kind == AgentChangeKind.updated),
      );

      final updated = events.firstWhere(
        (e) => e.kind == AgentChangeKind.updated,
      );
      expect(updated.id, 'reviewer');
      expect(updated.agent?.name, 'Reviewer v2');

      await file.delete();
      await _waitFor(
        () => events.any((e) => e.kind == AgentChangeKind.deleted),
      );

      final deleted = events.firstWhere(
        (e) => e.kind == AgentChangeKind.deleted,
      );
      expect(deleted.id, 'reviewer');
      expect(deleted.agent, isNull);
    },
  );

  test('tags workspace events with workspaceId and workspace scope', () async {
    final workspaceDir = Directory(p.join(tempDir.path, 'ws-agents'));
    await workspaceDir.create();
    final workspaceWatcher = AgentDirectoryWatcher(
      agentsDir: workspaceDir.path,
      repository: LocalAgentRepository(
        agentsDir: workspaceDir.path,
        scope: AgentScope.workspace,
      ),
      registry: registry,
      workspaceId: 'ws-1',
      debounceDuration: const Duration(milliseconds: 30),
    );
    addTearDown(workspaceWatcher.close);
    await workspaceWatcher.start();

    final events = <AgentsChangedPayload>[];
    final sub = channel.outgoing.listen((frame) {
      final envelope = WsEnvelope.decode(frame! as String);
      if (envelope.type == WsMessageType.agentsChanged) {
        events.add(AgentsChangedPayload.fromJson(envelope.payload));
      }
    });
    addTearDown(sub.cancel);

    await File(p.join(workspaceDir.path, 'planner.md'))
        .writeAsString('---\nname: Planner\n---\nPlan.');
    await _waitFor(() => events.isNotEmpty);

    expect(events.single.workspaceId, 'ws-1');
    expect(events.single.agent?.scope, AgentScope.workspace);
  });

  test('global events carry no workspaceId', () async {
    final events = <AgentsChangedPayload>[];
    final sub = channel.outgoing.listen((frame) {
      final envelope = WsEnvelope.decode(frame! as String);
      if (envelope.type == WsMessageType.agentsChanged) {
        events.add(AgentsChangedPayload.fromJson(envelope.payload));
      }
    });
    addTearDown(sub.cancel);
    await File(p.join(tempDir.path, 'a.md'))
        .writeAsString('---\nname: A\n---\nx');
    await _waitFor(() => events.isNotEmpty);
    expect(events.single.workspaceId, isNull);
    expect(events.single.agent?.scope, AgentScope.global);
  });

  test('ignores non-md files and subdirectories', () async {
    final events = <AgentsChangedPayload>[];
    final sub = channel.outgoing.listen((frame) {
      final envelope = WsEnvelope.decode(frame! as String);
      if (envelope.type == WsMessageType.agentsChanged) {
        events.add(AgentsChangedPayload.fromJson(envelope.payload));
      }
    });
    addTearDown(sub.cancel);

    await File(p.join(tempDir.path, 'notes.txt')).writeAsString('ignore me');
    final nestedDir = Directory(p.join(tempDir.path, 'sub'));
    await nestedDir.create();
    await File(p.join(nestedDir.path, 'nested.md'))
        .writeAsString('---\nname: Nested\n---\n');

    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(events, isEmpty);
  });
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for watcher event.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

final class _FakeWebSocketChannel implements WebSocketChannel {
  final _incoming = StreamController<Object?>.broadcast();
  final _outgoing = StreamController<Object?>.broadcast();

  Stream<Object?> get outgoing => _outgoing.stream;

  @override
  Stream<Object?> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSink(_outgoing);

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeWebSocketSink implements WebSocketSink {
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
