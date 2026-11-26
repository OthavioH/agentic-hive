import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Pure helpers for resolving a node's fallback entries and effective config.
abstract final class FallbackConfig {
  /// Returns the configured fallback entries for [node], or an empty list if
  /// [node] is not a headless harness or its config cannot be parsed.
  static List<FallbackEntry> entriesOf(WorkflowNode node) {
    if (!headlessHarnessTypeIds.contains(node.type)) {
      return const <FallbackEntry>[];
    }
    try {
      return HarnessNodeConfig.fromJson(node.config).fallback;
    } on FormatException {
      return const <FallbackEntry>[];
    }
  }

  /// Resolves the effective `(type, config)` for [node] at fallback [index].
  ///
  /// When [index] is `null` or out of range, returns `(node.type, node.config)`
  /// unchanged.
  static (String type, JsonMap config) effective(
    WorkflowNode node,
    int? index,
  ) {
    if (index == null || index < 0) {
      return (node.type, node.config);
    }
    final entries = entriesOf(node);
    if (index >= entries.length) {
      return (node.type, node.config);
    }

    final entry = entries[index];
    final config = JsonMap.of(node.config)
      ..remove('model')
      ..remove('effort');
    if (entry.harness != node.type) {
      config.remove('extraArgs');
    }
    final model = entry.model?.trim();
    if (model != null && model.isNotEmpty) {
      config['model'] = model;
    }
    final effort = entry.effort?.trim();
    if (effort != null && effort.isNotEmpty) {
      config['effort'] = effort;
    }
    return (entry.harness, config);
  }
}
