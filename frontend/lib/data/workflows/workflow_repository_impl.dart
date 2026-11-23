import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [WorkflowRepository] backed by [WorkflowRemoteDataSource].
final class WorkflowRepositoryImpl implements WorkflowRepository {
  /// Creates a repository delegating to [_remoteDataSource]; deletions wait on
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

  /// Deletes a workflow and waits for its operation to finish (ADR 0027).
  ///
  /// A `404` on the request itself counts as success (already deleted). The
  /// finish event wins when it arrives; otherwise the status is polled.
  @override
  Future<Result<void>> deleteWorkflow(String id, {String? workspaceId}) async {
    final buffered = <String, WorkflowDeletionFinished>{};
    final completion = Completer<Result<void>>();
    String? operationId;
    final subscription = _deletionEvents?.finished.listen((event) {
      buffered[event.operationId] = event;
      if (event.operationId == operationId) {
        _complete(completion, _resultForEvent(event));
      }
    });
    try {
      final deletion = await _remoteDataSource.deleteWorkflow(
        id,
        workspaceId: workspaceId,
      );
      if (deletion case FailureResult<WorkflowDeletionAccepted>(
        :final failure,
      )) {
        if (failure is NotFoundFailure) return const Success(null);
        return FailureResult(failure);
      }
      final acceptedId = deletion.valueOrNull!.operationId;
      operationId = acceptedId;
      final early = buffered[acceptedId];
      if (early != null) _complete(completion, _resultForEvent(early));
      unawaited(_pollUntilFinished(id, workspaceId, acceptedId, completion));
      return await completion.future;
    } finally {
      await subscription?.cancel();
    }
  }

  Future<void> _pollUntilFinished(
    String id,
    String? workspaceId,
    String operationId,
    Completer<Result<void>> completion,
  ) async {
    while (!completion.isCompleted) {
      await Future<void>.delayed(pollInterval);
      if (completion.isCompleted) return;
      final status = await _remoteDataSource.getWorkflowDeletion(operationId);
      switch (status) {
        case Success(:final value)
            when value.phase == WorkflowDeletionPhase.done:
          _complete(
            completion,
            value.outcome == WorkflowDeletionOutcome.deleted
                ? const Success(null)
                : FailureResult(
                    BackendFailure(
                      value.errorMessage ?? 'Workflow deletion failed.',
                      code: value.errorCode,
                    ),
                  ),
          );
        case Success():
          break;
        case FailureResult(:final failure) when failure is NotFoundFailure:
          _complete(
            completion,
            await _resultForVanishedOperation(id, workspaceId),
          );
        case FailureResult(:final failure):
          _complete(completion, FailureResult(failure));
      }
    }
  }

  /// The operation is gone (restart or eviction): the workflow being absent
  /// means it was deleted; still present means the operation was lost.
  Future<Result<void>> _resultForVanishedOperation(
    String id,
    String? workspaceId,
  ) async {
    final current = await _remoteDataSource.getWorkflow(
      id,
      workspaceId: workspaceId,
    );
    return switch (current) {
      Success() => const FailureResult(
        UnexpectedFailure(
          'Workflow deletion was interrupted. Delete it again.',
        ),
      ),
      FailureResult(:final failure) when failure is NotFoundFailure =>
        const Success(null),
      FailureResult(:final failure) => FailureResult(failure),
    };
  }

  static void _complete(
    Completer<Result<void>> completion,
    Result<void> result,
  ) {
    if (!completion.isCompleted) completion.complete(result);
  }

  Result<void> _resultForEvent(WorkflowDeletionFinished event) =>
      event.failure == null
      ? const Success(null)
      : FailureResult(event.failure!);

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) => _remoteDataSource.validateWorkflow(workflow);
}
