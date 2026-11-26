import 'dart:async';
import 'dart:math' as math;

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/fan_out_children_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _baseTime = DateTime.utc(2026, 11, 21, 10);

Workflow _minimalWorkflow() => Workflow(
  id: 'wf-child',
  name: 'Child Flow',
  nodes: const <WorkflowNode>[],
  edges: const <WorkflowEdge>[],
  createdAt: _baseTime,
  updatedAt: _baseTime,
);

RunSummary _summary({
  required String id,
  String? parentRunId,
  String? parentNodeId = 'fan',
  RunStatus status = RunStatus.running,
  DateTime? startedAt,
}) => RunSummary(
  id: id,
  workspaceId: 'ws-1',
  workflowId: 'wf-child',
  workflowName: 'Child Flow',
  status: status,
  startedAt: startedAt ?? _baseTime,
  checkpointCount: 0,
  parentRunId: parentRunId,
  parentNodeId: parentNodeId,
);

Run _run({
  required String id,
  String parentRunId = 'parent-1',
  String parentNodeId = 'fan',
  int childIndex = 0,
  RunStatus status = RunStatus.running,
  DateTime? startedAt,
}) => Run(
  id: id,
  workflowId: 'wf-child',
  workflowName: 'Child Flow',
  workflowDefinition: _minimalWorkflow(),
  workspaceRoot: '/tmp/ws',
  status: status,
  startedAt: startedAt ?? _baseTime,
  parentRunId: parentRunId,
  parentNodeId: parentNodeId,
  childIndex: childIndex,
  childName: 'Item $childIndex',
);

final class _FakeRunRepository implements RunRepository {
  final List<RunSummary> summaries = <RunSummary>[];
  final Map<String, Result<Run>> runs = <String, Result<Run>>{};
  Result<RunsListResponse>? listOverride;
  int? maxPageSize;
  int listCalls = 0;
  final Map<String, int> getRunCalls = <String, int>{};

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async {
    listCalls++;
    if (listOverride != null) return listOverride!;
    final start = offset ?? 0;
    final effectiveLimit = maxPageSize == null
        ? limit
        : (limit == null ? maxPageSize! : math.min(limit, maxPageSize!));
    final page = effectiveLimit == null
        ? summaries.skip(start).toList()
        : summaries.skip(start).take(effectiveLimit).toList();
    return Success(RunsListResponse(items: page, total: summaries.length));
  }

  @override
  Future<Result<Run>> getRun(String id) async {
    getRunCalls[id] = (getRunCalls[id] ?? 0) + 1;
    return runs[id] ?? const FailureResult(NotFoundFailure('missing'));
  }

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      const Success(<Checkpoint>[]);

  @override
  Future<Result<Run>> startRun(StartRunRequest request) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<Run>> cancelRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<Run>> resumeRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<void>> deleteRun(String id) async => const Success(null);
}

void main() {
  group('FanOutChildrenController', () {
    test('loads only the children of the run, oldest first', () async {
      final repo = _FakeRunRepository()
        ..summaries.addAll(<RunSummary>[
          _summary(
            id: 'c2',
            parentRunId: 'parent-1',
            startedAt: DateTime.utc(2026, 11, 21, 10, 2),
          ),
          _summary(id: 'other-child', parentRunId: 'parent-2'),
          _summary(id: 'plain'),
          _summary(
            id: 'c1',
            parentRunId: 'parent-1',
            startedAt: DateTime.utc(2026, 11, 21, 10, 1),
          ),
        ])
        ..runs['c1'] = Success(
          _run(id: 'c1', startedAt: DateTime.utc(2026, 11, 21, 10, 1)),
        )
        ..runs['c2'] = Success(
          _run(
            id: 'c2',
            childIndex: 1,
            startedAt: DateTime.utc(2026, 11, 21, 10, 2),
          ),
        );
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWsMessagesProvider.overrideWith((_) => ws.stream),
        ],
      );

      final children = await container.read(
        fanOutChildrenControllerProvider('parent-1').future,
      );
      expect(children.map((r) => r.id).toList(), <String>['c1', 'c2']);
    });

    test('pages through the whole list', () async {
      final repo = _FakeRunRepository()
        ..maxPageSize = 2
        ..summaries.addAll(<RunSummary>[
          _summary(id: 'c1', parentRunId: 'parent-1'),
          _summary(id: 'plain'),
          _summary(
            id: 'c2',
            parentRunId: 'parent-1',
            startedAt: DateTime.utc(2026, 11, 21, 10, 1),
          ),
        ])
        ..runs['c1'] = Success(_run(id: 'c1'))
        ..runs['c2'] = Success(
          _run(
            id: 'c2',
            childIndex: 1,
            startedAt: DateTime.utc(2026, 11, 21, 10, 1),
          ),
        );
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWsMessagesProvider.overrideWith((_) => ws.stream),
        ],
      );

      final children = await container.read(
        fanOutChildrenControllerProvider('parent-1').future,
      );
      expect(repo.listCalls, 2);
      expect(children.map((r) => r.id).toList(), <String>['c1', 'c2']);
    });

    test('a run.event of a known child reloads', () async {
      final repo = _FakeRunRepository()
        ..summaries.add(_summary(id: 'c1', parentRunId: 'parent-1'))
        ..runs['c1'] = Success(_run(id: 'c1'));
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWsMessagesProvider.overrideWith((_) => ws.stream),
        ],
      )..listen(fanOutChildrenControllerProvider('parent-1'), (_, _) {});

      await container.read(fanOutChildrenControllerProvider('parent-1').future);
      final initialListCalls = repo.listCalls;

      repo.runs['c1'] = Success(_run(id: 'c1', status: RunStatus.succeeded));
      ws.add(
        WsEnvelope(
          id: 'ws-1',
          type: WsMessageType.runEvent,
          payload: RunEventPayload(
            event: RunEvent(
              id: 'e1',
              runId: 'c1',
              sequence: 2,
              type: RunEventType.runSucceeded,
              createdAt: _baseTime,
            ),
          ).toJson(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final reloaded = await container.read(
        fanOutChildrenControllerProvider('parent-1').future,
      );

      expect(repo.listCalls, greaterThan(initialListCalls));
      expect(reloaded.single.status, RunStatus.succeeded);
    });

    test('a run.started of any run reloads', () async {
      final repo = _FakeRunRepository()
        ..summaries.add(_summary(id: 'c1', parentRunId: 'parent-1'))
        ..runs['c1'] = Success(_run(id: 'c1'));
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWsMessagesProvider.overrideWith((_) => ws.stream),
        ],
      )..listen(fanOutChildrenControllerProvider('parent-1'), (_, _) {});

      await container.read(fanOutChildrenControllerProvider('parent-1').future);
      final before = repo.listCalls;

      ws.add(
        WsEnvelope(
          id: 'ws-2',
          type: WsMessageType.runEvent,
          payload: RunEventPayload(
            event: RunEvent(
              id: 'e2',
              runId: 'new-child',
              sequence: 1,
              type: RunEventType.runStarted,
              createdAt: _baseTime,
            ),
          ).toJson(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await container.read(fanOutChildrenControllerProvider('parent-1').future);

      expect(repo.listCalls, greaterThan(before));
    });

    test('an event of an unrelated run does not reload', () async {
      final repo = _FakeRunRepository()
        ..summaries.add(_summary(id: 'c1', parentRunId: 'parent-1'))
        ..runs['c1'] = Success(_run(id: 'c1'));
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWsMessagesProvider.overrideWith((_) => ws.stream),
        ],
      )..listen(fanOutChildrenControllerProvider('parent-1'), (_, _) {});

      await container.read(fanOutChildrenControllerProvider('parent-1').future);
      final before = repo.listCalls;

      ws.add(
        WsEnvelope(
          id: 'ws-3',
          type: WsMessageType.runEvent,
          payload: RunEventPayload(
            event: RunEvent(
              id: 'e3',
              runId: 'unrelated-run',
              sequence: 5,
              type: RunEventType.nodeCompleted,
              createdAt: _baseTime,
            ),
          ).toJson(),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repo.listCalls, before);
    });

    test('final children are not fetched again', () async {
      final repo = _FakeRunRepository()
        ..summaries.addAll(<RunSummary>[
          _summary(id: 'c-done', parentRunId: 'parent-1'),
          _summary(id: 'c-run', parentRunId: 'parent-1'),
        ])
        ..runs['c-done'] = Success(
          _run(id: 'c-done', status: RunStatus.succeeded),
        )
        ..runs['c-run'] = Success(_run(id: 'c-run', childIndex: 1));
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWsMessagesProvider.overrideWith((_) => ws.stream),
        ],
      )..listen(fanOutChildrenControllerProvider('parent-1'), (_, _) {});

      await container.read(fanOutChildrenControllerProvider('parent-1').future);
      expect(repo.getRunCalls['c-done'], 1);
      expect(repo.getRunCalls['c-run'], 1);

      await container
          .read(fanOutChildrenControllerProvider('parent-1').notifier)
          .refresh();

      expect(repo.getRunCalls['c-done'], 1);
      expect(repo.getRunCalls['c-run'], 2);
    });

    test('a failing list surfaces the failure as AsyncError', () async {
      final repo = _FakeRunRepository()
        ..listOverride = const FailureResult(NetworkFailure('offline'));
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWsMessagesProvider.overrideWith((_) => ws.stream),
        ],
      )..listen(fanOutChildrenControllerProvider('parent-1'), (_, _) {});

      await expectLater(
        container.read(fanOutChildrenControllerProvider('parent-1').future),
        throwsA(isA<NetworkFailure>()),
      );
      expect(
        container.read(fanOutChildrenControllerProvider('parent-1')),
        isA<AsyncError<List<Run>>>(),
      );
    });

    test('a getRun failure skips that child', () async {
      final repo = _FakeRunRepository()
        ..summaries.addAll(<RunSummary>[
          _summary(id: 'c-ok', parentRunId: 'parent-1'),
          _summary(id: 'c-gone', parentRunId: 'parent-1'),
        ])
        ..runs['c-ok'] = Success(_run(id: 'c-ok'))
        ..runs['c-gone'] = const FailureResult(NotFoundFailure('deleted'));
      final ws = StreamController<WsEnvelope>.broadcast();
      addTearDown(ws.close);

      final container = ProviderContainer.test(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          backendWsMessagesProvider.overrideWith((_) => ws.stream),
        ],
      );

      final children = await container.read(
        fanOutChildrenControllerProvider('parent-1').future,
      );
      expect(children.map((r) => r.id).toList(), <String>['c-ok']);
    });
  });
}
