/// Persistence abstraction for the last open workspace identifier.
abstract interface class WorkspaceSelectionStore {
  /// Loads the persisted workspace ID, or null when unset or unreadable.
  Future<String?> load();

  /// Persists [workspaceId], or clears the selection when null.
  Future<void> save(String? workspaceId);
}
