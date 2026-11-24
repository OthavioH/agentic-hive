import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/nodes/harness_effort.dart';
import 'package:agentic_hive_shared/src/nodes/node_config_validation.dart';
import 'package:agentic_hive_shared/src/nodes/node_descriptor.dart';
import 'package:agentic_hive_shared/src/workflows/workflow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'node_override.freezed.dart';
part 'node_override.g.dart';

/// Per-node overrides applied to a single run without mutating the workflow.
@freezed
sealed class NodeOverride with _$NodeOverride {
  /// Creates a node override.
  const factory({String? agentId, String? model, String? effort}) =
      _NodeOverride;

  const new _();

  /// Decodes a [NodeOverride] from JSON.
  factory fromJson(JsonMap json) => parseJson(json, _$NodeOverrideFromJson);

  /// Overridable config field names and their getters on [NodeOverride].
  static final List<(String, String? Function(NodeOverride))> fields = [
    ('agentId', (o) => o.agentId),
    ('model', (o) => o.model),
    ('effort', (o) => o.effort),
  ];

  /// Whether no field is set to a non-blank value.
  bool get isEmpty => isBlank(agentId) && isBlank(model) && isBlank(effort);

  /// Validates the values of this override (R6, R7) under [field].
  List<NodeConfigIssue> validate({required String field}) {
    final issues = <NodeConfigIssue>[];
    if (isEmpty) {
      issues.add(
        NodeConfigIssue(
          field: field,
          message: 'Must set at least one of agentId, model or effort.',
        ),
      );
      return issues;
    }
    if (!isBlank(model) && model!.trim().startsWith('-')) {
      issues.add(
        NodeConfigIssue(
          field: '$field.model',
          message: 'Must not start with "-".',
        ),
      );
    }
    if (!isBlank(effort) && !harnessEffortIds.contains(effort!.trim())) {
      issues.add(
        NodeConfigIssue(
          field: '$field.effort',
          message: 'Must be one of: ${harnessEffortIds.join(', ')}.',
        ),
      );
    }
    return issues;
  }
}

/// Validates a map of per-node overrides against a [Workflow].
abstract final class NodeOverrideValidation {
  /// Validates [overrides] (node id -> override) against [workflow] (R6-R10).
  static List<NodeConfigIssue> validate(
    Map<String, NodeOverride> overrides,
    Workflow workflow,
  ) {
    final issues = <NodeConfigIssue>[];
    final nodesById = {for (final n in workflow.nodes) n.id: n};

    for (final entry in overrides.entries) {
      final nodeId = entry.key;
      final override = entry.value;
      final baseField = 'nodeOverrides.$nodeId';

      final node = nodesById[nodeId];
      if (node == null) {
        issues.add(
          NodeConfigIssue(
            field: baseField,
            message: 'Node "$nodeId" does not exist in this workflow.',
          ),
        );
        continue;
      }

      issues.addAll(override.validate(field: baseField));

      final descriptor = NodeDescriptors.of(node.type);
      if (descriptor == null) {
        issues.add(
          NodeConfigIssue(
            field: baseField,
            message: 'Unknown node type "${node.type}".',
          ),
        );
        continue;
      }

      final declared = {for (final f in descriptor.configFields) f.name};
      for (final (name, getter) in NodeOverride.fields) {
        final value = getter(override);
        if (!isBlank(value) && !declared.contains(name)) {
          issues.add(
            NodeConfigIssue(
              field: '$baseField.$name',
              message: '${node.type} does not support overriding $name.',
            ),
          );
        }
      }
    }

    return issues;
  }
}
