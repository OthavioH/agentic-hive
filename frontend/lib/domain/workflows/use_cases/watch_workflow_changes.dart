import 'package:agentic_hive_frontend/domain/workflows/workflow_changes_source.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Subscribes to workspace workflow files changing on disk.
final class WatchWorkflowChanges {
  /// Creates a [WatchWorkflowChanges] use case backed by [_source].
  const new(this._source);

  final WorkflowChangesSource _source;

  /// Returns a stream of [WorkflowsChangedPayload] events.
  Stream<WorkflowsChangedPayload> call() => _source.changes;
}
