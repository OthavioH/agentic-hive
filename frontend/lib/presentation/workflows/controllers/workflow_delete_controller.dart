import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/delete_workflow.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workflow_delete_controller.g.dart';

/// Identifies a listed workflow: ids are unique only inside a scope.
typedef WorkflowKey = ({String id, String? workspaceId});

/// The key of [workflow].
WorkflowKey workflowKeyOf(WorkflowSummary workflow) =>
    (id: workflow.id, workspaceId: workflow.workspaceId);

/// Progress of a followed deletion, shown on its row.
@immutable
final class WorkflowDeletionProgressView {
  /// Creates a progress view.
  const new({this.phase, this.runsToStop = 0, this.runsStopped = 0});

  /// Latest phase; `null` until the first progress update.
  final WorkflowDeletionPhase? phase;

  /// Runs the operation must stop before deleting.
  final int runsToStop;

  /// Runs stopped so far.
  final int runsStopped;
}

/// The notice shown on the Workflows page after a delete.
sealed class WorkflowDeleteNotice {
  /// Creates a notice.
  const new();
}

/// The workflow was deleted and no run was kept.
final class WorkflowDeletedNotice extends WorkflowDeleteNotice {
  /// Creates the success notice.
  const new();
}

/// The workflow was deleted but some runs were kept.
final class WorkflowDeletePartialNotice extends WorkflowDeleteNotice {
  /// Creates the partial notice listing [orphanedRunIds].
  const new(this.orphanedRunIds);

  /// Run ids kept, in backend order.
  final List<String> orphanedRunIds;
}

/// The deletion failed; the row is back to normal.
final class WorkflowDeleteFailedNotice extends WorkflowDeleteNotice {
  /// Creates the error notice for [workflow].
  const new({
    required this.workflow,
    required this.failure,
    required this.force,
    this.orphanedRunIds = const <String>[],
  });

  /// The workflow as it was when the delete was requested.
  final WorkflowSummary workflow;

  /// Why the deletion failed.
  final Failure failure;

  /// Whether the failed request stopped active runs first; Retry keeps it.
  final bool force;

  /// Run ids kept by a failed operation, in backend order.
  final List<String> orphanedRunIds;

  /// Whether the failure is a revision conflict. The user then reloads and
  /// confirms the delete again instead of retrying (owner decision).
  bool get isRevisionConflict => switch (failure) {
    BackendFailure(code: ApiErrorCode.revisionConflict) => true,
    _ => false,
  };
}

/// What the page must do after [WorkflowDeleteController.delete] returns.
sealed class WorkflowDeleteOutcome {
  /// Creates an outcome.
  const new();
}

/// Nothing more to ask: accepted, finished, or failed (notice set).
final class WorkflowDeleteHandled extends WorkflowDeleteOutcome {
  /// Creates a handled outcome.
  const new();
}

/// The workflow has [activeRunCount] active runs: ask to stop them.
final class WorkflowDeleteNeedsForce extends WorkflowDeleteOutcome {
  /// Creates a needs-force outcome.
  const new(this.activeRunCount);

  /// Number of active runs the backend refused to delete over.
  final int activeRunCount;
}

/// State of the delete flow: followed deletions, the workflows deleted in this
/// session and the current notice.
@immutable
final class WorkflowDeleteState {
  /// Creates a delete state.
  const new({
    this.progress = const <WorkflowKey, WorkflowDeletionProgressView>{},
    this.removed = const <WorkflowKey>{},
    this.notice,
  });

  /// Followed deletions by workflow.
  final Map<WorkflowKey, WorkflowDeletionProgressView> progress;

  /// Workflows this flow deleted; the list drops them.
  final Set<WorkflowKey> removed;

  /// The notice to show, if any.
  final WorkflowDeleteNotice? notice;

  /// Returns a copy with updated fields. A `notice` callback of `() => null`
  /// clears the notice.
  WorkflowDeleteState copyWith({
    Map<WorkflowKey, WorkflowDeletionProgressView>? progress,
    Set<WorkflowKey>? removed,
    WorkflowDeleteNotice? Function()? notice,
  }) => WorkflowDeleteState(
    progress: progress ?? this.progress,
    removed: removed ?? this.removed,
    notice: notice != null ? notice() : this.notice,
  );
}

/// Drives workflow deletions started from the Workflows page: the deleting
/// rows with their progress and the resulting notice (#101 state matrix).
/// Kept alive so leaving the page does not stop following an operation.
@Riverpod(keepAlive: true)
class WorkflowDeleteController extends _$WorkflowDeleteController {
  final Map<WorkflowKey, StreamSubscription<WorkflowDeletionUpdate>>
  _subscriptions = {};

  @override
  WorkflowDeleteState build() {
    ref.onDispose(() {
      for (final subscription in _subscriptions.values) {
        unawaited(subscription.cancel());
      }
      _subscriptions.clear();
    });
    return const WorkflowDeleteState();
  }

  /// Starts deleting [workflow] through [deleteWorkflow]. [revision] defaults
  /// to the workflow's own revision. Completes when the page knows whether to
  /// ask about active runs.
  Future<WorkflowDeleteOutcome> delete(
    DeleteWorkflow deleteWorkflow,
    WorkflowSummary workflow, {
    bool force = false,
    String? revision,
  }) {
    final key = workflowKeyOf(workflow);
    if (_subscriptions.containsKey(key)) {
      return Future.value(const WorkflowDeleteHandled());
    }
    final first = Completer<WorkflowDeleteOutcome>();
    state = state.copyWith(
      progress: {...state.progress, key: const WorkflowDeletionProgressView()},
      notice: () => null,
    );
    late final StreamSubscription<WorkflowDeletionUpdate> subscription;
    subscription = deleteWorkflow
        .call(
          workflow.id,
          workspaceId: workflow.workspaceId,
          revision: revision ?? workflow.revision,
          force: force,
        )
        .listen(
          (update) => _apply(workflow, key, force, update, first),
          onDone: () {
            if (identical(_subscriptions[key], subscription)) {
              _subscriptions.remove(key);
              if (ref.mounted) {
                state = state.copyWith(progress: _without(key));
              }
            }
            _complete(first, const WorkflowDeleteHandled());
          },
        );
    _subscriptions[key] = subscription;
    return first.future;
  }

  /// Clears the notice and keeps the followed deletions.
  void dismissNotice() => state = state.copyWith(notice: () => null);

  void _apply(
    WorkflowSummary workflow,
    WorkflowKey key,
    bool force,
    WorkflowDeletionUpdate update,
    Completer<WorkflowDeleteOutcome> first,
  ) {
    if (!ref.mounted) return;
    if (update is WorkflowDeletionEnded) _subscriptions.remove(key);
    switch (update) {
      case WorkflowDeletionStarted():
        _complete(first, const WorkflowDeleteHandled());
      case WorkflowDeletionProgressed(
        :final phase,
        :final runsToStop,
        :final runsStopped,
      ):
        state = state.copyWith(
          progress: {
            ...state.progress,
            key: WorkflowDeletionProgressView(
              phase: phase,
              runsToStop: runsToStop,
              runsStopped: runsStopped,
            ),
          },
        );
      case WorkflowDeletionSucceeded(:final orphanedRuns):
        state = state.copyWith(
          progress: _without(key),
          removed: {...state.removed, key},
          notice: () => orphanedRuns.isEmpty
              ? const WorkflowDeletedNotice()
              : WorkflowDeletePartialNotice(orphanedRuns),
        );
        _complete(first, const WorkflowDeleteHandled());
      case WorkflowDeletionRejected(
            failure: BackendFailure(
              code: ApiErrorCode.workflowHasActiveRuns,
              :final details,
            ),
          )
          when details.isNotEmpty:
        state = state.copyWith(progress: _without(key));
        _complete(first, WorkflowDeleteNeedsForce(details.length));
      case WorkflowDeletionRejected(:final failure):
        _fail(workflow, key, force, failure, const <String>[]);
        _complete(first, const WorkflowDeleteHandled());
      case WorkflowDeletionFailed(:final failure, :final orphanedRuns):
        _fail(workflow, key, force, failure, orphanedRuns);
        _complete(first, const WorkflowDeleteHandled());
    }
  }

  void _fail(
    WorkflowSummary workflow,
    WorkflowKey key,
    bool force,
    Failure failure,
    List<String> orphanedRuns,
  ) {
    state = state.copyWith(
      progress: _without(key),
      notice: () => WorkflowDeleteFailedNotice(
        workflow: workflow,
        failure: failure,
        force: force,
        orphanedRunIds: orphanedRuns,
      ),
    );
  }

  Map<WorkflowKey, WorkflowDeletionProgressView> _without(WorkflowKey key) =>
      {...state.progress}..remove(key);

  static void _complete(
    Completer<WorkflowDeleteOutcome> completer,
    WorkflowDeleteOutcome outcome,
  ) {
    if (!completer.isCompleted) completer.complete(outcome);
  }
}
