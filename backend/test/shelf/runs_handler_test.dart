import 'dart:convert';

import 'package:agentic_hive_backend/src/api/runs/runs_handler.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_registry.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _FakeRunRepository implements RunRepository {
  final store = <String, Run>{};
  final Map<String, int> checkpointCounts = {};

  @override
  Future<Result<Run>> create(Run run) async {
    store[run.id] = run;
    return Success(run);
  }

  @override
  Future<Result<void>> delete(String id) async {
    final existing = store[id];
    if (existing == null) {
      return FailureResult(NotFoundFailure('Run "$id" not found.'));
    }
    if (existing.status.isActive) {
      return FailureResult(
        ConflictFailure(
          'Cannot delete active run "$id" with status '
          '"${existing.status.name}".',
        ),
      );
    }
    store.remove(id);
    return const Success<void>(null);
  }

  @override
  Future<Result<List<String>>> deleteAllOfWorkflow(
    String workflowId, {
    String? workspaceId,
    Set<String> orphanIds = const {},
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> markInterruptedWithEvent(
    String runId, {
    required String eventId,
    required DateTime createdAt,
    JsonMap payload = const {},
  }) async {
    final existing = store[runId];
    if (existing == null || existing.status != RunStatus.running) {
      return FailureResult(NotFoundFailure('Running run "$runId" not found.'));
    }
    final updated = existing.copyWith(status: RunStatus.interrupted);
    store[runId] = updated;
    return Success(updated);
  }

  @override
  Future<Result<Run>> markCancellationUncertainWithEvent(
    String runId, {
    required String eventId,
    required DateTime createdAt,
    JsonMap payload = const {},
  }) async {
    final existing = store[runId];
    if (existing == null || existing.status != RunStatus.cancelling) {
      return FailureResult(
        NotFoundFailure('Cancelling run "$runId" not found.'),
      );
    }
    final updated = existing.copyWith(status: RunStatus.cancellationUncertain);
    store[runId] = updated;
    return Success(updated);
  }

  @override
  Future<Result<Run>> getById(String id) async {
    final run = store[id];
    if (run == null) {
      return FailureResult(NotFoundFailure('Run "$id" not found.'));
    }
    return Success(run);
  }

  @override
  Future<Result<({List<RunSummary> items, int total})>> list({
    RunStatus? status,
    String? workflowId,
    int limit = 50,
    int offset = 0,
  }) async {
    final filtered = store.values.where((run) {
      if (status != null && run.status != status) return false;
      if (workflowId != null && run.workflowId != workflowId) return false;
      return true;
    }).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final page = filtered.skip(offset).take(limit).map((run) {
      return RunSummary(
        id: run.id,
        workflowId: run.workflowId,
        workflowName: run.workflowName,
        status: run.status,
        startedAt: run.startedAt,
        finishedAt: run.finishedAt,
        checkpointCount: checkpointCounts[run.id] ?? 0,
      );
    }).toList();

    return Success((items: page, total: filtered.length));
  }

  @override
  Future<Result<List<Run>>> listByStatus(RunStatus status) async {
    final items = store.values.where((r) => r.status == status).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return Success(items);
  }

  @override
  Future<Result<int>> countByStatusFinishedSince(
    RunStatus status, {
    required DateTime finishedSince,
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> updateStatus(
    String id, {
    required RunStatus status,
    DateTime? finishedAt,
    String? errorMessage,
    bool clearFinishedAt = false,
    bool clearErrorMessage = false,
  }) async {
    final existing = store[id];
    if (existing == null) {
      return FailureResult(NotFoundFailure('Run "$id" not found.'));
    }
    final updated = existing.copyWith(
      status: status,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? existing.finishedAt),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? existing.errorMessage),
    );
    store[id] = updated;
    return Success(updated);
  }
}

final class _FakeCheckpointRepository implements CheckpointRepository {
  final List<Checkpoint> items = [];

  @override
  Future<Result<Checkpoint>> append({
    required String id,
    required String runId,
    required List<String> pendingNodeIds,
    required Map<String, int> attemptsByEdge,
    required int circuitBreakerCount,
    required Map<String, JsonMap> nodeOutputs,
    required DateTime createdAt,
    String? completedNodeId,
    int? sequence,
  }) async {
    final existing = items.where((c) => c.runId == runId).length;
    final cp = Checkpoint(
      id: id,
      runId: runId,
      sequence: sequence ?? existing + 1,
      completedNodeId: completedNodeId,
      pendingNodeIds: pendingNodeIds,
      attemptsByEdge: attemptsByEdge,
      circuitBreakerCount: circuitBreakerCount,
      nodeOutputs: nodeOutputs,
      createdAt: createdAt,
    );
    items.add(cp);
    return Success(cp);
  }

  @override
  Future<Result<Checkpoint?>> getLatestForRun(String runId) async {
    final matching = items.where((c) => c.runId == runId).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return Success(matching.isEmpty ? null : matching.last);
  }

  @override
  Future<Result<List<Checkpoint>>> listForRun(String runId) async {
    final matching = items.where((c) => c.runId == runId).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return Success(matching);
  }
}

final class _FakeRunEventRepository implements RunEventRepository {
  final List<RunEvent> items = [];

  @override
  Future<Result<RunEvent>> append({
    required String id,
    required String runId,
    required RunEventType type,
    required DateTime createdAt,
    String? nodeId,
    String? edgeId,
    JsonMap payload = const {},
    int? sequence,
  }) async {
    final existing = items.where((e) => e.runId == runId).length;
    final event = RunEvent(
      id: id,
      runId: runId,
      sequence: sequence ?? existing + 1,
      type: type,
      nodeId: nodeId,
      edgeId: edgeId,
      payload: payload,
      createdAt: createdAt,
    );
    items.add(event);
    return Success(event);
  }

  @override
  Future<Result<({List<RunEvent> items, int lastSequence})>> listForRun(
    String runId, {
    int? afterSequence,
    int? limit,
  }) async {
    var matching =
        items
            .where(
              (e) =>
                  e.runId == runId &&
                  (afterSequence == null || e.sequence > afterSequence),
            )
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (limit != null) {
      matching = matching.take(limit).toList();
    }
    final lastSeq = matching.isNotEmpty
        ? matching.last.sequence
        : (afterSequence ?? 0);
    return Success((items: matching, lastSequence: lastSeq));
  }

  @override
  Future<Result<Map<String, Map<String, DateTime>>>> findExecutingNodesForRuns(
    List<String> runIds,
  ) => throw UnimplementedError();
}

void main() {
  late _FakeRunRepository runsRepo;
  late _FakeCheckpointRepository checkpointsRepo;
  late _FakeRunEventRepository eventsRepo;
  late WorkflowDeletionRegistry deletions;
  late Handler handler;

  final workflow = Workflow(
    id: 'wf-1',
    name: 'Build Flow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Plan',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 10),
    updatedAt: DateTime.utc(2026, 11, 20, 10),
  );

  Run makeRun({
    required String id,
    required RunStatus status,
    required DateTime startedAt,
    String? workflowId = 'wf-1',
  }) => Run(
    id: id,
    workflowId: workflowId,
    workflowName: 'Build Flow',
    workflowDefinition: workflow,
    workspacePath: '/tmp/ws',
    status: status,
    startedAt: startedAt,
  );

  setUp(() {
    runsRepo = _FakeRunRepository();
    checkpointsRepo = _FakeCheckpointRepository();
    eventsRepo = _FakeRunEventRepository();
    deletions = WorkflowDeletionRegistry();
    final service = RunService(
      runs: runsRepo,
      checkpoints: checkpointsRepo,
      events: eventsRepo,
      deletions: deletions,
    );
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 3),
        ),
        version: '0.1.0',
        dataDir: '/tmp',
        startedAt: DateTime.utc(2026, 11, 20, 11),
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (_) => Response(418),
      runsHandler: RunsHandler(service: service),
    );
  });

  group('GET /api/v1/runs', () {
    test('lists runs with filters and pagination', () async {
      await runsRepo.create(
        makeRun(
          id: 'r1',
          status: RunStatus.succeeded,
          startedAt: DateTime.utc(2026, 11, 20, 10),
        ),
      );
      await runsRepo.create(
        makeRun(
          id: 'r2',
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 20, 11),
          workflowId: 'wf-2',
        ),
      );
      await runsRepo.create(
        makeRun(
          id: 'r3',
          status: RunStatus.succeeded,
          startedAt: DateTime.utc(2026, 11, 20, 12),
        ),
      );

      final allResp = await handler(buildRequest('/api/v1/runs'));
      expect(allResp.statusCode, 200);
      final allDto = RunsListResponse.fromJson(await readJson(allResp));
      expect(allDto.total, 3);
      expect(allDto.items.map((r) => r.id), ['r3', 'r2', 'r1']);

      final filteredResp = await handler(
        buildRequest(
          '/api/v1/runs?status=succeeded&workflowId=wf-1&limit=1&offset=1',
        ),
      );
      expect(filteredResp.statusCode, 200);
      final filteredDto = RunsListResponse.fromJson(
        await readJson(filteredResp),
      );
      expect(filteredDto.total, 2);
      expect(filteredDto.items.map((r) => r.id), ['r1']);
    });

    test('rejects invalid query parameters with 400 bad_request', () async {
      for (final path in [
        '/api/v1/runs?status=invalid',
        '/api/v1/runs?limit=0',
        '/api/v1/runs?limit=abc',
        '/api/v1/runs?offset=-1',
      ]) {
        final resp = await handler(buildRequest(path));
        expect(resp.statusCode, 400, reason: path);
        expect(
          ApiError.fromJson(await readJson(resp)).code,
          ApiErrorCode.badRequest,
        );
      }
    });
  });

  group('GET /api/v1/runs/:id', () {
    test('returns 200 for existing run and 404 for missing', () async {
      final run = makeRun(
        id: 'r1',
        status: RunStatus.paused,
        startedAt: DateTime.utc(2026, 11, 20, 10),
      );
      await runsRepo.create(run);

      final okResp = await handler(buildRequest('/api/v1/runs/r1'));
      expect(okResp.statusCode, 200);
      expect(Run.fromJson(await readJson(okResp)), run);

      final missingResp = await handler(buildRequest('/api/v1/runs/missing'));
      expect(missingResp.statusCode, 404);
      expect(
        ApiError.fromJson(await readJson(missingResp)).code,
        ApiErrorCode.notFound,
      );
    });
  });

  group('GET /api/v1/runs/:id/events', () {
    test(
      'returns events with afterSequence and limit, or 404 if run missing',
      () async {
        await runsRepo.create(
          makeRun(
            id: 'r1',
            status: RunStatus.running,
            startedAt: DateTime.utc(2026, 11, 20, 10),
          ),
        );
        for (var i = 1; i <= 3; i++) {
          await eventsRepo.append(
            id: 'ev-$i',
            runId: 'r1',
            type: RunEventType.nodeStarted,
            nodeId: 'n$i',
            createdAt: DateTime.utc(2026, 11, 20, 10, i),
          );
        }

        final resp = await handler(
          buildRequest('/api/v1/runs/r1/events?afterSequence=1&limit=1'),
        );
        expect(resp.statusCode, 200);
        final dto = RunEventsResponse.fromJson(await readJson(resp));
        expect(dto.items.map((e) => e.sequence), [2]);
        expect(dto.lastSequence, 2);

        final missingResp = await handler(
          buildRequest('/api/v1/runs/missing/events'),
        );
        expect(missingResp.statusCode, 404);
      },
    );
  });

  group('GET /api/v1/runs/:id/checkpoints', () {
    test('returns checkpoints ordered ASC and supports ?latest=true', () async {
      await runsRepo.create(
        makeRun(
          id: 'r1',
          status: RunStatus.succeeded,
          startedAt: DateTime.utc(2026, 11, 20, 10),
        ),
      );
      await checkpointsRepo.append(
        id: 'cp-1',
        runId: 'r1',
        pendingNodeIds: const ['n2'],
        attemptsByEdge: const {},
        circuitBreakerCount: 0,
        nodeOutputs: const {},
        createdAt: DateTime.utc(2026, 11, 20, 10, 1),
      );
      await checkpointsRepo.append(
        id: 'cp-2',
        runId: 'r1',
        pendingNodeIds: const [],
        attemptsByEdge: const {},
        circuitBreakerCount: 0,
        nodeOutputs: const {},
        createdAt: DateTime.utc(2026, 11, 20, 10, 2),
      );

      final allResp = await handler(
        buildRequest('/api/v1/runs/r1/checkpoints'),
      );
      expect(allResp.statusCode, 200);
      expect(
        RunCheckpointsResponse.fromJson(await readJson(allResp)).items
            .map((c) => c.sequence),
        [1, 2],
      );

      final latestResp = await handler(
        buildRequest('/api/v1/runs/r1/checkpoints?latest=true'),
      );
      expect(latestResp.statusCode, 200);
      expect(
        RunCheckpointsResponse.fromJson(await readJson(latestResp)).items
            .map((c) => c.sequence),
        [2],
      );

      final missingResp = await handler(
        buildRequest('/api/v1/runs/missing/checkpoints'),
      );
      expect(missingResp.statusCode, 404);
    });
  });

  group('DELETE /api/v1/runs/:id', () {
    test(
      'deletes non-active run (204), rejects active runs (409), 404 on missing',
      () async {
        await runsRepo.create(
          makeRun(
            id: 'r-running',
            status: RunStatus.running,
            startedAt: DateTime.utc(2026, 11, 20, 10),
          ),
        );
        await runsRepo.create(
          makeRun(
            id: 'r-paused',
            status: RunStatus.paused,
            startedAt: DateTime.utc(2026, 11, 20, 10),
          ),
        );
        await runsRepo.create(
          makeRun(
            id: 'r-interrupted',
            status: RunStatus.interrupted,
            startedAt: DateTime.utc(2026, 11, 20, 10),
          ),
        );

        for (final activeId in ['r-running', 'r-paused']) {
          final conflictResp = await handler(
            buildRequest('/api/v1/runs/$activeId', method: 'DELETE'),
          );
          expect(conflictResp.statusCode, 409);
          expect(
            ApiError.fromJson(await readJson(conflictResp)).code,
            ApiErrorCode.conflict,
          );
        }

        final deleteResp = await handler(
          buildRequest('/api/v1/runs/r-interrupted', method: 'DELETE'),
        );
        expect(deleteResp.statusCode, 204);

        final missingResp = await handler(
          buildRequest('/api/v1/runs/r-interrupted', method: 'DELETE'),
        );
        expect(missingResp.statusCode, 404);
      },
    );

    test('rejects Origin header with 403', () async {
      final resp = await handler(
        buildRequest(
          '/api/v1/runs',
          headers: {'origin': 'http://evil.example'},
        ),
      );
      expect(resp.statusCode, 403);
      expect(
        ApiError.fromJson(await readJson(resp)).code,
        ApiErrorCode.originNotAllowed,
      );
    });
  });

  group('POST /api/v1/runs/:id/resume', () {
    test('answers 409 workflow_deleting with details.operationId while the '
        'workflow is being deleted', () async {
      await runsRepo.create(
        makeRun(
          id: 'r-interrupted',
          status: RunStatus.interrupted,
          startedAt: DateTime.utc(2026, 11, 20, 10),
        ),
      );
      deletions.start(
        WorkflowDeletionOperation(
          id: 'op-1',
          workflowId: 'wf-1',
          phase: WorkflowDeletionPhase.deletingRuns,
          startedAt: DateTime.utc(2026, 11, 23, 10),
        ),
      );

      final resp = await handler(
        buildRequest('/api/v1/runs/r-interrupted/resume', method: 'POST'),
      );

      expect(resp.statusCode, 409);
      final error = ApiError.fromJson(await readJson(resp));
      expect(error.code, ApiErrorCode.workflowDeleting);
      expect(error.details, {'operationId': 'op-1'});
    });
  });

  group('POST /api/v1/runs', () {
    test('rejects input exceeding 64 KiB with 400 bad_request', () async {
      final oversized = 'a' * (RunService.maxInputBytes + 1);
      final resp = await handler(
        buildRequest(
          '/api/v1/runs',
          method: 'POST',
          body: jsonEncode({
            'workflowId': 'wf-1',
            'workspacePath': '/tmp/ws',
            'input': oversized,
          }),
        ),
      );
      expect(resp.statusCode, 400);
      expect(
        ApiError.fromJson(await readJson(resp)).code,
        ApiErrorCode.badRequest,
      );
    });
  });
}
