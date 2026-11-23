import 'package:agentic_hive_frontend/domain/workspace/workspace_tree_changes_source.dart';

/// Subscribes to changes that affect the side rail tree.
final class WatchWorkspaceTreeChanges {
  /// Creates a [WatchWorkspaceTreeChanges] use case backed by [_source].
  const new(this._source);

  final WorkspaceTreeChangesSource _source;

  /// Returns a stream of [WorkspaceTreeChange] events.
  Stream<WorkspaceTreeChange> call() => _source.changes;
}
