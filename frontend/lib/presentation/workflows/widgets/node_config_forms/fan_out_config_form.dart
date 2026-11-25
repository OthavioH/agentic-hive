import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/fan_out_workflow_select_field.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Inspector configuration form for `fan_out` ([FanOutNodeConfig]).
class FanOutConfigForm extends StatefulWidget {
  /// Creates a [FanOutConfigForm].
  const new({
    required this.node,
    required this.onConfigChanged,
    this.upstreamNodes = const <WorkflowNode>[],
    super.key,
  });

  /// Node being edited.
  final WorkflowNode node;

  /// Emits the updated raw `JsonMap` configuration.
  final ValueChanged<JsonMap> onConfigChanged;

  /// Other nodes in the workflow that can supply the items list.
  final List<WorkflowNode> upstreamNodes;

  @override
  State<FanOutConfigForm> createState() => _FanOutConfigFormState();
}

class _FanOutConfigFormState extends State<FanOutConfigForm> {
  final TextEditingController _itemsPathController = TextEditingController();
  final TextEditingController _inputFieldController = TextEditingController();
  final TextEditingController _overridesFieldController =
      TextEditingController();
  final TextEditingController _nameFieldController = TextEditingController();
  final TextEditingController _concurrencyController = TextEditingController();
  final TextEditingController _maxItemsController = TextEditingController();

  String _workflowId = '';
  String _itemsNodeId = '';
  bool _concurrencyInvalid = false;
  bool _maxItemsInvalid = false;

  @override
  void initState() {
    super.initState();
    _syncFromNode();
  }

  @override
  void didUpdateWidget(FanOutConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _syncFromNode();
    }
  }

  @override
  void dispose() {
    _itemsPathController.dispose();
    _inputFieldController.dispose();
    _overridesFieldController.dispose();
    _nameFieldController.dispose();
    _concurrencyController.dispose();
    _maxItemsController.dispose();
    super.dispose();
  }

  void _syncFromNode() {
    final config = _parseConfig(widget.node.config);
    _workflowId = config.workflowId;
    _itemsNodeId = config.itemsNodeId;
    _itemsPathController.text = config.itemsPath;
    _inputFieldController.text = config.inputField ?? '';
    _overridesFieldController.text = config.overridesField ?? '';
    _nameFieldController.text = config.nameField ?? '';
    _concurrencyController.text = '${config.concurrency}';
    _maxItemsController.text = '${config.maxItems}';
    _concurrencyInvalid = false;
    _maxItemsInvalid = false;
  }

  FanOutNodeConfig _parseConfig(JsonMap raw) {
    try {
      return FanOutNodeConfig.fromJson(raw);
    } on FormatException {
      return const FanOutNodeConfig(
        workflowId: '',
        itemsNodeId: '',
        itemsPath: '',
      );
    }
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _parsePositive(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < 1) return null;
    return parsed;
  }

  FanOutNodeConfig _currentConfig({
    int concurrency = fanOutDefaultConcurrency,
    int maxItems = fanOutDefaultMaxItems,
  }) {
    return FanOutNodeConfig(
      workflowId: _workflowId,
      itemsNodeId: _itemsNodeId,
      itemsPath: _itemsPathController.text.trim(),
      inputField: _nullIfBlank(_inputFieldController.text),
      overridesField: _nullIfBlank(_overridesFieldController.text),
      nameField: _nullIfBlank(_nameFieldController.text),
      concurrency: concurrency,
      maxItems: maxItems,
    );
  }

  void _emit() {
    final concurrency = _parsePositive(_concurrencyController.text);
    final maxItems = _parsePositive(_maxItemsController.text);
    final concurrencyInvalid = concurrency == null;
    final maxItemsInvalid = maxItems == null;
    setState(() {
      _concurrencyInvalid = concurrencyInvalid;
      _maxItemsInvalid = maxItemsInvalid;
    });
    if (concurrencyInvalid || maxItemsInvalid) return;
    widget.onConfigChanged(
      _currentConfig(concurrency: concurrency, maxItems: maxItems).toJson(),
    );
  }

  String? _issueFor(List<NodeConfigIssue> issues, String field) {
    final messages = issues
        .where((issue) => issue.field == field)
        .map((issue) => issue.message)
        .toList(growable: false);
    return messages.isEmpty ? null : messages.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final issues = _currentConfig(
      concurrency:
          _parsePositive(_concurrencyController.text) ??
          fanOutDefaultConcurrency,
      maxItems:
          _parsePositive(_maxItemsController.text) ?? fanOutDefaultMaxItems,
    ).validate();

    final upstream = widget.upstreamNodes
        .where((n) => n.id != widget.node.id)
        .toList(growable: false);
    final currentItemsNode = _itemsNodeId.trim().isEmpty ? null : _itemsNodeId;
    final hasDanglingItemsNode =
        currentItemsNode != null &&
        !upstream.any((n) => n.id == currentItemsNode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FanOutWorkflowSelectField(
          selectKey: const Key('config_fan_out_workflow'),
          workflowId: _workflowId,
          errorText: _issueFor(issues, 'workflowId'),
          onChanged: (picked) {
            setState(() => _workflowId = picked);
            _emit();
          },
        ),
        SizedBox(height: spacing.space2),
        HiveSelect<String>(
          key: const Key('config_fan_out_items_node'),
          label: l10n.nodeConfigFanOutItemsNodeLabel,
          hint: l10n.nodeConfigFanOutItemsNodeHint,
          value: currentItemsNode,
          errorText: _issueFor(issues, 'itemsNodeId'),
          options: <HiveSelectOption<String>>[
            if (hasDanglingItemsNode)
              HiveSelectOption<String>(
                value: currentItemsNode,
                label: currentItemsNode,
              ),
            for (final node in upstream)
              HiveSelectOption<String>(
                value: node.id,
                label: node.label.isEmpty ? node.id : node.label,
              ),
          ],
          onChanged: (picked) {
            setState(() => _itemsNodeId = picked);
            _emit();
          },
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_fan_out_items_path'),
          label: l10n.nodeConfigFanOutItemsPathLabel,
          hint: l10n.nodeConfigFanOutItemsPathHint,
          controller: _itemsPathController,
          errorText: _issueFor(issues, 'itemsPath'),
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_fan_out_input_field'),
          label: l10n.nodeConfigFanOutInputFieldLabel,
          hint: l10n.nodeConfigFanOutInputFieldHint,
          controller: _inputFieldController,
          errorText: _issueFor(issues, 'inputField'),
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_fan_out_overrides_field'),
          label: l10n.nodeConfigFanOutOverridesFieldLabel,
          hint: l10n.nodeConfigFanOutOverridesFieldHint,
          controller: _overridesFieldController,
          errorText: _issueFor(issues, 'overridesField'),
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_fan_out_name_field'),
          label: l10n.nodeConfigFanOutNameFieldLabel,
          hint: l10n.nodeConfigFanOutNameFieldHint,
          controller: _nameFieldController,
          errorText: _issueFor(issues, 'nameField'),
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_fan_out_concurrency'),
          label: l10n.nodeConfigFanOutConcurrencyLabel,
          controller: _concurrencyController,
          errorText: _concurrencyInvalid
              ? l10n.nodeConfigFanOutPositiveIntError
              : null,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_fan_out_max_items'),
          label: l10n.nodeConfigFanOutMaxItemsLabel,
          controller: _maxItemsController,
          errorText: _maxItemsInvalid
              ? l10n.nodeConfigFanOutPositiveIntError
              : null,
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}
