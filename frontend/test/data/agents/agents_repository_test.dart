import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/data/agents/agents_remote_data_source.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWebSocketSession implements BackendWebSocketSession {
  final StreamController<WsEnvelope> _messages =
      StreamController<WsEnvelope>.broadcast();
  final Completer<void> _done = Completer<void>();

  @override
  ServerHelloPayload get serverHello => const ServerHelloPayload(
    serverVersion: '0.1.0',
    protocolVersion: wsProtocolVersion,
  );

  @override
  Stream<WsEnvelope> get messages => _messages.stream;

  @override
  Future<void> get done => _done.future;

  @override
  bool get isClosed => false;

  void emit(WsEnvelope envelope) => _messages.add(envelope);

  @override
  Future<Result<void>> send(WsEnvelope envelope) async => const Success(null);

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!_messages.isClosed) await _messages.close();
    if (!_done.isCompleted) _done.complete();
  }
}

final class _FakeBackendClient implements BackendClient {
  new(this.session);

  final _FakeWebSocketSession session;
  String? lastMethod;
  String? lastPath;
  JsonMap? lastBody;

  Result<JsonMap> nextGet = const Success(<String, Object?>{'agents': []});
  Result<JsonMap> nextPost = const Success(<String, Object?>{});
  Result<JsonMap> nextPut = const Success(<String, Object?>{});
  Result<void> nextDelete = const Success(null);

  @override
  Future<Result<StatusResponse>> checkStatus() async => const Success(
    StatusResponse(
      status: BackendStatus.ok,
      version: '0.1.0',
      uptimeSeconds: 1,
      dataDir: '/tmp/hive',
      database: DatabaseStatus(ok: true, schemaVersion: 1),
    ),
  );

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      Success(session);

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async =>
      const Success(ShutdownResponse());

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) async {
    lastMethod = 'GET';
    lastPath = path;
    return nextGet;
  }

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = body;
    return nextPost;
  }

  @override
  Future<Result<JsonMap>> putJson(String path, JsonMap body) async {
    lastMethod = 'PUT';
    lastPath = path;
    lastBody = body;
    return nextPut;
  }

  @override
  Future<Result<void>> delete(String path) async {
    lastMethod = 'DELETE';
    lastPath = path;
    return nextDelete;
  }

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async => const FailureResult(NetworkFailure('unused'));

  @override
  Future<void> close() async {}
}

void main() {
  group('AgentsRemoteDataSource', () {
    test('decodes list, detail, create, update conflict, and delete', () async {
      final session = _FakeWebSocketSession();
      final client = _FakeBackendClient(session);
      final ds = AgentsRemoteDataSource(client);

      client.nextGet = Success(
        AgentListResponse(
          agents: <AgentSummary>[
            AgentSummary(
              id: 'reviewer',
              name: 'Reviewer',
              contentHash: 'h1',
              updatedAt: DateTime.utc(2026, 11, 20),
            ),
          ],
        ).toJson(),
      );
      final list = await ds.listAgents();
      expect(client.lastPath, '/api/v1/agents');
      expect(list.valueOrNull, hasLength(1));

      client.nextGet = Success(
        AgentDetail(
          id: 'broken',
          name: 'broken',
          contentHash: 'h0',
          updatedAt: DateTime.utc(2026, 11, 20),
          parseError: 'Invalid YAML',
          rawContent: '---\nbroken: [',
        ).toJson(),
      );
      final detail = await ds.getAgent('broken');
      expect(client.lastPath, '/api/v1/agents/broken');
      expect(detail.valueOrNull?.parseError, 'Invalid YAML');

      client.nextPut = const FailureResult(
        BackendFailure(
          'Hash mismatch',
          code: ApiErrorCode.conflict,
          statusCode: 409,
        ),
      );
      final conflict = await ds.updateAgent(
        'reviewer',
        const UpdateAgentRequest(name: 'Reviewer', expectedHash: 'stale'),
      );
      expect(conflict.isFailure, isTrue);
      expect((conflict.failureOrNull! as BackendFailure).statusCode, 409);

      final del = await ds.deleteAgent('reviewer');
      expect(del.isSuccess, isTrue);
      expect(client.lastMethod, 'DELETE');
    });

    test('sends workspaceId as a query parameter only when scoped', () async {
      final client = _FakeBackendClient(_FakeWebSocketSession());
      final ds = AgentsRemoteDataSource(client);

      await ds.listAgents(scope: const WorkspaceScope('ws 1'));
      expect(client.lastPath, '/api/v1/agents?workspaceId=ws%201');

      client.nextGet = Success(
        AgentDetail(
          id: 'reviewer',
          name: 'Reviewer',
          contentHash: 'h',
          updatedAt: DateTime.utc(2026, 11, 20),
          scope: const WorkspaceScope('ws-1'),
        ).toJson(),
      );
      final detail = await ds.getAgent(
        'reviewer',
        scope: const WorkspaceScope('ws-1'),
      );
      expect(client.lastPath, '/api/v1/agents/reviewer?workspaceId=ws-1');
      expect(detail.valueOrNull?.scope, const WorkspaceScope('ws-1'));

      await ds.createAgent(
        const CreateAgentRequest(id: 'a', name: 'A'),
        scope: const WorkspaceScope('ws-1'),
      );
      expect(client.lastPath, '/api/v1/agents?workspaceId=ws-1');

      await ds.updateAgent(
        'a',
        const UpdateAgentRequest(name: 'A', expectedHash: 'h'),
        scope: const WorkspaceScope('ws-1'),
      );
      expect(client.lastPath, '/api/v1/agents/a?workspaceId=ws-1');

      await ds.deleteAgent('a', scope: const WorkspaceScope('ws-1'));
      expect(client.lastPath, '/api/v1/agents/a?workspaceId=ws-1');

      await ds.listAgents();
      expect(client.lastPath, '/api/v1/agents');
    });
  });

  group('agentRepositoryProvider', () {
    test(
      'forwards agents.changed WebSocket events from BackendConnection',
      () async {
        final session = _FakeWebSocketSession();
        final client = _FakeBackendClient(session);
        final container = ProviderContainer.test(
          overrides: [
            backendClientProvider.overrideWithValue(client),
            backendConnectionConfigProvider.overrideWithValue(
              BackendConnectionConfig(nextRandomDouble: () => 0.5),
            ),
          ],
        );

        final repo = container
            .listen(agentRepositoryProvider, (_, _) {})
            .read();
        final received = <AgentsChangedPayload>[];
        final sub = repo.watchAgentChanges().listen(received.add);

        // Wait for BackendConnection microtask to connect and attach session.
        await pumpEventQueue();

        session.emit(
          WsEnvelope(
            type: WsMessageType.agentsChanged,
            id: 'evt-1',
            payload: const AgentsChangedPayload(
              kind: AgentChangeKind.deleted,
              id: 'reviewer',
            ).toJson(),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.single.id, 'reviewer');
        expect(received.single.kind, AgentChangeKind.deleted);

        await sub.cancel();
      },
    );
  });
}
