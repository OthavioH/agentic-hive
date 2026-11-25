/// Rules for node ids chosen by MCP clients.
abstract final class WorkflowNodeIds {
  /// Pattern for 1-32 lowercase letters, digits or underscores.
  static final RegExp pattern = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

  /// Whether [id] is a valid client-chosen node id.
  static bool isValid(String id) => pattern.hasMatch(id);
}
