import 'dart:async';

import 'package:agentic_hive_backend/src/api/workflows/workflow_deletion_handler.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_runs_deleter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _MemoryWorkflowRepository implements WorkflowRepository {
  final store = <String, Workflow>{};

  /// When true, `delete` fails with a persistence failure.
  bool failDelete = false;

  @override
  Future<Result<Workflow>> create(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (failDelete) return const FailureResult(PersistenceFailure('db'));
    store.remove(id);
    return const Success<void>(null);
  }

  @override
  Future<Result<Workflow>> getById(String id) async {
    final workflow = store[id];
    if (workflow == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return Success(workflow);
  }

  @override
  Future<Result<List<Workflow>>> listAll() async =>
      Success(store.values.toList());

  @override
  Future<Result<Workflow>> update(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }
}

final class _GatedRunsDeleter implements WorkflowRunsDeleter {
  Map<String, RunStatus> activeRuns = const {};
  Completer<void>? gate;

  @override
  Future<Result<Map<String, RunStatus>>> activeRunsOfWorkflow(
    String workflowId, {
    String? workspaceId,
  }) async => Success(activeRuns);

  @override
  Future<Result<WorkflowRunsDeletion>> deleteRunsOfWorkflow(
    String workflowId, {
    String? workspaceId,
    bool force = false,
    WorkflowRunsProgressListener? onProgress,
  }) async {
    await gate?.future;
    return const Success(WorkflowRunsDeletion(deletedRuns: 0));
  }
}

void main() {
  late _MemoryWorkflowRepository repository;
  late _GatedRunsDeleter deleter;
  late WorkflowService service;
  late Handler handler;

  setUp(() {
    repository = _MemoryWorkflowRepository();
    deleter = _GatedRunsDeleter();
    var counter = 0;
    service = WorkflowService(
      repository: repository,
      validator: const WorkflowValidator(),
      runsDeleter: deleter,
      generateId: () => 'id-${++counter}',
      now: () => DateTime.utc(2026, 11, 23, 10),
    );
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 2),
        ),
        version: '0.1.0',
        dataDir: '/tmp',
        startedAt: DateTime.utc(2026, 11, 23, 9),
      ),
      webSocketHandler: (_) => Response(418),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      workflowDeletionHandler: WorkflowDeletionHandler(service: service),
    );
  });

  Future<String> createWorkflow() async => (await service.createWorkflow(
    const CreateWorkflowRequest(name: 'Deploy'),
  )).valueOrNull!.workflow.id;

  test(
    'GET /api/v1/workflow-deletions/<id> answers 200 with the status',
    () async {
      final id = await createWorkflow();
      deleter
        ..activeRuns = {'r1': RunStatus.running}
        ..gate = Completer<void>();
      final accepted = (await service.deleteWorkflow(
        id,
        force: true,
      )).valueOrNull!;

      final resp = await handler(
        buildRequest('/api/v1/workflow-deletions/${accepted.operationId}'),
      );

      expect(resp.statusCode, 200);
      final status = WorkflowDeletionStatus.fromJson(await readJson(resp));
      expect(status.operationId, accepted.operationId);
      expect(status.workflowId, id);
      expect(status.phase, WorkflowDeletionPhase.stoppingRuns);
      expect(status.runsToStop, 1);

      deleter.gate!.complete();
      await service.whenDeletionFinished(accepted.operationId);
    },
  );

  test('a finished failed operation exposes errorCode and errorMessage from '
      'the failure mapping', () async {
    final id = await createWorkflow();
    repository.failDelete = true;
    final accepted = (await service.deleteWorkflow(id)).valueOrNull!;
    await service.whenDeletionFinished(accepted.operationId);

    final resp = await handler(
      buildRequest('/api/v1/workflow-deletions/${accepted.operationId}'),
    );

    expect(resp.statusCode, 200);
    final status = WorkflowDeletionStatus.fromJson(await readJson(resp));
    expect(status.phase, WorkflowDeletionPhase.done);
    expect(status.outcome, WorkflowDeletionOutcome.failed);
    expect(status.errorCode, ApiErrorCode.internalError);
    expect(status.errorMessage, 'Internal server error.');
  });

  test('an unknown operation answers 404 not_found', () async {
    final resp = await handler(
      buildRequest('/api/v1/workflow-deletions/unknown'),
    );

    expect(resp.statusCode, 404);
    expect(ApiError.fromJson(await readJson(resp)).code, ApiErrorCode.notFound);
  });
}
