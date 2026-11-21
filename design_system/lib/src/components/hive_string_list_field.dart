import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/components/hive_icon_button.dart';
import 'package:design_system/src/components/hive_text_field.dart';
import 'package:design_system/src/foundation/hive_list_field_frame.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// An editable list of strings, such as CLI `args` and `extraArgs`.
///
/// Each row is a text field and a remove button. Rows keep a stable
/// identity while they are edited, so focus never jumps. [onChanged]
/// receives every item in row order, including empty ones.
///
/// Keyboard: Enter in a non-empty item inserts a new item below it and
/// focuses it; the add button appends one.
class HiveStringListField extends StatefulWidget {
  /// Creates a string list field. A null [onChanged] disables it.
  const new({
    required this.items,
    required this.onChanged,
    this.label,
    this.helperText,
    this.errorText,
    this.itemLabel = 'Item',
    this.itemPlaceholder,
    this.addButtonLabel = 'Add item',
    this.removeButtonLabel = 'Remove',
    this.emptyText,
    this.enabled = true,
    super.key,
  });

  /// The items, in row order. Rows are rebuilt only when this differs from
  /// both the previous value and what the rows already hold.
  final List<String> items;

  /// Called with every item after each edit, addition or removal.
  final ValueChanged<List<String>>? onChanged;

  /// Visible group label above the rows.
  final String? label;

  /// Supporting text below the field; hidden while [errorText] is set.
  final String? helperText;

  /// Error text below the field.
  final String? errorText;

  /// Accessibility label of each item field, followed by the row number.
  final String itemLabel;

  /// Placeholder of an empty item.
  final String? itemPlaceholder;

  /// Label of the add button.
  final String addButtonLabel;

  /// Accessibility label of each remove button, followed by the item text
  /// (or [itemLabel] and the row number while the item is empty).
  final String removeButtonLabel;

  /// Text shown in place of the rows while there are none.
  final String? emptyText;

  /// Whether the field accepts input.
  final bool enabled;

  @override
  State<HiveStringListField> createState() => _HiveStringListFieldState();
}

class _ItemRow {
  new(String text) : controller = TextEditingController(text: text);

  final LocalKey id = UniqueKey();
  final TextEditingController controller;
  final FocusNode focus = FocusNode();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

bool _sameItems(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _HiveStringListFieldState extends State<HiveStringListField> {
  final List<_ItemRow> _rows = <_ItemRow>[];
  final FocusNode _addFocus = FocusNode();

  bool get _enabled => widget.enabled && widget.onChanged != null;

  List<String> get _items => <String>[
    for (final row in _rows) row.controller.text,
  ];

  @override
  void initState() {
    super.initState();
    _sync(widget.items);
  }

  @override
  void didUpdateWidget(HiveStringListField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameItems(widget.items, oldWidget.items) &&
        !_sameItems(widget.items, _items)) {
      _sync(widget.items);
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _addFocus.dispose();
    super.dispose();
  }

  /// Matches the rows to [items], reusing rows by position so focus and
  /// selection survive.
  void _sync(List<String> items) {
    while (_rows.length > items.length) {
      _rows.removeLast().dispose();
    }
    for (var i = 0; i < items.length; i++) {
      if (i < _rows.length) {
        final controller = _rows[i].controller;
        if (controller.text != items[i]) controller.text = items[i];
      } else {
        _rows.add(_ItemRow(items[i]));
      }
    }
  }

  void _emit() {
    setState(() {});
    widget.onChanged?.call(_items);
  }

  void _focusLater(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node.requestFocus();
    });
  }

  void _insert(int index) {
    final row = _ItemRow('');
    _rows.insert(index, row);
    _emit();
    _focusLater(row.focus);
  }

  void _remove(_ItemRow row) {
    final index = _rows.indexOf(row);
    _rows.removeAt(index);
    _emit();
    _focusLater(
      _rows.isEmpty
          ? _addFocus
          : _rows[index < _rows.length ? index : _rows.length - 1].focus,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _submit(_ItemRow row) {
    if (row.controller.text.isEmpty) {
      _focusLater(row.focus);
      return;
    }
    _insert(_rows.indexOf(row) + 1);
  }

  String _removeLabel(_ItemRow row, int index) {
    final text = row.controller.text.trim();
    return '${widget.removeButtonLabel} '
        '${text.isEmpty ? '${widget.itemLabel} ${index + 1}' : text}';
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    final enabled = _enabled;

    return HiveListFieldFrame(
      label: widget.label,
      helperText: widget.helperText,
      errorText: widget.errorText,
      emptyText: widget.emptyText,
      enabled: enabled,
      rows: <Widget>[
        for (final (index, row) in _rows.indexed)
          Row(
            key: row.id,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: HiveTextField(
                  label: '${widget.itemLabel} ${index + 1}',
                  showLabel: false,
                  controller: row.controller,
                  focusNode: row.focus,
                  hint: widget.itemPlaceholder,
                  enabled: enabled,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => _emit(),
                  onSubmitted: (_) => _submit(row),
                ),
              ),
              SizedBox(width: spacing.space1),
              HiveIconButton(
                icon: HiveIcons.delete,
                semanticLabel: _removeLabel(row, index),
                onPressed: enabled ? () => _remove(row) : null,
              ),
            ],
          ),
      ],
      addButton: HiveButton(
        label: widget.addButtonLabel,
        icon: HiveIcons.add,
        variant: HiveButtonVariant.secondary,
        size: HiveButtonSize.small,
        focusNode: _addFocus,
        onPressed: enabled ? () => _insert(_rows.length) : null,
      ),
    );
  }
}
