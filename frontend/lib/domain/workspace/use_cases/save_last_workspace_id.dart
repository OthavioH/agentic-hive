import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';

/// Persists the current workspace identifier across restarts.
final class SaveLastWorkspaceId {
  /// Creates a [SaveLastWorkspaceId] use case.
  const new(this._store);

  final WorkspaceSelectionStore _store;

  /// Saves [workspaceId], or clears the stored selection when null.
  Future<void> call(String? workspaceId) => _store.save(workspaceId);
}
