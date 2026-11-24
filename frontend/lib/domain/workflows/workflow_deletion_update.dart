import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// One step of a workflow deletion followed by the app (ADR 0027).
sealed class WorkflowDeletionUpdate {
  /// Creates a deletion update.
  const new();
}

/// The backend accepted the deletion (`202`) as an operation.
final class WorkflowDeletionStarted extends WorkflowDeletionUpdate {
  /// Creates a started update for [operationId].
  const new({required this.operationId});

  /// Identifier of the accepted operation.
  final String operationId;
}

/// The operation moved to [phase] with these counters.
final class WorkflowDeletionProgressed extends WorkflowDeletionUpdate {
  /// Creates a progress update.
  const new({
    required this.phase,
    this.runsToStop = 0,
    this.runsStopped = 0,
    this.runsDeleted = 0,
  });

  /// Phase the operation is in.
  final WorkflowDeletionPhase phase;

  /// Runs the operation must stop before deleting.
  final int runsToStop;

  /// Runs stopped so far.
  final int runsStopped;

  /// Runs deleted so far.
  final int runsDeleted;
}

/// The last update of a deletion; the stream closes after it.
sealed class WorkflowDeletionEnded extends WorkflowDeletionUpdate {
  /// Creates an ended update.
  const new();
}

/// The backend refused the request synchronously; nothing changed.
final class WorkflowDeletionRejected extends WorkflowDeletionEnded {
  /// Creates a rejected update carrying [failure].
  const new(this.failure);

  /// Why the backend refused the request.
  final Failure failure;
}

/// The workflow is deleted; [orphanedRuns] were kept because their stop could
/// not be confirmed.
final class WorkflowDeletionSucceeded extends WorkflowDeletionEnded {
  /// Creates a succeeded update.
  const new({this.deletedRuns = 0, this.orphanedRuns = const <String>[]});

  /// Runs deleted together with the workflow.
  final int deletedRuns;

  /// Run ids kept after the workflow was deleted, in backend order.
  final List<String> orphanedRuns;
}

/// The accepted operation failed after it started.
final class WorkflowDeletionFailed extends WorkflowDeletionEnded {
  /// Creates a failed update carrying [failure].
  const new(
    this.failure, {
    this.deletedRuns = 0,
    this.orphanedRuns = const <String>[],
  });

  /// Why the operation failed.
  final Failure failure;

  /// Runs deleted before the failure.
  final int deletedRuns;

  /// Run ids kept before the failure, in backend order.
  final List<String> orphanedRuns;
}
