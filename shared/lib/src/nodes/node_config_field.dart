/// Value shape of one node config field.
enum NodeConfigFieldKind {
  /// A string.
  string,

  /// An integer.
  integer,

  /// A boolean.
  boolean,

  /// A list of strings.
  stringList,

  /// A string-to-string map.
  stringMap,

  /// A list of objects described by [NodeConfigField.itemFields].
  objectList,
}

/// Describes one key of a `WorkflowNode.config` map.
final class NodeConfigField {
  /// Creates a config field description.
  const new({
    required this.name,
    this.kind = NodeConfigFieldKind.string,
    this.required = false,
    this.values = const <String>{},
    this.itemFields = const <NodeConfigField>[],
  });

  /// JSON key in the config map.
  final String name;

  /// Value shape.
  final NodeConfigFieldKind kind;

  /// Whether the key must be present.
  final bool required;

  /// Closed set of accepted values; empty when the values are open.
  final Set<String> values;

  /// Fields of each object when [kind] is [NodeConfigFieldKind.objectList].
  final List<NodeConfigField> itemFields;
}
