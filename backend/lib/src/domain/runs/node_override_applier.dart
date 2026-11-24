import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Applies per-run node overrides to a workflow definition (ADR 0029).
abstract final class NodeOverrideApplier {
  static final List<(String, String? Function(NodeOverride))> _fields = [
    ('agentId', (o) => o.agentId),
    ('model', (o) => o.model),
    ('effort', (o) => o.effort),
  ];

  /// Returns [workflow] with the non-blank fields of [overrides] (node id ->
  /// override) written into the matching nodes' `config`.
  ///
  /// [overrides] must already be validated with [NodeOverrideValidation].
  /// Returns [workflow] itself when [overrides] is null or empty.
  static Workflow apply(
    Workflow workflow,
    Map<String, NodeOverride>? overrides,
  ) {
    if (overrides == null || overrides.isEmpty) {
      return workflow;
    }

    return workflow.copyWith(
      nodes: [
        for (final node in workflow.nodes)
          if (overrides[node.id] case final override?)
            _applyToNode(node, override)
          else
            node,
      ],
    );
  }

  static WorkflowNode _applyToNode(WorkflowNode node, NodeOverride override) {
    final config = <String, Object?>{...node.config};
    for (final (key, getter) in _fields) {
      final value = getter(override);
      if (value != null && value.trim().isNotEmpty) {
        config[key] = value.trim();
      }
    }
    return node.copyWith(config: config);
  }
}
