import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_registry.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_runs_deleter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
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
    if (store.remove(id) == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
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
  /// Active runs reported for the workflow (run id to status).
  Map<String, RunStatus> activeRuns = {};

  /// When set, the deletion waits on this gate before answering.
  Completer<void>? gate;

  /// Progress reported (in order) before the gate is awaited.
  List<WorkflowRunsProgress> script = [];

  /// Result returned after the gate.
  Result<WorkflowRunsDeletion> result = const Success(
    WorkflowRunsDeletion(deletedRuns: 0),
  );

  /// When set, the deletion throws this after the gate.
  Error? thrown;

  final List<(String, String?, bool)> calls = [];

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
    calls.add((workflowId, workspaceId, force));
    if (onProgress case final listener?) script.forEach(listener);
    await gate?.future;
    if (thrown case final error?) throw error;
    return result;
  }
}

final class _RecordingDeletionEvents implements WorkflowDeletionEvents {
  /// Every published event: its kind and the operation snapshot.
  final List<(String, WorkflowDeletionOperation)> events = [];

  @override
  void progress(WorkflowDeletionOperation operation) =>
      events.add(('progress', operation));

  @override
  void deleted(WorkflowDeletionOperation operation) =>
      events.add(('deleted', operation));

  @override
  void failed(WorkflowDeletionOperation operation) =>
      events.add(('failed', operation));
}

void main() {
  late _FakeWorkflowRepository repository;
  late _GatedRunsDeleter deleter;
  late _RecordingDeletionEvents events;
  late WorkflowDeletionRegistry registry;
  late WorkflowService service;
  late int counter;

  WorkflowService buildService({WorkflowDeletionRegistry? deletions}) =>
      WorkflowService(
        repository: repository,
        validator: const WorkflowValidator(),
        runsDeleter: deleter,
        deletions: deletions ?? registry,
        deletionEvents: events,
        generateId: () => 'id-${++counter}',
        now: () => DateTime.utc(2026, 11, 23, 10),
      );

  setUp(() {
    repository = _FakeWorkflowRepository();
    deleter = _GatedRunsDeleter();
    events = _RecordingDeletionEvents();
    registry = WorkflowDeletionRegistry();
    counter = 0;
    service = buildService();
  });

  Future<String> createWorkflow(String name) async {
    final created = (await service.createWorkflow(
      CreateWorkflowRequest(name: name),
    )).valueOrNull!;
    return created.workflow.id;
  }

  Future<WorkflowDeletionOperation> finished(String operationId) =>
      registry.whenFinished(operationId)!;

  test('R1.3 stale revision fails and registers nothing', () async {
    final id = await createWorkflow('Deploy');

    final result = await service.deleteWorkflow(
      id,
      expectedRevision: '0000000000000000',
    );

    expect(result.failureOrNull, isA<StaleRevisionFailure>());
    expect(registry.runningFor(id), isNull);
    expect(deleter.calls, isEmpty);
    expect((await service.getWorkflow(id)).isSuccess, isTrue);
  });

  test('R1.4 active runs without force fail with WorkflowHasActiveRunsFailure '
      'and change nothing', () async {
    final id = await createWorkflow('Deploy');
    deleter.activeRuns = {'r1': RunStatus.running};

    final result = await service.deleteWorkflow(id);

    final failure = result.failureOrNull! as WorkflowHasActiveRunsFailure;
    expect(
      failure.message,
      'Workflow "$id" has 1 active run(s). Stop them, then delete it again.',
    );
    expect(failure.activeRuns, {'r1': RunStatus.running});
    expect(registry.runningFor(id), isNull);
    expect(deleter.calls, isEmpty);
    expect(events.events, isEmpty);
    expect((await service.getWorkflow(id)).isSuccess, isTrue);
  });

  test('R1.2 unknown workflow fails with NotFoundFailure', () async {
    final result = await service.deleteWorkflow('missing');

    expect(result.failureOrNull, isA<NotFoundFailure>());
  });

  test(
    'R13 answers accepted before the slow forced cancellation finishes',
    () async {
      final id = await createWorkflow('Deploy');
      deleter
        ..activeRuns = {'r1': RunStatus.running}
        ..gate = Completer<void>();

      final accepted =
          (await service
                  .deleteWorkflow(id, force: true)
                  .timeout(const Duration(seconds: 1)))
              .valueOrNull!;

      final operation = registry.byId(accepted.operationId)!;
      expect(operation.phase, WorkflowDeletionPhase.stoppingRuns);
      expect(operation.runsToStop, 1);
      expect((await service.getWorkflow(id)).isSuccess, isTrue);

      deleter.gate!.complete();
      await finished(accepted.operationId);
      expect(
        (await service.getWorkflow(id)).failureOrNull,
        isA<NotFoundFailure>(),
      );
    },
  );

  test(
    'R7 while deleting, get and list work and the summary is deleting',
    () async {
      final deleting = await createWorkflow('Deploy');
      final other = await createWorkflow('Other');
      deleter.gate = Completer<void>();
      await service.deleteWorkflow(deleting);

      expect((await service.getWorkflow(deleting)).isSuccess, isTrue);
      final summaries = (await service.listWorkflows()).valueOrNull!.workflows;
      expect(summaries.singleWhere((s) => s.id == deleting).deleting, isTrue);
      expect(summaries.singleWhere((s) => s.id == other).deleting, isFalse);

      deleter.gate!.complete();
    },
  );

  test('R7 while deleting, update fails with WorkflowDeletingFailure carrying '
      'the operation id', () async {
    final id = await createWorkflow('Deploy');
    deleter.gate = Completer<void>();
    final accepted = (await service.deleteWorkflow(id)).valueOrNull!;

    final result = await service.updateWorkflow(
      id,
      const UpdateWorkflowRequest(name: 'Renamed'),
    );

    final failure = result.failureOrNull! as WorkflowDeletingFailure;
    expect(failure.operationId, accepted.operationId);
    deleter.gate!.complete();
  });

  test(
    'R7 while deleting, duplicate fails with WorkflowDeletingFailure',
    () async {
      final id = await createWorkflow('Deploy');
      deleter.gate = Completer<void>();
      await service.deleteWorkflow(id);

      final result = await service.duplicateWorkflow(id);

      expect(result.failureOrNull, isA<WorkflowDeletingFailure>());
      deleter.gate!.complete();
    },
  );

  test('R1.1 a second delete returns the same operation', () async {
    final id = await createWorkflow('Deploy');
    deleter.gate = Completer<void>();
    final first = (await service.deleteWorkflow(id, force: true)).valueOrNull!;

    final second = (await service.deleteWorkflow(
      id,
      expectedRevision: '0000000000000000',
    )).valueOrNull!;

    expect(second.operationId, first.operationId);
    deleter.gate!.complete();
    await finished(first.operationId);
  });

  test('R3/R4/R5 success emits progress then deleted and the finished '
      'operation holds the counters', () async {
    final id = await createWorkflow('Deploy');
    deleter
      ..activeRuns = {'r1': RunStatus.running}
      ..script = [
        const WorkflowRunsProgress(
          phase: WorkflowDeletionPhase.stoppingRuns,
          runsToStop: 1,
          runsStopped: 1,
        ),
        const WorkflowRunsProgress(
          phase: WorkflowDeletionPhase.deletingRuns,
          runsDeleted: 1,
        ),
      ]
      ..result = const Success(
        WorkflowRunsDeletion(deletedRuns: 1, orphanedRuns: ['r9']),
      );

    final accepted = (await service.deleteWorkflow(
      id,
      force: true,
    )).valueOrNull!;
    final operation = await finished(accepted.operationId);

    expect(operation.phase, WorkflowDeletionPhase.done);
    expect(operation.outcome, WorkflowDeletionOutcome.deleted);
    expect(operation.runsDeleted, 1);
    expect(operation.orphanedRuns, ['r9']);
    expect(events.events.first.$1, 'progress');
    expect(events.events.first.$2.phase, WorkflowDeletionPhase.stoppingRuns);
    expect(events.events[events.events.length - 2].$1, 'progress');
    expect(
      events.events[events.events.length - 2].$2.phase,
      WorkflowDeletionPhase.done,
    );
    expect(events.events.last.$1, 'deleted');
    expect(registry.runningFor(id), isNull);
  });

  test('R6 runs deletion failure fails the operation, keeps the workflow and '
      'allows edits again', () async {
    final id = await createWorkflow('Deploy');
    deleter.result = const FailureResult(
      WorkflowHasActiveRunsFailure(
        'busy',
        activeRuns: {'r2': RunStatus.paused},
      ),
    );

    final accepted = (await service.deleteWorkflow(id)).valueOrNull!;
    final operation = await finished(accepted.operationId);

    expect(operation.outcome, WorkflowDeletionOutcome.failed);
    expect(operation.failure, isA<WorkflowHasActiveRunsFailure>());
    expect(events.events.last.$1, 'failed');
    expect(
      (await service.updateWorkflow(
        id,
        const UpdateWorkflowRequest(name: 'Renamed'),
      )).isSuccess,
      isTrue,
    );
  });

  test('R6 workflow delete failure after runs fails the operation with '
      'runsDeleted', () async {
    final id = await createWorkflow('Deploy');
    repository.failDelete = true;
    deleter.result = const Success(WorkflowRunsDeletion(deletedRuns: 2));

    final accepted = (await service.deleteWorkflow(id)).valueOrNull!;
    final operation = await finished(accepted.operationId);

    expect(operation.outcome, WorkflowDeletionOutcome.failed);
    expect(operation.failure, isA<PersistenceFailure>());
    expect(operation.runsDeleted, 2);
    expect(events.events.last.$1, 'failed');
  });

  test(
    'R6 a thrown error fails the operation with UnexpectedFailure',
    () async {
      final id = await createWorkflow('Deploy');
      deleter.thrown = StateError('boom');

      final accepted = (await service.deleteWorkflow(id)).valueOrNull!;
      final operation = await finished(accepted.operationId);

      expect(operation.outcome, WorkflowDeletionOutcome.failed);
      expect(operation.failure, isA<UnexpectedFailure>());
      expect(
        operation.failure!.message,
        'Workflow deletion failed unexpectedly.',
      );
      expect(events.events.last.$1, 'failed');
    },
  );

  test('progress events for a workflow with several runs never decrease '
      'runsDeleted', () async {
    final id = await createWorkflow('Deploy');
    deleter
      ..script = [
        const WorkflowRunsProgress(
          phase: WorkflowDeletionPhase.deletingRuns,
          runsDeleted: 1,
        ),
        const WorkflowRunsProgress(
          phase: WorkflowDeletionPhase.deletingRuns,
          runsDeleted: 2,
        ),
        const WorkflowRunsProgress(
          phase: WorkflowDeletionPhase.deletingRuns,
          runsDeleted: 3,
        ),
      ]
      ..result = const Success(WorkflowRunsDeletion(deletedRuns: 3));

    final accepted = (await service.deleteWorkflow(id)).valueOrNull!;
    await finished(accepted.operationId);

    final counts = events.events
        .where((e) => e.$1 == 'progress')
        .map((e) => e.$2.runsDeleted)
        .toList();
    expect(counts, isNotEmpty);
    for (var i = 1; i < counts.length; i++) {
      expect(counts[i], greaterThanOrEqualTo(counts[i - 1]));
    }
  });

  test(
    'R6 a new delete after a failed operation starts a new operation',
    () async {
      final id = await createWorkflow('Deploy');
      deleter.result = const FailureResult(PersistenceFailure('db'));
      final first = (await service.deleteWorkflow(id)).valueOrNull!;
      await finished(first.operationId);

      deleter.result = const Success(WorkflowRunsDeletion(deletedRuns: 0));
      final second = (await service.deleteWorkflow(id)).valueOrNull!;

      expect(second.operationId, isNot(first.operationId));
      await finished(second.operationId);
    },
  );

  test('R11 a fresh registry (restart) shows the workflow normal', () async {
    final id = await createWorkflow('Deploy');
    deleter.gate = Completer<void>();
    final accepted = (await service.deleteWorkflow(id)).valueOrNull!;

    final restarted = buildService(deletions: WorkflowDeletionRegistry());
    final summaries = (await restarted.listWorkflows()).valueOrNull!.workflows;
    expect(summaries.single.deleting, isFalse);
    expect(
      (await restarted.updateWorkflow(
        id,
        const UpdateWorkflowRequest(name: 'Renamed'),
      )).isSuccess,
      isTrue,
    );

    deleter.gate!.complete();
    await finished(accepted.operationId);
  });
}
