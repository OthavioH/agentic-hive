import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/agent_library_select_field.dart';
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
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _workingDirController = TextEditingController();
  final TextEditingController _timeoutController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();

  String? _agentId;
  String? _effort;
  List<String> _extraArgs = const <String>[];
  List<String> _args = const <String>[];
  bool _sendPromptToStdin = false;
  String? _syncedNodeId;
  bool _hasTimeoutError = false;

  /// Config keys the node's descriptor declares (single source, 128-A).
  Set<String> get _supportedFields => <String>{
    for (final f
        in NodeDescriptors.of(widget.node.type)?.configFields ??
            const <NodeConfigField>[])
      f.name,
  };

  String? _rawString(String key) {
    final value = widget.node.config[key];
    return value is String ? value : null;
  }

  @override
  void initState() {
    super.initState();
    _syncFromNode();
  }

  @override
  void didUpdateWidget(HarnessConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id ||
        oldWidget.node.type != widget.node.type ||
        oldWidget.includeTerminalFields != widget.includeTerminalFields) {
      _syncFromNode();
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _workingDirController.dispose();
    _timeoutController.dispose();
    _modelController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  void _syncFromNode() {
    _syncedNodeId = widget.node.id;
    _hasTimeoutError = false;
    if (widget.includeTerminalFields) {
      final config = _parseTerminalConfig(widget.node.config);
      _agentId = _nullIfEmpty(config.agentId ?? '');
      _instructionsController.text = config.additionalInstructions ?? '';
      _workingDirController.text = config.workingDirectory ?? '';
      _timeoutController.text = config.timeoutSeconds?.toString() ?? '';
      _extraArgs = List<String>.of(config.extraArgs);
      _modelController.text = _rawString('model') ?? '';
      _effort = _nullIfEmpty(_rawString('effort') ?? '');
      _commandController.text = config.command ?? '';
      _args = List<String>.of(config.args);
      _sendPromptToStdin = config.sendPromptToStdin;
    } else {
      final config = _parseHarnessConfig(widget.node.config);
      _agentId = _nullIfEmpty(config.agentId ?? '');
      _instructionsController.text = config.additionalInstructions ?? '';
      _workingDirController.text = config.workingDirectory ?? '';
      _timeoutController.text = config.timeoutSeconds?.toString() ?? '';
      _extraArgs = List<String>.of(config.extraArgs);
      _modelController.text = config.model ?? '';
      _effort = _nullIfEmpty(config.effort ?? '');
      _commandController.clear();
      _args = const <String>[];
      _sendPromptToStdin = false;
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
      final model = _nullIfEmpty(_modelController.text);
      final json = <String, dynamic>{
        ...TerminalHarnessNodeConfig(
          agentId: _agentId,
          additionalInstructions: _nullIfEmpty(_instructionsController.text),
          workingDirectory: _nullIfEmpty(_workingDirController.text),
          timeoutSeconds: timeout.value,
          extraArgs: _extraArgs,
          command: _nullIfEmpty(_commandController.text),
          args: _args,
          sendPromptToStdin: _sendPromptToStdin,
        ).toJson(),
        'model': ?model,
        'effort': ?_effort,
      };
      widget.onConfigChanged(json);
    } else {
      widget.onConfigChanged(
        HarnessNodeConfig(
          agentId: _agentId,
          additionalInstructions: _nullIfEmpty(_instructionsController.text),
          workingDirectory: _nullIfEmpty(_workingDirController.text),
          timeoutSeconds: timeout.value,
          model: _nullIfEmpty(_modelController.text),
          effort: _effort,
          extraArgs: _extraArgs,
        ).toJson(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final supported = _supportedFields;
    final harnessName = resolveNodeTypeLabel(context, l10n, widget.node.type);
    final modelSupported = supported.contains('model');
    final effortSupported = supported.contains('effort');
    final showModel = modelSupported || _modelController.text.trim().isNotEmpty;
    final showEffort = effortSupported || _effort != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AgentLibrarySelectField(
          selectKey: const Key('config_harness_agent_id'),
          agentId: _agentId,
          onChanged: (value) {
            setState(() => _agentId = value);
            _emit();
          },
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
          SizedBox(height: spacing.space2),
          HiveSwitch(
            key: const Key('config_terminal_send_prompt_to_stdin'),
            label: l10n.nodeConfigSendPromptToStdinLabel,
            value: _sendPromptToStdin,
            onChanged: (value) {
              setState(() => _sendPromptToStdin = value);
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
        if (showModel) ...<Widget>[
          SizedBox(height: spacing.space2),
          HiveTextField(
            key: const Key('config_harness_model'),
            label: l10n.nodeConfigModelLabel,
            hint: l10n.nodeConfigHarnessDefaultHint,
            errorText: modelSupported
                ? null
                : l10n.nodeConfigModelUnsupportedError(harnessName),
            controller: _modelController,
            onChanged: (_) {
              setState(() {});
              _emit();
            },
          ),
        ],
        if (showEffort) ...<Widget>[
          SizedBox(height: spacing.space2),
          _buildEffortSelect(
            l10n,
            harnessName,
            effortSupported: effortSupported,
          ),
        ],
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

  Widget _buildEffortSelect(
    AppLocalizations l10n,
    String harnessName, {
    required bool effortSupported,
  }) {
    final current = _effort;
    final known = HarnessEffort.tryParse(current) != null;
    String? error;
    if (!effortSupported) {
      error = l10n.nodeConfigEffortUnsupportedError(harnessName);
    } else if (current != null && !known) {
      error = l10n.nodeConfigEffortInvalidError(current);
    }
    return HiveSelect<String>(
      key: const Key('config_harness_effort'),
      label: l10n.nodeConfigEffortLabel,
      hint: l10n.nodeConfigHarnessDefaultHint,
      errorText: error,
      value: current,
      options: <HiveSelectOption<String>>[
        HiveSelectOption<String>(
          value: '',
          label: l10n.nodeConfigHarnessDefaultHint,
        ),
        if (current != null && !known)
          HiveSelectOption<String>(value: current, label: current),
        for (final level in HarnessEffort.values)
          HiveSelectOption<String>(
            value: level.name,
            label: _effortLabel(l10n, level),
          ),
      ],
      onChanged: (picked) {
        setState(() => _effort = picked.isEmpty ? null : picked);
        _emit();
      },
    );
  }

  String _effortLabel(AppLocalizations l10n, HarnessEffort level) =>
      switch (level) {
        HarnessEffort.low => l10n.nodeConfigEffortLow,
        HarnessEffort.medium => l10n.nodeConfigEffortMedium,
        HarnessEffort.high => l10n.nodeConfigEffortHigh,
        HarnessEffort.max => l10n.nodeConfigEffortMax,
      };
}
