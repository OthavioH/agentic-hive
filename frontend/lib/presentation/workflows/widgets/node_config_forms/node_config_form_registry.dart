import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/checklist_validator_config_form.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/command_config_form.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/harness_config_form.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/human_approval_config_form.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/review_validator_config_form.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/tests_validator_config_form.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:material_ui/material_ui.dart';

/// Builder callback producing the configuration form widget for [node].
typedef NodeConfigFormBuilder = Widget Function(
  BuildContext context,
  WorkflowNode node,
  ValueChanged<JsonMap> onConfigChanged,
  List<WorkflowNode> workflowNodes,
);

/// Registry mapping canonical `WorkflowNode.type` identifiers to their typed
/// inspector configuration form builders.
class NodeConfigFormRegistry {
  /// Creates an empty [NodeConfigFormRegistry].
  new();

  final Map<String, NodeConfigFormBuilder> _builders =
      <String, NodeConfigFormBuilder>{};

  /// Registers [builder] for [typeId].
  ///
  /// Throws a [StateError] if [typeId] is already registered.
  void register(String typeId, NodeConfigFormBuilder builder) {
    if (_builders.containsKey(typeId)) {
      throw StateError('Node type "$typeId" already has a config form.');
    }
    _builders[typeId] = builder;
  }

  /// Whether [typeId] has a registered form builder.
  bool contains(String typeId) => _builders.containsKey(typeId);

  /// Builds the configuration form for [node], or returns `null` when
  /// [node]'s type is unregistered.
  Widget? buildForm(
    BuildContext context,
    WorkflowNode node,
    ValueChanged<JsonMap> onConfigChanged, {
    List<WorkflowNode> workflowNodes = const <WorkflowNode>[],
  }) {
    final builder = _builders[node.type];
    return builder?.call(context, node, onConfigChanged, workflowNodes);
  }
}

/// Creates a [NodeConfigFormRegistry] with all 10 canonical node types
/// registered.
NodeConfigFormRegistry createNodeConfigFormRegistry() {
  final registry = NodeConfigFormRegistry();

  Widget buildHeadlessHarness(
    BuildContext context,
    WorkflowNode node,
    ValueChanged<JsonMap> onConfigChanged,
    List<WorkflowNode> workflowNodes,
  ) {
    return HarnessConfigForm(
      key: ValueKey<String>(node.id),
      node: node,
      onConfigChanged: onConfigChanged,
    );
  }

  registry
    ..register(NodeTypeId.claudeCode, buildHeadlessHarness)
    ..register(NodeTypeId.codex, buildHeadlessHarness)
    ..register(NodeTypeId.geminiCli, buildHeadlessHarness)
    ..register(NodeTypeId.antigravity, buildHeadlessHarness)
    ..register(
      NodeTypeId.terminal,
      (context, node, onConfigChanged, _) => HarnessConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        includeTerminalFields: true,
        onConfigChanged: onConfigChanged,
      ),
    )
    ..register(
      NodeTypeId.command,
      (context, node, onConfigChanged, _) => CommandConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        onConfigChanged: onConfigChanged,
      ),
    )
    ..register(
      NodeTypeId.testsValidator,
      (context, node, onConfigChanged, _) => TestsValidatorConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        onConfigChanged: onConfigChanged,
      ),
    )
    ..register(
      NodeTypeId.checklistValidator,
      (context, node, onConfigChanged, _) => ChecklistValidatorConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        onConfigChanged: onConfigChanged,
      ),
    )
    ..register(
      NodeTypeId.reviewValidator,
      (context, node, onConfigChanged, _) => ReviewValidatorConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        onConfigChanged: onConfigChanged,
      ),
    )
    ..register(
      NodeTypeId.humanApproval,
      (context, node, onConfigChanged, workflowNodes) =>
          HumanApprovalConfigForm(
            key: ValueKey<String>(node.id),
            node: node,
            onConfigChanged: onConfigChanged,
            upstreamNodes: workflowNodes,
          ),
    );

  return registry;
}

/// Parses an optional positive integer timeout from [raw].
///
/// Empty/whitespace input returns `(value: null, isValid: true)`. Any non-empty
/// input that is not a strictly positive integer returns
/// `(value: null, isValid: false)`.
({int? value, bool isValid}) parsePositiveTimeout(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return (value: null, isValid: true);
  final parsed = int.tryParse(trimmed);
  if (parsed == null || parsed <= 0) return (value: null, isValid: false);
  return (value: parsed, isValid: true);
}
