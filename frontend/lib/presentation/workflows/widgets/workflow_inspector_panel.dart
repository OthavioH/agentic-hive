import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_editor_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Right-hand contextual inspector panel for workflow metadata, selected node
/// or edge properties, and clickable validation diagnostics.
class WorkflowInspectorPanel extends StatefulWidget {
  /// Creates a [WorkflowInspectorPanel].
  const new({
    required this.state,
    required this.onUpdateMetadata,
    required this.onUpdateNodeLabel,
    required this.onToggleEntryNode,
    required this.onDeleteNode,
    required this.onUpdateEdge,
    required this.onDeleteEdge,
    required this.onFocusIssue,
    super.key,
  });

  /// Current editor state.
  final WorkflowEditorState state;

  /// Called when workflow name or description changes.
  final void Function({String? name, String? description}) onUpdateMetadata;

  /// Called when the selected node's label changes.
  final void Function(String nodeId, String label) onUpdateNodeLabel;

  /// Called when the selected node's entry-node switch changes.
  final void Function(String nodeId, {required bool isEntry}) onToggleEntryNode;

  /// Called to delete the selected node.
  final ValueChanged<String> onDeleteNode;

  /// Called when the selected edge's `sourceOutput` or `maxRetries` changes.
  final void Function(
    String edgeId, {
    String? sourceOutput,
    int? maxRetries,
    bool clearMaxRetries,
  })
  onUpdateEdge;

  /// Called to delete the selected edge.
  final ValueChanged<String> onDeleteEdge;

  /// Called when the user clicks a validation issue to focus it on the canvas.
  final ValueChanged<WorkflowValidationIssue> onFocusIssue;

  @override
  State<WorkflowInspectorPanel> createState() => _WorkflowInspectorPanelState();
}

class _WorkflowInspectorPanelState extends State<WorkflowInspectorPanel> {
  static const String _customOutputKey = '__custom__';
  static const List<String> _presetOutputs = <String>['onSuccess', 'onFailure'];

  final TextEditingController _workflowNameController = TextEditingController();
  final TextEditingController _workflowDescController = TextEditingController();
  final TextEditingController _nodeLabelController = TextEditingController();
  final TextEditingController _nodeTypeController = TextEditingController();
  final TextEditingController _edgeOutputController = TextEditingController();
  final TextEditingController _edgeRetriesController = TextEditingController();

  String? _syncedWorkflowId;
  String? _syncedNodeId;
  String? _syncedEdgeId;
  bool _useCustomOutput = false;

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(WorkflowInspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  @override
  void dispose() {
    _workflowNameController.dispose();
    _workflowDescController.dispose();
    _nodeLabelController.dispose();
    _nodeTypeController.dispose();
    _edgeOutputController.dispose();
    _edgeRetriesController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final workflow = widget.state.workflow;
    if (_syncedWorkflowId != workflow.id) {
      _syncedWorkflowId = workflow.id;
      _workflowNameController.text = workflow.name;
      _workflowDescController.text = workflow.description ?? '';
    }

    final node = widget.state.selectedNode;
    if (node != null && _syncedNodeId != node.id) {
      _syncedNodeId = node.id;
      _nodeLabelController.text = node.label;
      _nodeTypeController.text = node.type;
    } else if (node == null) {
      _syncedNodeId = null;
    }

    final edge = widget.state.selectedEdge;
    if (edge != null && _syncedEdgeId != edge.id) {
      _syncedEdgeId = edge.id;
      _useCustomOutput = !_presetOutputs.contains(edge.sourceOutput);
      _edgeOutputController.text = edge.sourceOutput;
      _edgeRetriesController.text = edge.maxRetries?.toString() ?? '';
    } else if (edge == null) {
      _syncedEdgeId = null;
      _useCustomOutput = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final elevation = context.hiveElevation;

    final selectedNode = widget.state.selectedNode;
    final selectedEdge = widget.state.selectedEdge;

    return Container(
      width: spacing.space8 * 5,
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: context.hiveRadii.panel,
        border: Border.all(
          color: colors.borderSubtle,
          width: elevation.hairline,
        ),
      ),
      padding: EdgeInsets.all(spacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (selectedNode != null)
                    _buildNodeInspector(context, l10n, selectedNode)
                  else if (selectedEdge != null)
                    _buildEdgeInspector(context, l10n, selectedEdge)
                  else
                    _buildWorkflowInspector(context, l10n),
                  SizedBox(height: spacing.space3),
                  Divider(
                    color: colors.borderSubtle,
                    height: elevation.hairline,
                  ),
                  SizedBox(height: spacing.space3),
                  _buildValidationSection(context, l10n, typography, colors),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowInspector(BuildContext context, AppLocalizations l10n) {
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final colors = context.hiveColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.editorInspectorWorkflowTitle,
            style: typography.titleSmall.copyWith(color: colors.onSurface),
          ),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('inspector_workflow_name'),
          label: l10n.workflowsNameLabel,
          hint: l10n.workflowsNameHint,
          controller: _workflowNameController,
          onChanged: (value) => widget.onUpdateMetadata(name: value),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('inspector_workflow_description'),
          label: l10n.workflowsDescriptionLabel,
          hint: l10n.workflowsDescriptionHint,
          controller: _workflowDescController,
          multiline: true,
          maxLines: 5,
          onChanged: (value) => widget.onUpdateMetadata(description: value),
        ),
      ],
    );
  }

  Widget _buildNodeInspector(
    BuildContext context,
    AppLocalizations l10n,
    WorkflowNode node,
  ) {
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final colors = context.hiveColors;
    final isEntry = widget.state.workflow.entryNodeId == node.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.editorInspectorNodeTitle,
            style: typography.titleSmall.copyWith(color: colors.onSurface),
          ),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('inspector_node_label'),
          label: l10n.editorNodeLabelField,
          controller: _nodeLabelController,
          onChanged: (value) => widget.onUpdateNodeLabel(node.id, value),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('inspector_node_type'),
          label: l10n.editorNodeTypeField,
          controller: _nodeTypeController,
          readOnly: true,
        ),
        SizedBox(height: spacing.space2),
        HiveSwitch(
          key: const Key('inspector_node_entry_switch'),
          label: l10n.editorNodeEntryLabel,
          value: isEntry,
          onChanged: (value) =>
              widget.onToggleEntryNode(node.id, isEntry: value),
        ),
        SizedBox(height: spacing.space3),
        HiveButton(
          key: const Key('inspector_delete_node'),
          label: l10n.editorDeleteNodeAction,
          icon: HiveIcons.delete,
          variant: HiveButtonVariant.danger,
          onPressed: () => widget.onDeleteNode(node.id),
        ),
      ],
    );
  }

  Widget _buildEdgeInspector(
    BuildContext context,
    AppLocalizations l10n,
    WorkflowEdge edge,
  ) {
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final colors = context.hiveColors;

    final selectedOption = _useCustomOutput
        ? _customOutputKey
        : (_presetOutputs.contains(edge.sourceOutput)
              ? edge.sourceOutput
              : _customOutputKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.editorInspectorEdgeTitle,
            style: typography.titleSmall.copyWith(color: colors.onSurface),
          ),
        ),
        SizedBox(height: spacing.space2),
        HiveSelect<String>(
          key: const Key('inspector_edge_source_output_select'),
          label: l10n.editorEdgeSourceOutputLabel,
          value: selectedOption,
          options: <HiveSelectOption<String>>[
            for (final preset in _presetOutputs)
              HiveSelectOption<String>(value: preset, label: preset),
            HiveSelectOption<String>(
              value: _customOutputKey,
              label: l10n.editorEdgeSourceOutputCustomOption,
            ),
          ],
          onChanged: (value) {
            if (value == _customOutputKey) {
              setState(() => _useCustomOutput = true);
            } else {
              setState(() => _useCustomOutput = false);
              _edgeOutputController.text = value;
              widget.onUpdateEdge(edge.id, sourceOutput: value);
            }
          },
        ),
        if (selectedOption == _customOutputKey) ...<Widget>[
          SizedBox(height: spacing.space2),
          HiveTextField(
            key: const Key('inspector_edge_source_output_custom'),
            label: l10n.editorEdgeSourceOutputCustomLabel,
            hint: l10n.editorEdgeSourceOutputCustomHint,
            controller: _edgeOutputController,
            onChanged: (value) =>
                widget.onUpdateEdge(edge.id, sourceOutput: value),
          ),
        ],
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('inspector_edge_max_retries'),
          label: l10n.editorEdgeMaxRetriesLabel,
          hint: l10n.editorEdgeMaxRetriesHint,
          helperText: l10n.editorEdgeMaxRetriesHelper,
          controller: _edgeRetriesController,
          onChanged: (value) {
            final trimmed = value.trim();
            if (trimmed.isEmpty) {
              widget.onUpdateEdge(edge.id, clearMaxRetries: true);
              return;
            }
            final parsed = int.tryParse(trimmed);
            if (parsed != null) {
              widget.onUpdateEdge(edge.id, maxRetries: parsed);
            }
          },
        ),
        SizedBox(height: spacing.space3),
        HiveButton(
          key: const Key('inspector_delete_edge'),
          label: l10n.editorDeleteEdgeAction,
          icon: HiveIcons.delete,
          variant: HiveButtonVariant.danger,
          onPressed: () => widget.onDeleteEdge(edge.id),
        ),
      ],
    );
  }

  Widget _buildValidationSection(
    BuildContext context,
    AppLocalizations l10n,
    HiveTypography typography,
    HiveColors colors,
  ) {
    final spacing = context.hiveSpacing;
    final issues = widget.state.validation.issues;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.editorValidationSectionTitle,
            style: typography.titleSmall.copyWith(color: colors.onSurface),
          ),
        ),
        SizedBox(height: spacing.space2),
        if (issues.isEmpty)
          Text(
            l10n.editorNoValidationIssues,
            style: typography.bodySmall.copyWith(color: colors.onSurfaceMuted),
          )
        else
          for (var i = 0; i < issues.length; i++) ...<Widget>[
            _ValidationIssueTile(
              issue: issues[i],
              onTap: () => widget.onFocusIssue(issues[i]),
            ),
            if (i < issues.length - 1) SizedBox(height: spacing.space1),
          ],
      ],
    );
  }
}

class _ValidationIssueTile extends StatelessWidget {
  const new({required this.issue, required this.onTap});

  final WorkflowValidationIssue issue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isError = issue.severity == WorkflowValidationSeverity.error;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;

    return HiveCard(
      surface: HiveCardSurface.surface2,
      semanticLabel: issue.message,
      onPressed: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          HiveBadge(
            label: isError
                ? l10n.editorIssueErrorLabel
                : l10n.editorIssueWarningLabel,
            tone: isError ? HiveBadgeTone.danger : HiveBadgeTone.warning,
            icon: HiveIcons.alert,
          ),
          SizedBox(width: spacing.space1),
          Expanded(
            child: Text(
              issue.message,
              style: typography.bodySmall.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
