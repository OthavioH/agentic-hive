import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';

/// Loads the last open workspace identifier persisted across restarts.
final class LoadLastWorkspaceId {
  /// Creates a [LoadLastWorkspaceId] use case.
  const new(this._store);

  final WorkspaceSelectionStore _store;

  /// Returns the saved workspace ID, or null if none is stored.
  Future<String?> call() => _store.load();
}
