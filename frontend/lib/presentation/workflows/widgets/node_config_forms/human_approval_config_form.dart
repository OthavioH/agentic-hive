import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Inspector configuration form for `human_approval`
/// ([HumanApprovalNodeConfig]).
class HumanApprovalConfigForm extends StatefulWidget {
  /// Creates a [HumanApprovalConfigForm].
  const new({required this.node, required this.onConfigChanged, super.key});

  /// Node being edited.
  final WorkflowNode node;

  /// Emits the updated raw `JsonMap` configuration.
  final ValueChanged<JsonMap> onConfigChanged;

  @override
  State<HumanApprovalConfigForm> createState() =>
      _HumanApprovalConfigFormState();
}

class _HumanApprovalConfigFormState extends State<HumanApprovalConfigForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  bool _allowFeedback = true;

  @override
  void initState() {
    super.initState();
    _syncFromNode();
  }

  @override
  void didUpdateWidget(HumanApprovalConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _syncFromNode();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _syncFromNode() {
    final config = _parseConfig(widget.node.config);
    _titleController.text = config.title ?? '';
    _instructionsController.text = config.instructions;
    _allowFeedback = config.allowFeedback;
  }

  HumanApprovalNodeConfig _parseConfig(JsonMap raw) {
    try {
      return HumanApprovalNodeConfig.fromJson(raw);
    } on FormatException {
      return const HumanApprovalNodeConfig(instructions: '');
    }
  }

  void _emit() {
    final trimmedTitle = _titleController.text.trim();
    widget.onConfigChanged(
      HumanApprovalNodeConfig(
        title: trimmedTitle.isEmpty ? null : trimmedTitle,
        instructions: _instructionsController.text,
        allowFeedback: _allowFeedback,
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
          key: const Key('config_human_title'),
          label: l10n.nodeConfigHumanTitleLabel,
          hint: l10n.nodeConfigHumanTitleHint,
          controller: _titleController,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveTextField(
          key: const Key('config_human_instructions'),
          label: l10n.nodeConfigHumanInstructionsLabel,
          hint: l10n.nodeConfigHumanInstructionsHint,
          controller: _instructionsController,
          multiline: true,
          maxLines: 4,
          onChanged: (_) => _emit(),
        ),
        SizedBox(height: spacing.space2),
        HiveSwitch(
          key: const Key('config_human_allow_feedback'),
          label: l10n.nodeConfigHumanAllowFeedbackLabel,
          value: _allowFeedback,
          onChanged: (value) {
            setState(() => _allowFeedback = value);
            _emit();
          },
        ),
      ],
    );
  }
}
