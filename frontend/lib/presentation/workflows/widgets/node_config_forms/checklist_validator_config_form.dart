import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Inspector configuration form for `validator.checklist`
/// ([ChecklistValidatorNodeConfig]).
class ChecklistValidatorConfigForm extends StatefulWidget {
  /// Creates a [ChecklistValidatorConfigForm].
  const new({required this.node, required this.onConfigChanged, super.key});

  /// Node being edited.
  final WorkflowNode node;

  /// Emits the updated raw `JsonMap` configuration.
  final ValueChanged<JsonMap> onConfigChanged;

  @override
  State<ChecklistValidatorConfigForm> createState() =>
      _ChecklistValidatorConfigFormState();
}

final class _ChecklistRuleControllers {
  new(ChecklistRule rule)
    : label = TextEditingController(text: rule.label),
      path = TextEditingController(text: rule.path ?? ''),
      command = TextEditingController(text: rule.command ?? ''),
      workingDirectory = TextEditingController(
        text: rule.workingDirectory ?? '',
      ),
      pattern = TextEditingController(text: rule.pattern ?? ''),
      kind = rule.kind;

  final LocalKey id = UniqueKey();
  final TextEditingController label;
  final TextEditingController path;
  final TextEditingController command;
  final TextEditingController workingDirectory;
  final TextEditingController pattern;
  ChecklistRuleKind kind;

  ChecklistRule toRule() {
    String? nullIfEmpty(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return ChecklistRule(
      label: label.text,
      kind: kind,
      path: kind == ChecklistRuleKind.fileExists
          ? nullIfEmpty(path.text)
          : null,
      command: kind != ChecklistRuleKind.fileExists
          ? nullIfEmpty(command.text)
          : null,
      workingDirectory: kind != ChecklistRuleKind.fileExists
          ? nullIfEmpty(workingDirectory.text)
          : null,
      pattern: kind == ChecklistRuleKind.outputMatchesRegex
          ? nullIfEmpty(pattern.text)
          : null,
    );
  }

  void dispose() {
    label.dispose();
    path.dispose();
    command.dispose();
    workingDirectory.dispose();
    pattern.dispose();
  }
}

class _ChecklistValidatorConfigFormState
    extends State<ChecklistValidatorConfigForm> {
  final List<_ChecklistRuleControllers> _rows = <_ChecklistRuleControllers>[];

  @override
  void initState() {
    super.initState();
    _syncFromNode();
  }

  @override
  void didUpdateWidget(ChecklistValidatorConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _syncFromNode();
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _syncFromNode() {
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
    final config = _parseConfig(widget.node.config);
    for (final rule in config.rules) {
      _rows.add(_ChecklistRuleControllers(rule));
    }
  }

  ChecklistValidatorNodeConfig _parseConfig(JsonMap raw) {
    try {
      return ChecklistValidatorNodeConfig.fromJson(raw);
    } on FormatException {
      return const ChecklistValidatorNodeConfig(rules: <ChecklistRule>[]);
    }
  }

  void _emit() {
    widget.onConfigChanged(
      ChecklistValidatorNodeConfig(
        rules: <ChecklistRule>[for (final row in _rows) row.toRule()],
      ).toJson(),
    );
  }

  void _addRule() {
    setState(() {
      _rows.add(
        _ChecklistRuleControllers(
          const ChecklistRule(label: '', kind: ChecklistRuleKind.fileExists),
        ),
      );
    });
    _emit();
  }

  void _removeRule(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.nodeConfigChecklistRulesLabel,
          style: typography.labelLarge.copyWith(color: colors.onSurface),
        ),
        SizedBox(height: spacing.space2),
        if (_rows.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.space2),
            child: Text(
              l10n.nodeConfigChecklistEmpty,
              style: typography.bodySmall.copyWith(
                color: colors.onSurfaceMuted,
              ),
            ),
          )
        else
          for (var i = 0; i < _rows.length; i++) ...<Widget>[
            _ChecklistRuleCard(
              key: _rows[i].id,
              index: i,
              row: _rows[i],
              onChanged: () {
                setState(() {});
                _emit();
              },
              onRemove: () => _removeRule(i),
            ),
            SizedBox(height: spacing.space2),
          ],
        HiveButton(
          key: const Key('config_checklist_add_rule'),
          label: l10n.nodeConfigChecklistAddRule,
          icon: HiveIcons.add,
          variant: HiveButtonVariant.secondary,
          size: HiveButtonSize.small,
          onPressed: _addRule,
        ),
      ],
    );
  }
}

class _ChecklistRuleCard extends StatelessWidget {
  const new({
    required this.index,
    required this.row,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _ChecklistRuleControllers row;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;

    return HiveCard(
      surface: HiveCardSurface.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: HiveTextField(
                  key: Key('config_checklist_rule_${index}_label'),
                  label: l10n.nodeConfigChecklistRuleLabelField,
                  controller: row.label,
                  onChanged: (_) => onChanged(),
                ),
              ),
              SizedBox(width: spacing.space1),
              HiveIconButton(
                key: Key('config_checklist_rule_${index}_remove'),
                icon: HiveIcons.delete,
                size: HiveButtonSize.small,
                semanticLabel: l10n.nodeConfigChecklistRemoveRule,
                onPressed: onRemove,
              ),
            ],
          ),
          SizedBox(height: spacing.space2),
          HiveSelect<ChecklistRuleKind>(
            key: Key('config_checklist_rule_${index}_kind'),
            label: l10n.nodeConfigChecklistRuleKindField,
            value: row.kind,
            options: <HiveSelectOption<ChecklistRuleKind>>[
              HiveSelectOption<ChecklistRuleKind>(
                value: ChecklistRuleKind.fileExists,
                label: l10n.nodeConfigChecklistRuleKindFileExists,
              ),
              HiveSelectOption<ChecklistRuleKind>(
                value: ChecklistRuleKind.commandSucceeds,
                label: l10n.nodeConfigChecklistRuleKindCommandSucceeds,
              ),
              HiveSelectOption<ChecklistRuleKind>(
                value: ChecklistRuleKind.outputMatchesRegex,
                label: l10n.nodeConfigChecklistRuleKindOutputMatchesRegex,
              ),
            ],
            onChanged: (kind) {
              row.kind = kind;
              onChanged();
            },
          ),
          if (row.kind == ChecklistRuleKind.fileExists) ...<Widget>[
            SizedBox(height: spacing.space2),
            HiveTextField(
              key: Key('config_checklist_rule_${index}_path'),
              label: l10n.nodeConfigChecklistRulePathField,
              hint: l10n.nodeConfigChecklistRulePathHint,
              controller: row.path,
              onChanged: (_) => onChanged(),
            ),
          ] else ...<Widget>[
            SizedBox(height: spacing.space2),
            HiveTextField(
              key: Key('config_checklist_rule_${index}_command'),
              label: l10n.nodeConfigCommandLabel,
              hint: l10n.nodeConfigCommandHint,
              controller: row.command,
              onChanged: (_) => onChanged(),
            ),
            SizedBox(height: spacing.space2),
            HiveTextField(
              key: Key('config_checklist_rule_${index}_working_directory'),
              label: l10n.nodeConfigWorkingDirectoryLabel,
              hint: l10n.nodeConfigWorkingDirectoryHint,
              controller: row.workingDirectory,
              onChanged: (_) => onChanged(),
            ),
            if (row.kind == ChecklistRuleKind.outputMatchesRegex) ...<Widget>[
              SizedBox(height: spacing.space2),
              HiveTextField(
                key: Key('config_checklist_rule_${index}_pattern'),
                label: l10n.nodeConfigChecklistRulePatternField,
                hint: l10n.nodeConfigChecklistRulePatternHint,
                controller: row.pattern,
                onChanged: (_) => onChanged(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
