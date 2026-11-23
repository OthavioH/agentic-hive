import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_repository_impl.dart';
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
}) => WorkflowDeletionStatus(
  operationId: 'op-1',
  workflowId: 'wf-1',
  phase: phase,
  startedAt: _now,
  outcome: outcome,
  errorCode: errorCode,
  errorMessage: errorMessage,
);

final class _ScriptedRemote implements WorkflowRemoteDataSource {
  /// Answer to `DELETE`.
  Result<WorkflowDeletionAccepted> deleteResult = const Success(
    WorkflowDeletionAccepted(operationId: 'op-1', workflowId: 'wf-1'),
  );

  /// Answers to successive status reads; the last one repeats.
  List<Result<WorkflowDeletionStatus>> statuses = const [
    FailureResult(NetworkFailure('unused')),
  ];

  /// Answer to `GET /api/v1/workflows/:id`.
  Result<WorkflowResponse> getResult = const FailureResult(
    NotFoundFailure('gone'),
  );

  /// Runs before `deleteWorkflow` answers (may emit events synchronously).
  void Function()? onDelete;

  int statusCalls = 0;
  int deleteCalls = 0;

  @override
  Future<Result<WorkflowDeletionAccepted>> deleteWorkflow(
    String id, {
    String? workspaceId,
  }) async {
    deleteCalls++;
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
    String? workspaceId,
  }) async => getResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final class _FakeDeletionEvents implements WorkflowDeletionEventsSource {
  new(this.controller);

  final StreamController<WorkflowDeletionFinished> controller;

  @override
  Stream<WorkflowDeletionFinished> get finished => controller.stream;
}

void main() {
  late _ScriptedRemote remote;
  late StreamController<WorkflowDeletionFinished> controller;

  setUp(() {
    remote = _ScriptedRemote();
    controller = StreamController<WorkflowDeletionFinished>.broadcast();
  });

  tearDown(() => controller.close());

  WorkflowRepositoryImpl repository({bool withEvents = true}) =>
      WorkflowRepositoryImpl(
        remote,
        deletionEvents: withEvents ? _FakeDeletionEvents(controller) : null,
        pollInterval: _poll,
      );

  test('completes with success when workflow.deleted arrives', () async {
    remote.statuses = [
      Success(_status(phase: WorkflowDeletionPhase.deletingRuns)),
    ];

    final pending = repository().deleteWorkflow('wf-1');
    await pumpEventQueue();
    controller.add(const WorkflowDeletionFinished(operationId: 'op-1'));

    expect((await pending).isSuccess, isTrue);
  });

  test('returns BackendFailure with the event code when workflow.delete.failed '
      'arrives', () async {
    remote.statuses = [
      Success(_status(phase: WorkflowDeletionPhase.deletingRuns)),
    ];

    final pending = repository().deleteWorkflow('wf-1');
    await pumpEventQueue();
    controller.add(
      const WorkflowDeletionFinished(
        operationId: 'op-1',
        failure: BackendFailure(
          'Stop them first.',
          code: ApiErrorCode.workflowHasActiveRuns,
        ),
      ),
    );

    final failure = (await pending).failureOrNull! as BackendFailure;
    expect(failure.code, ApiErrorCode.workflowHasActiveRuns);
    expect(failure.message, 'Stop them first.');
  });

  test(
    'an event that arrives before the DELETE response is not lost',
    () async {
      remote
        ..onDelete = (() {
          controller.add(const WorkflowDeletionFinished(operationId: 'op-1'));
        })
        ..statuses = [
          Success(_status(phase: WorkflowDeletionPhase.deletingRuns)),
        ];

      final result = await repository()
          .deleteWorkflow('wf-1')
          .timeout(_deleteTimeout);

      expect(result.isSuccess, isTrue);
    },
  );

  test('ignores events of other operations', () async {
    remote.statuses = [
      Success(_status(phase: WorkflowDeletionPhase.deletingRuns)),
    ];

    final pending = repository().deleteWorkflow('wf-1');
    await pumpEventQueue();
    controller
      ..add(const WorkflowDeletionFinished(operationId: 'op-9'))
      ..add(
        const WorkflowDeletionFinished(
          operationId: 'op-1',
          failure: BackendFailure('boom', code: ApiErrorCode.conflict),
        ),
      );

    final failure = (await pending).failureOrNull! as BackendFailure;
    expect(failure.code, ApiErrorCode.conflict);
  });

  test('falls back to polling without events', () async {
    remote.statuses = [
      Success(_status(phase: WorkflowDeletionPhase.stoppingRuns)),
      Success(
        _status(
          phase: WorkflowDeletionPhase.done,
          outcome: WorkflowDeletionOutcome.deleted,
        ),
      ),
    ];

    final result = await repository(withEvents: false).deleteWorkflow('wf-1');

    expect(result.isSuccess, isTrue);
    expect(remote.statusCalls, 2);
  });

  test('polling a failed outcome returns BackendFailure(errorMessage, '
      'code: errorCode)', () async {
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

    final failure =
        (await repository(withEvents: false).deleteWorkflow('wf-1'))
                .failureOrNull!
            as BackendFailure;

    expect(failure.message, 'Internal server error.');
    expect(failure.code, ApiErrorCode.internalError);
  });

  test('a 404 on DELETE is success and does not poll', () async {
    remote.deleteResult = const FailureResult(NotFoundFailure('gone'));

    final result = await repository().deleteWorkflow('wf-1');

    expect(result.isSuccess, isTrue);
    expect(remote.statusCalls, 0);
  });

  test('status 404 and workflow gone is success', () async {
    remote
      ..statuses = [const FailureResult(NotFoundFailure('op gone'))]
      ..getResult = const FailureResult(NotFoundFailure('gone'));

    final result = await repository(withEvents: false).deleteWorkflow('wf-1');

    expect(result.isSuccess, isTrue);
  });

  test('status 404 and workflow still present is UnexpectedFailure', () async {
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

    final failure = (await repository(withEvents: false).deleteWorkflow('wf-1'))
        .failureOrNull!;

    expect(failure, isA<UnexpectedFailure>());
    expect(
      failure.message,
      'Workflow deletion was interrupted. Delete it again.',
    );
  });

  test('other DELETE failures are returned unchanged', () async {
    const failure = BackendFailure(
      'busy',
      code: ApiErrorCode.workflowHasActiveRuns,
      statusCode: 409,
    );
    remote.deleteResult = const FailureResult(failure);

    final result = await repository().deleteWorkflow('wf-1');

    expect(result.failureOrNull, same(failure));
  });

  test('cancels its event subscription when done', () async {
    remote.statuses = [
      Success(_status(phase: WorkflowDeletionPhase.deletingRuns)),
    ];

    final pending = repository().deleteWorkflow('wf-1');
    await pumpEventQueue();
    expect(controller.hasListener, isTrue);
    controller.add(const WorkflowDeletionFinished(operationId: 'op-1'));
    await pending;

    expect(controller.hasListener, isFalse);
  });
}
