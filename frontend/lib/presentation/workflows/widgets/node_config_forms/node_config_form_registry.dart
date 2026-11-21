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
    ValueChanged<JsonMap> onConfigChanged,
  ) {
    final builder = _builders[node.type];
    return builder?.call(context, node, onConfigChanged);
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
      (context, node, onConfigChanged) => HarnessConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        includeTerminalFields: true,
        onConfigChanged: onConfigChanged,
      ),
    )
    ..register(
      NodeTypeId.command,
      (context, node, onConfigChanged) => CommandConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        onConfigChanged: onConfigChanged,
      ),
    )
    ..register(
      NodeTypeId.testsValidator,
      (context, node, onConfigChanged) => TestsValidatorConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        onConfigChanged: onConfigChanged,
      ),
    )
    ..register(
      NodeTypeId.checklistValidator,
      (context, node, onConfigChanged) => ChecklistValidatorConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        onConfigChanged: onConfigChanged,
      ),
    )
    ..register(
      NodeTypeId.reviewValidator,
      (context, node, onConfigChanged) => ReviewValidatorConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        onConfigChanged: onConfigChanged,
      ),
    )
    ..register(
      NodeTypeId.humanApproval,
      (context, node, onConfigChanged) => HumanApprovalConfigForm(
        key: ValueKey<String>(node.id),
        node: node,
        onConfigChanged: onConfigChanged,
      ),
    );

  return registry;
}
