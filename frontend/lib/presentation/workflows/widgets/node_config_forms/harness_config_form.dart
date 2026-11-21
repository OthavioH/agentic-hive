import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/node_config_form_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Inspector configuration form for headless harness nodes and
/// `harness.terminal`.
class HarnessConfigForm extends StatefulWidget {
  /// Creates a [HarnessConfigForm].
  ///
  /// When [includeTerminalFields] is true, edits a
  /// [TerminalHarnessNodeConfig] including `command` and `args`.
  const new({
    required this.node,
    required this.onConfigChanged,
    this.includeTerminalFields = false,
    super.key,
  });

  /// Node being edited.
  final WorkflowNode node;

  /// Emits the updated raw `JsonMap` configuration.
  final ValueChanged<JsonMap> onConfigChanged;

  /// Whether to include `command` and `args` for `harness.terminal`.
  final bool includeTerminalFields;

  @override
  State<HarnessConfigForm> createState() => _HarnessConfigFormState();
}

class _HarnessConfigFormState extends State<HarnessConfigForm> {
  final TextEditingController _agentIdController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _workingDirController = TextEditingController();
  final TextEditingController _timeoutController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();

  List<String> _extraArgs = const <String>[];
  List<String> _args = const <String>[];
  String? _syncedNodeId;
  bool _hasTimeoutError = false;

  @override
  void initState() {
    super.initState();
    _syncFromNode();
  }

  @override
  void didUpdateWidget(HarnessConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id ||
        oldWidget.includeTerminalFields != widget.includeTerminalFields) {
      _syncFromNode();
    }
  }

  @override
  void dispose() {
    _agentIdController.dispose();
    _instructionsController.dispose();
    _workingDirController.dispose();
    _timeoutController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  void _syncFromNode() {
    _syncedNodeId = widget.node.id;
    _hasTimeoutError = false;
    if (widget.includeTerminalFields) {
      final config = _parseTerminalConfig(widget.node.config);
      _agentIdController.text = config.agentId ?? '';
      _instructionsController.text = config.additionalInstructions ?? '';
      _workingDirController.text = config.workingDirectory ?? '';
      _timeoutController.text = config.timeoutSeconds?.toString() ?? '';
      _extraArgs = List<String>.of(config.extraArgs);
      _commandController.text = config.command ?? '';
      _args = List<String>.of(config.args);
    } else {
      final config = _parseHarnessConfig(widget.node.config);
      _agentIdController.text = config.agentId ?? '';
      _instructionsController.text = config.additionalInstructions ?? '';
      _workingDirController.text = config.workingDirectory ?? '';
      _timeoutController.text = config.timeoutSeconds?.toString() ?? '';
      _extraArgs = List<String>.of(config.extraArgs);
      _commandController.clear();
      _args = const <String>[];
    }
  }

  HarnessNodeConfig _parseHarnessConfig(JsonMap raw) {
    try {
      return HarnessNodeConfig.fromJson(raw);
    } on FormatException {
      return const HarnessNodeConfig(additionalInstructions: '');
    }
  }

  TerminalHarnessNodeConfig _parseTerminalConfig(JsonMap raw) {
    try {
      return TerminalHarnessNodeConfig.fromJson(raw);
    } on FormatException {
      return const TerminalHarnessNodeConfig(command: '');
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _emit() {
    if (_syncedNodeId != widget.node.id) return;
    final timeout = parsePositiveTimeout(_timeoutController.text);
    if (_hasTimeoutError != !timeout.isValid) {
      setState(() => _hasTimeoutError = !timeout.isValid);
    }
    if (!timeout.isValid) return;

    if (widget.includeTerminalFields) {
      widget.onConfigChanged(
        TerminalHarnessNodeConfig(
          agentId: _nullIfEmpty(_agentIdController.text),
          additionalInstructions: _nullIfEmpty(_instructionsController.text),
          workingDirectory: _nullIfEmpty(_workingDirController.text),
          timeoutSeconds: timeout.value,
          extraArgs: _extraArgs,
          command: _nullIfEmpty(_commandController.text),
          args: _args,
        ).toJson(),
      );
    } else {
      widget.onConfigChanged(
        HarnessNodeConfig(
          agentId: _nullIfEmpty(_agentIdController.text),
          additionalInstructions: _nullIfEmpty(_instructionsController.text),
          workingDirectory: _nullIfEmpty(_workingDirController.text),
          timeoutSeconds: timeout.value,
          extraArgs: _extraArgs,
        ).toJson(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HiveTextField(
          key: const Key('config_harness_agent_id'),
          label: l10n.nodeConfigAgentIdLabel,
          hint: l10n.nodeConfigAgentIdHint,
          helperText: l10n.nodeConfigAgentIdHelper,
          controller: _agentIdController,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_harness_additional_instructions'),
          label: l10n.nodeConfigAdditionalInstructionsLabel,
          hint: l10n.nodeConfigAdditionalInstructionsHint,
          controller: _instructionsController,
          multiline: true,
          maxLines: 4,
          onChanged: (_) => _emit(),
        ),
        if (widget.includeTerminalFields) ...<Widget>[
          SizedBox(height: spacing.space2),
          HiveTextField(
            key: const Key('config_terminal_command'),
            label: l10n.nodeConfigCommandLabel,
            hint: l10n.nodeConfigCommandHint,
            controller: _commandController,
            onChanged: (_) => _emit(),
          ),
          SizedBox(height: spacing.space2),
          HiveStringListField(
            key: const Key('config_terminal_args'),
            label: l10n.nodeConfigArgsLabel,
            itemLabel: l10n.nodeConfigArgsItemLabel,
            addButtonLabel: l10n.nodeConfigArgsAddLabel,
            removeButtonLabel: l10n.nodeConfigRemoveButtonLabel,
            items: _args,
            onChanged: (items) {
              setState(() => _args = items);
              _emit();
            },
          ),
        ],
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_harness_working_directory'),
          label: l10n.nodeConfigWorkingDirectoryLabel,
          hint: l10n.nodeConfigWorkingDirectoryHint,
          controller: _workingDirController,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_harness_timeout_seconds'),
          label: l10n.nodeConfigTimeoutSecondsLabel,
          hint: l10n.nodeConfigTimeoutSecondsHint,
          errorText: _hasTimeoutError
              ? l10n.nodeConfigTimeoutSecondsError
              : null,
          controller: _timeoutController,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveStringListField(
          key: const Key('config_harness_extra_args'),
          label: l10n.nodeConfigExtraArgsLabel,
          itemLabel: l10n.nodeConfigExtraArgsItemLabel,
          addButtonLabel: l10n.nodeConfigExtraArgsAddLabel,
          removeButtonLabel: l10n.nodeConfigRemoveButtonLabel,
          items: _extraArgs,
          onChanged: (items) {
            setState(() => _extraArgs = items);
            _emit();
          },
        ),
      ],
    );
  }
}
