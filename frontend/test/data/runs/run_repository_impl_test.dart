import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
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
  Future<Result<StatusResponse>> checkStatus() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<void> close() async {}
}

void main() {
  final now = DateTime.utc(2026, 11, 21, 4, 30);
  final later = DateTime.utc(2026, 11, 21, 4, 30, 12);
  final sampleWorkflow = Workflow(
    id: 'wf-1',
    name: 'Build & Test',
    nodes: const <WorkflowNode>[],
    edges: const <WorkflowEdge>[],
    createdAt: now,
    updatedAt: now,
  );
  final sampleRun = Run(
    id: 'run-1',
    workflowId: 'wf-1',
    workflowName: 'Build & Test',
    workflowDefinition: sampleWorkflow,
    workspacePath: '/tmp/workspace',
    status: RunStatus.succeeded,
    startedAt: now,
    finishedAt: later,
  );
  final sampleSummary = RunSummary(
    id: 'run-1',
    workflowId: 'wf-1',
    workflowName: 'Build & Test',
    status: RunStatus.succeeded,
    startedAt: now,
    finishedAt: later,
    checkpointCount: 2,
  );
  final sampleEvent = RunEvent(
    id: 'evt-1',
    runId: 'run-1',
    sequence: 1,
    type: RunEventType.runStarted,
    createdAt: now,
    payload: const <String, Object?>{'workspace': '/tmp/workspace'},
  );
  final sampleCheckpoint = Checkpoint(
    id: 'cp-1',
    runId: 'run-1',
    sequence: 1,
    completedNodeId: 'node-1',
    pendingNodeIds: const <String>['node-2'],
    attemptsByEdge: const <String, int>{'edge-1': 1},
    circuitBreakerCount: 0,
    nodeOutputs: const <String, JsonMap>{
      'node-1': <String, Object?>{'ok': true},
    },
    createdAt: now,
  );

  group('RunRepositoryImpl & HttpRunsRemoteDataSource', () {
    test(
      'listRuns calls GET /api/v1/runs with optional query params',
      () async {
        final client = _FakeBackendClient()
          ..nextResponse = Success(
            RunsListResponse(
              items: <RunSummary>[sampleSummary],
              total: 1,
            ).toJson(),
          );
        final container = ProviderContainer.test(
          overrides: [backendClientProvider.overrideWithValue(client)],
        );

        final repo = container.read(runRepositoryProvider);
        final result = await repo.listRuns(
          status: RunStatus.succeeded,
          workflowId: 'wf-1',
          limit: 20,
          offset: 5,
        );

        expect(client.lastMethod, 'GET');
        final uri = Uri.parse(client.lastPath!);
        expect(uri.path, '/api/v1/runs');
        expect(uri.queryParameters, <String, String>{
          'status': 'succeeded',
          'workflowId': 'wf-1',
          'limit': '20',
          'offset': '5',
        });
        expect(result.valueOrNull?.items, hasLength(1));
        expect(result.valueOrNull?.total, 1);
      },
    );

    test('getRun, getRunEvents, getRunCheckpoints, deleteRun', () async {
      final client = _FakeBackendClient();
      final container = ProviderContainer.test(
        overrides: [backendClientProvider.overrideWithValue(client)],
      );
      final repo = container.read(runRepositoryProvider);

      client.nextResponse = Success(sampleRun.toJson());
      final runRes = await repo.getRun('run-1');
      expect(client.lastMethod, 'GET');
      expect(client.lastPath, '/api/v1/runs/run-1');
      expect(runRes.valueOrNull?.id, 'run-1');

      client.nextResponse = Success(
        RunEventsResponse(
          items: <RunEvent>[sampleEvent],
          lastSequence: 1,
        ).toJson(),
      );
      final eventsRes = await repo.getRunEvents(
        'run-1',
        afterSequence: 0,
        limit: 100,
      );
      expect(client.lastMethod, 'GET');
      final eventsUri = Uri.parse(client.lastPath!);
      expect(eventsUri.path, '/api/v1/runs/run-1/events');
      expect(eventsUri.queryParameters, <String, String>{
        'afterSequence': '0',
        'limit': '100',
      });
      expect(eventsRes.valueOrNull?.items, hasLength(1));
      expect(eventsRes.valueOrNull?.lastSequence, 1);

      client.nextResponse = Success(
        RunCheckpointsResponse(items: <Checkpoint>[sampleCheckpoint]).toJson(),
      );
      final cpRes = await repo.getRunCheckpoints('run-1');
      expect(client.lastMethod, 'GET');
      expect(client.lastPath, '/api/v1/runs/run-1/checkpoints');
      expect(cpRes.valueOrNull, hasLength(1));
      expect(cpRes.valueOrNull!.first.id, 'cp-1');

      client.nextResponse = const Success(<String, Object?>{});
      final delRes = await repo.deleteRun('run-1');
      expect(client.lastMethod, 'DELETE');
      expect(client.lastPath, '/api/v1/runs/run-1');
      expect(delRes.isSuccess, isTrue);
    });

    test('returns BackendFailure on malformed payload', () async {
      final client = _FakeBackendClient()
        ..nextResponse = const Success(<String, Object?>{'unexpected': true});
      final container = ProviderContainer.test(
        overrides: [backendClientProvider.overrideWithValue(client)],
      );

      final result = await container.read(runRepositoryProvider).listRuns();
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<BackendFailure>());
    });

    test('propagates NotFoundFailure from BackendClient', () async {
      final client = _FakeBackendClient()
        ..nextResponse = const FailureResult(NotFoundFailure('missing'));
      final container = ProviderContainer.test(
        overrides: [backendClientProvider.overrideWithValue(client)],
      );

      final result = await container
          .read(runRepositoryProvider)
          .getRun('missing');
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });
}
