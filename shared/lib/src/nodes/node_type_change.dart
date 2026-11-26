import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/nodes/node_config_field.dart';
import 'package:agentic_hive_shared/src/nodes/node_configs.dart';
import 'package:agentic_hive_shared/src/nodes/node_descriptor.dart';

/// The in-place node type change rule (spec #172): headless harness into a
/// different headless harness only.
abstract final class NodeTypeChange {
  /// Config keys [typeId] supports, from its descriptor; empty when unknown.
  static Set<String> supportedFields(String typeId) => {
    for (final f
        in NodeDescriptors.of(typeId)?.configFields ??
            const <NodeConfigField>[])
      f.name,
  };

  /// Whether a node of type [from] may become [to].
  static bool isAllowed(String from, String to) =>
      from != to &&
      headlessHarnessTypeIds.contains(from) &&
      headlessHarnessTypeIds.contains(to);

  /// Keys of [config] that [toType] does not support, sorted.
  static List<String> droppedFields(JsonMap config, String toType) {
    final supported = supportedFields(toType);
    return [
      for (final k in config.keys)
        if (!supported.contains(k)) k,
    ]..sort();
  }
}
