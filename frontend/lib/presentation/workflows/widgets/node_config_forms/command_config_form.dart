import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Inspector configuration form for `command` nodes ([CommandNodeConfig]).
class CommandConfigForm extends StatefulWidget {
  /// Creates a [CommandConfigForm].
  const new({required this.node, required this.onConfigChanged, super.key});

  /// Node being edited.
  final WorkflowNode node;

  /// Emits the updated raw `JsonMap` configuration.
  final ValueChanged<JsonMap> onConfigChanged;

  @override
  State<CommandConfigForm> createState() => _CommandConfigFormState();
}

class _CommandConfigFormState extends State<CommandConfigForm> {
  final TextEditingController _commandController = TextEditingController();
  final TextEditingController _workingDirController = TextEditingController();
  final TextEditingController _timeoutController = TextEditingController();

  List<String> _args = const <String>[];
  List<MapEntry<String, String>> _envEntries =
      const <MapEntry<String, String>>[];

  @override
  void initState() {
    super.initState();
    _syncFromNode();
  }

  @override
  void didUpdateWidget(CommandConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _syncFromNode();
    }
  }

  @override
  void dispose() {
    _commandController.dispose();
    _workingDirController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  void _syncFromNode() {
    final config = _parseConfig(widget.node.config);
    _commandController.text = config.command;
    _workingDirController.text = config.workingDirectory ?? '';
    _timeoutController.text = config.timeoutSeconds?.toString() ?? '';
    _args = List<String>.of(config.args);
    _envEntries = config.env.entries.toList();
  }

  CommandNodeConfig _parseConfig(JsonMap raw) {
    try {
      return CommandNodeConfig.fromJson(raw);
    } on FormatException {
      return const CommandNodeConfig(command: '');
    }
  }

  void _emit() {
    final trimmedDir = _workingDirController.text.trim();
    final trimmedTimeout = _timeoutController.text.trim();
    final envMap = <String, String>{
      for (final entry in _envEntries)
        if (entry.key.isNotEmpty) entry.key: entry.value,
    };

    widget.onConfigChanged(
      CommandNodeConfig(
        command: _commandController.text,
        args: _args,
        workingDirectory: trimmedDir.isEmpty ? null : trimmedDir,
        timeoutSeconds: trimmedTimeout.isEmpty
            ? null
            : int.tryParse(trimmedTimeout),
        env: envMap,
      ).toJson(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HiveTextField(
          key: const Key('config_command_command'),
          label: l10n.nodeConfigCommandLabel,
          hint: l10n.nodeConfigCommandHint,
          controller: _commandController,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveStringListField(
          key: const Key('config_command_args'),
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
        HiveTextField(
          key: const Key('config_command_working_directory'),
          label: l10n.nodeConfigWorkingDirectoryLabel,
          hint: l10n.nodeConfigWorkingDirectoryHint,
          controller: _workingDirController,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_command_timeout_seconds'),
          label: l10n.nodeConfigTimeoutSecondsLabel,
          hint: l10n.nodeConfigTimeoutSecondsHint,
          controller: _timeoutController,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveKeyValueEditor(
          key: const Key('config_command_env'),
          label: l10n.nodeConfigEnvLabel,
          keyLabel: l10n.nodeConfigEnvKeyLabel,
          valueLabel: l10n.nodeConfigEnvValueLabel,
          addButtonLabel: l10n.nodeConfigEnvAddLabel,
          removeButtonLabel: l10n.nodeConfigRemoveButtonLabel,
          duplicateKeyText: l10n.nodeConfigEnvDuplicateKey,
          emptyKeyText: l10n.nodeConfigEnvEmptyKey,
          entries: _envEntries,
          onChanged: (entries) {
            setState(() => _envEntries = entries);
            _emit();
          },
        ),
      ],
    );
  }
}
