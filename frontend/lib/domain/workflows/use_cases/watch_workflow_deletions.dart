import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_events.dart';

/// Subscribes to workflow deletions finishing, whichever client started them.
final class WatchWorkflowDeletions {
  /// Creates a [WatchWorkflowDeletions] use case backed by [_source].
  const new(this._source);

  final WorkflowDeletionEventsSource _source;

  /// Returns a stream of [WorkflowDeletionFinished] events.
  Stream<WorkflowDeletionFinished> call() => _source.finished;
}
