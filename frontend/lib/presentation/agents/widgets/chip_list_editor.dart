import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Editable list of string values rendered as removable [HiveChip]s with an
/// inline [HiveTextField] to add new items.
class ChipListEditor extends StatefulWidget {
  /// Creates a [ChipListEditor].
  const new({
    required this.label,
    required this.hintText,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  /// Field label.
  final String label;

  /// Placeholder text inside the add input.
  final String hintText;

  /// Current chip values.
  final List<String> items;

  /// Called when the user submits a new non-empty value.
  final ValueChanged<String> onAdd;

  /// Called when the user removes an existing chip.
  final ValueChanged<String> onRemove;

  @override
  State<ChipListEditor> createState() => _ChipListEditorState();
}

class _ChipListEditorState extends State<ChipListEditor> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onAdd(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HiveTextField(
          label: widget.label,
          hintText: widget.hintText,
          controller: _controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          trailing: HiveIconButton(
            icon: HiveIcons.add,
            semanticLabel: l10n.agentsAddChipTooltip,
            size: HiveButtonSize.small,
            onPressed: _submit,
          ),
        ),
        if (widget.items.isNotEmpty) ...<Widget>[
          SizedBox(height: spacing.space1),
          Wrap(
            spacing: spacing.space1,
            runSpacing: spacing.space1,
            children: <Widget>[
              for (final item in widget.items)
                HiveChip.removable(
                  label: item,
                  removeSemanticLabel: l10n.agentsRemoveChipTooltip(item),
                  onRemoved: () => widget.onRemove(item),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
