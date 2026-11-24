import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// A workflow deletion operation finished, as reported by the backend
/// WebSocket. It may come from this app or from another client.
final class WorkflowDeletionFinished {
  /// Creates a completion event.
  const new({
    required this.operationId,
    required this.workflowId,
    this.workspaceId,
    this.failure,
    this.deletedRuns = 0,
    this.orphanedRuns = const <String>[],
  });

  /// Operation identifier.
  final String operationId;

  /// Identifier of the deleted workflow.
  final String workflowId;

  /// Workspace of the workflow; `null` for a global workflow.
  final String? workspaceId;

  /// Operation failure, when it failed.
  final Failure? failure;

  /// Runs deleted by the operation.
  final int deletedRuns;

  /// Run ids kept by the operation, in backend order.
  final List<String> orphanedRuns;
}

/// Live feed of workflow deletions from the backend WebSocket.
abstract interface class WorkflowDeletionEventsSource {
  /// Finished operations, whichever client started them.
  Stream<WorkflowDeletionFinished> get finished;

  /// Progress snapshots (`workflow.delete.progress`).
  Stream<WorkflowDeletionStatus> get progress;
}
