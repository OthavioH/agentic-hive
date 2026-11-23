import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [WorkflowRepository] backed by [WorkflowRemoteDataSource].
final class WorkflowRepositoryImpl implements WorkflowRepository {
  /// Creates a repository delegating to [_remoteDataSource]; deletions follow
  /// [_deletionEvents] and fall back to polling every [pollInterval].
  new(
    this._remoteDataSource, {
    this._deletionEvents,
    this.pollInterval = defaultPollInterval,
  });

  static const _pollIntervalSeconds = 1;

  /// Default delay between deletion status requests when no event arrives.
  static const Duration defaultPollInterval = Duration(
    seconds: _pollIntervalSeconds,
  );

  final WorkflowRemoteDataSource _remoteDataSource;
  final WorkflowDeletionEventsSource? _deletionEvents;

  /// Delay between status requests while awaiting deletion.
  final Duration pollInterval;

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({String? workspaceId}) =>
      _remoteDataSource.listWorkflows(workspaceId: workspaceId);

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  }) => _remoteDataSource.getWorkflow(id, workspaceId: workspaceId);

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) => _remoteDataSource.createWorkflow(request);

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) => _remoteDataSource.updateWorkflow(id, request, workspaceId: workspaceId);

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) => _remoteDataSource.duplicateWorkflow(
    id,
    name: name,
    workspaceId: workspaceId,
  );

  /// Follows a deletion (ADR 0027): live events win and the status is polled
  /// every [pollInterval] as a fallback. A `404` on the request is success
  /// (already deleted). Events that arrive before the `202` are kept.
  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    String? workspaceId,
    String? revision,
    bool force = false,
  }) {
    final out = StreamController<WorkflowDeletionUpdate>();
    final ended = Completer<void>();
    out.onListen = () {
      unawaited(
        _follow(
          out,
          ended,
          id,
          workspaceId: workspaceId,
          revision: revision,
          force: force,
        ),
      );
    };
    out.onCancel = () {
      if (!ended.isCompleted) ended.complete();
    };
    return out.stream;
  }

  Future<void> _follow(
    StreamController<WorkflowDeletionUpdate> out,
    Completer<void> ended,
    String id, {
    required String? workspaceId,
    required String? revision,
    required bool force,
  }) async {
    String? operationId;
    final earlyProgress = <WorkflowDeletionStatus>[];
    final earlyFinished = <WorkflowDeletionFinished>[];

    void emit(WorkflowDeletionUpdate update) {
      if (ended.isCompleted) return;
      out.add(update);
      if (update is WorkflowDeletionEnded) ended.complete();
    }

    void onProgress(WorkflowDeletionStatus status) {
      if (operationId == null) {
        earlyProgress.add(status);
        return;
      }
      if (status.operationId != operationId) return;
      if (status.phase == WorkflowDeletionPhase.done) return;
      emit(_progressed(status));
    }

    void onFinished(WorkflowDeletionFinished event) {
      if (operationId == null) {
        earlyFinished.add(event);
        return;
      }
      if (event.operationId != operationId) return;
      emit(_endedFor(event));
    }

    final events = _deletionEvents;
    final subscriptions = <StreamSubscription<Object?>>[
      if (events != null) ...<StreamSubscription<Object?>>[
        events.progress.listen(onProgress),
        events.finished.listen(onFinished),
      ],
    ];
    try {
      final accepted = await _remoteDataSource.deleteWorkflow(
        id,
        workspaceId: workspaceId,
        revision: revision,
        force: force,
      );
      switch (accepted) {
        case FailureResult(:final failure) when failure is NotFoundFailure:
          emit(const WorkflowDeletionSucceeded());
        case FailureResult(:final failure):
          emit(WorkflowDeletionRejected(failure));
        case Success(:final value):
          operationId = value.operationId;
          emit(WorkflowDeletionStarted(operationId: value.operationId));
          earlyProgress.forEach(onProgress);
          earlyFinished.forEach(onFinished);
          unawaited(_poll(id, workspaceId, value.operationId, ended, emit));
          await ended.future;
      }
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await out.close();
    }
  }

  Future<void> _poll(
    String id,
    String? workspaceId,
    String operationId,
    Completer<void> ended,
    void Function(WorkflowDeletionUpdate) emit,
  ) async {
    while (!ended.isCompleted) {
      await Future<void>.delayed(pollInterval);
      if (ended.isCompleted) return;
      final status = await _remoteDataSource.getWorkflowDeletion(operationId);
      if (ended.isCompleted) return;
      switch (status) {
        case Success(:final value)
            when value.phase == WorkflowDeletionPhase.done:
          emit(
            value.outcome == WorkflowDeletionOutcome.deleted
                ? WorkflowDeletionSucceeded(
                    deletedRuns: value.runsDeleted,
                    orphanedRuns: value.orphanedRuns,
                  )
                : WorkflowDeletionFailed(
                    BackendFailure(
                      value.errorMessage ?? '',
                      code: value.errorCode,
                    ),
                    deletedRuns: value.runsDeleted,
                    orphanedRuns: value.orphanedRuns,
                  ),
          );
        case Success(:final value):
          emit(_progressed(value));
        case FailureResult(:final failure) when failure is NotFoundFailure:
          emit(await _endedForVanishedOperation(id, workspaceId));
        case FailureResult(:final failure):
          emit(WorkflowDeletionFailed(failure));
      }
    }
  }

  /// The operation is gone (restart or eviction): the workflow being absent
  /// means it was deleted; still present means the operation was lost.
  Future<WorkflowDeletionEnded> _endedForVanishedOperation(
    String id,
    String? workspaceId,
  ) async {
    final current = await _remoteDataSource.getWorkflow(
      id,
      workspaceId: workspaceId,
    );
    return switch (current) {
      Success() => const WorkflowDeletionFailed(
        UnexpectedFailure(
          'Workflow deletion was interrupted. Delete it again.',
        ),
      ),
      FailureResult(:final failure) when failure is NotFoundFailure =>
        const WorkflowDeletionSucceeded(),
      FailureResult(:final failure) => WorkflowDeletionFailed(failure),
    };
  }

  static WorkflowDeletionProgressed _progressed(
    WorkflowDeletionStatus status,
  ) => WorkflowDeletionProgressed(
    phase: status.phase,
    runsToStop: status.runsToStop,
    runsStopped: status.runsStopped,
    runsDeleted: status.runsDeleted,
  );

  static WorkflowDeletionEnded _endedFor(WorkflowDeletionFinished event) {
    final failure = event.failure;
    return failure == null
        ? WorkflowDeletionSucceeded(
            deletedRuns: event.deletedRuns,
            orphanedRuns: event.orphanedRuns,
          )
        : WorkflowDeletionFailed(
            failure,
            deletedRuns: event.deletedRuns,
            orphanedRuns: event.orphanedRuns,
          );
  }

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) => _remoteDataSource.validateWorkflow(workflow);
}
