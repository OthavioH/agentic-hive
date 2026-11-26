import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

const _pollMs = 10;
const _poll = Duration(milliseconds: _pollMs);
const _deleteTimeoutSeconds = 2;
const _deleteTimeout = Duration(seconds: _deleteTimeoutSeconds);

final _now = DateTime.utc(2026, 11, 23, 10);

WorkflowDeletionStatus _status({
  required WorkflowDeletionPhase phase,
  WorkflowDeletionOutcome? outcome,
  String? errorCode,
  String? errorMessage,
  int runsToStop = 0,
  int runsStopped = 0,
  int runsDeleted = 0,
  List<String> orphanedRuns = const <String>[],
}) => WorkflowDeletionStatus(
  operationId: 'op-1',
  workflowId: 'wf-1',
  phase: phase,
  startedAt: _now,
  outcome: outcome,
  errorCode: errorCode,
  errorMessage: errorMessage,
  runsToStop: runsToStop,
  runsStopped: runsStopped,
  runsDeleted: runsDeleted,
  orphanedRuns: orphanedRuns,
);

final class _ScriptedRemote implements WorkflowRemoteDataSource {
  /// Answer to `DELETE`.
  Result<WorkflowDeletionAccepted> deleteResult = const Success(
    WorkflowDeletionAccepted(operationId: 'op-1', workflowId: 'wf-1'),
  );

  /// Answers to successive status reads; the last one repeats. By default the
  /// operation keeps running, so polling never ends a test early.
  List<Result<WorkflowDeletionStatus>> statuses = [
    Success(_status(phase: WorkflowDeletionPhase.deletingRuns)),
  ];

  /// Answer to `GET /api/v1/workflows/:id`.
  Result<WorkflowResponse> getResult = const FailureResult(
    NotFoundFailure('gone'),
  );

  /// Runs before `deleteWorkflow` answers (may emit events synchronously).
  void Function()? onDelete;

  int statusCalls = 0;
  int deleteCalls = 0;
  String? lastRevision;
  bool? lastForce;

  @override
  Future<Result<WorkflowDeletionAccepted>> deleteWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  }) async {
    deleteCalls++;
    lastRevision = revision;
    lastForce = force;
    onDelete?.call();
    return deleteResult;
  }

  @override
  Future<Result<WorkflowDeletionStatus>> getWorkflowDeletion(
    String operationId,
  ) async {
    statusCalls++;
    final index = statusCalls - 1 < statuses.length
        ? statusCalls - 1
        : statuses.length - 1;
    return statuses[index];
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async => getResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final class _FakeDeletionEvents implements WorkflowDeletionEventsSource {
  new(this.finishedController, this.progressController);

  final StreamController<WorkflowDeletionFinished> finishedController;
  final StreamController<WorkflowDeletionStatus> progressController;

  @override
  Stream<WorkflowDeletionFinished> get finished => finishedController.stream;

  @override
  Stream<WorkflowDeletionStatus> get progress => progressController.stream;
}

Future<List<WorkflowDeletionUpdate>> collect(
  Stream<WorkflowDeletionUpdate> updates,
) => updates.toList().timeout(_deleteTimeout);

void main() {
  late _ScriptedRemote remote;
  late StreamController<WorkflowDeletionFinished> finished;
  late StreamController<WorkflowDeletionStatus> progress;

  setUp(() {
    remote = _ScriptedRemote();
    finished = StreamController<WorkflowDeletionFinished>.broadcast();
    progress = StreamController<WorkflowDeletionStatus>.broadcast();
  });

  tearDown(() async {
    await finished.close();
    await progress.close();
  });

  WorkflowRepositoryImpl repository({bool withEvents = true}) =>
      WorkflowRepositoryImpl(
        remote,
        deletionEvents: withEvents
            ? _FakeDeletionEvents(finished, progress)
            : null,
        pollInterval: _poll,
      );

  test('emits Started then Succeeded with counts when workflow.deleted '
      'arrives', () async {
    final pending = collect(repository().deleteWorkflow('wf-1'));
    await pumpEventQueue();
    finished.add(
      const WorkflowDeletionFinished(
        operationId: 'op-1',
        workflowId: 'wf-1',
        deletedRuns: 2,
        orphanedRuns: ['run-9'],
      ),
    );

    final updates = await pending;

    expect(updates, [
      isA<WorkflowDeletionStarted>().having(
        (u) => u.operationId,
        'operationId',
        'op-1',
      ),
      isA<WorkflowDeletionSucceeded>()
          .having((u) => u.deletedRuns, 'deletedRuns', 2)
          .having((u) => u.orphanedRuns, 'orphanedRuns', ['run-9']),
    ]);
  });

  test('emits Progressed for progress events of its operation and ignores the '
      'done phase', () async {
    final pending = collect(repository().deleteWorkflow('wf-1'));
    await pumpEventQueue();
    progress
      ..add(
        _status(
          phase: WorkflowDeletionPhase.stoppingRuns,
          runsToStop: 3,
          runsStopped: 1,
        ),
      )
      ..add(_status(phase: WorkflowDeletionPhase.done));
    await pumpEventQueue();
    finished.add(
      const WorkflowDeletionFinished(operationId: 'op-1', workflowId: 'wf-1'),
    );

    final updates = await pending;

    expect(updates, [
      isA<WorkflowDeletionStarted>(),
      isA<WorkflowDeletionProgressed>()
          .having((u) => u.phase, 'phase', WorkflowDeletionPhase.stoppingRuns)
          .having((u) => u.runsToStop, 'runsToStop', 3)
          .having((u) => u.runsStopped, 'runsStopped', 1),
      isA<WorkflowDeletionSucceeded>(),
    ]);
  });

  test('emits Failed with the event failure, deletedRuns and orphanedRuns when '
      'workflow.delete.failed arrives', () async {
    final pending = collect(repository().deleteWorkflow('wf-1'));
    await pumpEventQueue();
    finished.add(
      const WorkflowDeletionFinished(
        operationId: 'op-1',
        workflowId: 'wf-1',
        failure: BackendFailure(
          'Stop them first.',
          code: ApiErrorCode.workflowHasActiveRuns,
        ),
        deletedRuns: 1,
        orphanedRuns: ['run-3'],
      ),
    );

    final last = (await pending).last as WorkflowDeletionFailed;

    final failure = last.failure as BackendFailure;
    expect(failure.code, ApiErrorCode.workflowHasActiveRuns);
    expect(failure.message, 'Stop them first.');
    expect(last.deletedRuns, 1);
    expect(last.orphanedRuns, ['run-3']);
  });

  test('events that arrive before the DELETE response are not lost', () async {
    remote.onDelete = () {
      progress.add(
        _status(
          phase: WorkflowDeletionPhase.stoppingRuns,
          runsToStop: 2,
          runsStopped: 1,
        ),
      );
      finished.add(
        const WorkflowDeletionFinished(operationId: 'op-1', workflowId: 'wf-1'),
      );
    };

    final updates = await collect(repository().deleteWorkflow('wf-1'));

    expect(updates, [
      isA<WorkflowDeletionStarted>(),
      isA<WorkflowDeletionProgressed>(),
      isA<WorkflowDeletionSucceeded>(),
    ]);
  });

  test('ignores events of other operations', () async {
    final pending = collect(repository().deleteWorkflow('wf-1'));
    await pumpEventQueue();
    finished
      ..add(
        const WorkflowDeletionFinished(operationId: 'op-9', workflowId: 'wf-9'),
      )
      ..add(
        const WorkflowDeletionFinished(
          operationId: 'op-1',
          workflowId: 'wf-1',
          failure: BackendFailure('boom', code: ApiErrorCode.conflict),
        ),
      );

    final updates = await pending;

    expect(updates, [
      isA<WorkflowDeletionStarted>(),
      isA<WorkflowDeletionFailed>().having(
        (u) => (u.failure as BackendFailure).code,
        'code',
        ApiErrorCode.conflict,
      ),
    ]);
  });

  test('falls back to polling: Progressed from a running status, Succeeded '
      'from done', () async {
    remote.statuses = [
      Success(
        _status(
          phase: WorkflowDeletionPhase.stoppingRuns,
          runsToStop: 2,
          runsStopped: 1,
        ),
      ),
      Success(
        _status(
          phase: WorkflowDeletionPhase.done,
          outcome: WorkflowDeletionOutcome.deleted,
          runsDeleted: 3,
          orphanedRuns: const ['run-9'],
        ),
      ),
    ];

    final updates = await collect(
      repository(withEvents: false).deleteWorkflow('wf-1'),
    );

    expect(updates, [
      isA<WorkflowDeletionStarted>(),
      isA<WorkflowDeletionProgressed>().having(
        (u) => u.runsStopped,
        'runsStopped',
        1,
      ),
      isA<WorkflowDeletionSucceeded>()
          .having((u) => u.deletedRuns, 'deletedRuns', 3)
          .having((u) => u.orphanedRuns, 'orphanedRuns', ['run-9']),
    ]);
    expect(remote.statusCalls, 2);
  });

  test('polling a failed outcome emits Failed(BackendFailure(errorMessage, '
      'code: errorCode))', () async {
    remote.statuses = [
      Success(
        _status(
          phase: WorkflowDeletionPhase.done,
          outcome: WorkflowDeletionOutcome.failed,
          errorCode: ApiErrorCode.internalError,
          errorMessage: 'Internal server error.',
        ),
      ),
    ];

    final last =
        (await collect(repository(withEvents: false).deleteWorkflow('wf-1')))
                .last
            as WorkflowDeletionFailed;

    final failure = last.failure as BackendFailure;
    expect(failure.message, 'Internal server error.');
    expect(failure.code, ApiErrorCode.internalError);
  });

  test(
    'polling a failed outcome without errorMessage emits empty message',
    () async {
      remote.statuses = [
        Success(
          _status(
            phase: WorkflowDeletionPhase.done,
            outcome: WorkflowDeletionOutcome.failed,
            errorCode: ApiErrorCode.internalError,
          ),
        ),
      ];

      final last =
          (await collect(repository(withEvents: false).deleteWorkflow('wf-1')))
                  .last
              as WorkflowDeletionFailed;

      final failure = last.failure as BackendFailure;
      expect(failure.message, isEmpty);
      expect(failure.code, ApiErrorCode.internalError);
    },
  );

  test('a 404 on DELETE emits a single Succeeded and does not poll', () async {
    remote.deleteResult = const FailureResult(NotFoundFailure('gone'));

    final updates = await collect(repository().deleteWorkflow('wf-1'));

    expect(updates, [isA<WorkflowDeletionSucceeded>()]);
    expect(remote.statusCalls, 0);
  });

  test('status 404 and workflow gone emits Succeeded', () async {
    remote
      ..statuses = [const FailureResult(NotFoundFailure('op gone'))]
      ..getResult = const FailureResult(NotFoundFailure('gone'));

    final updates = await collect(
      repository(withEvents: false).deleteWorkflow('wf-1'),
    );

    expect(updates.last, isA<WorkflowDeletionSucceeded>());
  });

  test('status 404 and workflow still present emits Failed(UnexpectedFailure '
      'interrupted)', () async {
    remote
      ..statuses = [const FailureResult(NotFoundFailure('op gone'))]
      ..getResult = Success(
        WorkflowResponse(
          workflow: Workflow(
            id: 'wf-1',
            name: 'Flow',
            nodes: <WorkflowNode>[],
            edges: <WorkflowEdge>[],
            createdAt: _now,
            updatedAt: _now,
          ),
          validation: const WorkflowValidationResult(isValid: true),
        ),
      );

    final last =
        (await collect(repository(withEvents: false).deleteWorkflow('wf-1')))
                .last
            as WorkflowDeletionFailed;

    expect(last.failure, isA<UnexpectedFailure>());
    expect(
      last.failure.message,
      'Workflow deletion was interrupted. Delete it again.',
    );
  });

  test(
    'other DELETE failures emit a single Rejected with the same failure',
    () async {
      const failure = BackendFailure(
        'busy',
        code: ApiErrorCode.workflowHasActiveRuns,
        statusCode: 409,
      );
      remote.deleteResult = const FailureResult(failure);

      final updates = await collect(repository().deleteWorkflow('wf-1'));

      expect(updates, hasLength(1));
      final rejected = updates.single as WorkflowDeletionRejected;
      expect(rejected.failure, same(failure));
    },
  );

  test('forwards revision and force to the data source', () async {
    final pending = collect(
      repository().deleteWorkflow('wf-1', revision: 'r1', force: true),
    );
    await pumpEventQueue();
    finished.add(
      const WorkflowDeletionFinished(operationId: 'op-1', workflowId: 'wf-1'),
    );
    await pending;

    expect(remote.lastRevision, 'r1');
    expect(remote.lastForce, isTrue);
  });

  test('cancels its event subscriptions when it ends', () async {
    final pending = collect(repository().deleteWorkflow('wf-1'));
    await pumpEventQueue();
    expect(finished.hasListener, isTrue);
    expect(progress.hasListener, isTrue);
    finished.add(
      const WorkflowDeletionFinished(operationId: 'op-1', workflowId: 'wf-1'),
    );
    await pending;

    expect(finished.hasListener, isFalse);
    expect(progress.hasListener, isFalse);
  });

  test('cancelling the subscription stops polling', () async {
    final subscription = repository().deleteWorkflow('wf-1').listen((_) {});
    await pumpEventQueue();
    await subscription.cancel();

    await Future<void>.delayed(_poll * 5);
    final callsAfterCancel = remote.statusCalls;
    await Future<void>.delayed(_poll * 5);

    expect(remote.statusCalls, callsAfterCancel);
  });
}
