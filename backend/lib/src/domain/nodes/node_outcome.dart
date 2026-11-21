/// Result of executing a workflow node.
final class NodeOutcome {
  /// Creates a node outcome.
  const new({
    required this.outputLabel,
    this.data = const <String, Object?>{},
    this.artifacts = const <String>[],
  });

  /// Edge output label emitted by this node (`onSuccess`, `onFailure`,
  /// `approved`, `rejected`, `changesRequested`, etc.).
  final String outputLabel;

  /// Structured output payload produced by the node.
  final Map<String, Object?> data;

  /// Paths or references to artifacts produced by the node.
  final List<String> artifacts;
}
