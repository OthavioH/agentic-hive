import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/components/hive_icon_button.dart';
import 'package:design_system/src/components/hive_text_field.dart';
import 'package:design_system/src/foundation/hive_list_field_frame.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// An editable list of key/value string pairs, such as environment
/// variables.
///
/// Each row is a key field, a value field and a remove button. Rows keep a
/// stable identity while they are edited, so changing a key never reorders
/// rows or moves the focus. [onChanged] receives every pair in row order,
/// including rows whose key is empty or repeated; convert with
/// `Map.fromEntries` once the keys are valid.
///
/// Keyboard: Enter in a key field moves to its value; Enter in the last
/// value field adds a row. A repeated key shows [duplicateKeyText] and an
/// empty key next to a value shows [emptyKeyText] under the key field.
class HiveKeyValueEditor extends StatefulWidget {
  /// Creates a key/value editor. A null [onChanged] disables it.
  const new({
    required this.entries,
    required this.onChanged,
    this.label,
    this.helperText,
    this.errorText,
    this.keyLabel = 'Key',
    this.valueLabel = 'Value',
    this.keyPlaceholder,
    this.valuePlaceholder,
    this.addButtonLabel = 'Add entry',
    this.removeButtonLabel = 'Remove',
    this.emptyText,
    this.duplicateKeyText = 'Duplicate key',
    this.emptyKeyText = 'Key is required',
    this.enabled = true,
    super.key,
  });

  /// The pairs, in row order. Rows are rebuilt only when this differs from
  /// both the previous value and what the rows already hold.
  final List<MapEntry<String, String>> entries;

  /// Called with every pair after each edit, addition or removal.
  final ValueChanged<List<MapEntry<String, String>>>? onChanged;

  /// Visible group label above the rows.
  final String? label;

  /// Supporting text below the editor; hidden while [errorText] is set.
  final String? helperText;

  /// Error text below the editor.
  final String? errorText;

  /// Accessibility label of each key field, followed by the row number.
  final String keyLabel;

  /// Accessibility label of each value field, followed by the row number.
  final String valueLabel;

  /// Placeholder of an empty key field.
  final String? keyPlaceholder;

  /// Placeholder of an empty value field.
  final String? valuePlaceholder;

  /// Label of the add button.
  final String addButtonLabel;

  /// Accessibility label of each remove button, followed by the row's key
  /// (or [keyLabel] and the row number while the key is empty).
  final String removeButtonLabel;

  /// Text shown in place of the rows while there are none.
  final String? emptyText;

  /// Error under a key that more than one row uses.
  final String duplicateKeyText;

  /// Error under an empty key whose row has a value.
  final String emptyKeyText;

  /// Whether the editor accepts input.
  final bool enabled;

  @override
  State<HiveKeyValueEditor> createState() => _HiveKeyValueEditorState();
}

class _EntryRow {
  new(String key, String value)
    : keyController = TextEditingController(text: key),
      valueController = TextEditingController(text: value);

  final LocalKey id = UniqueKey();
  final TextEditingController keyController;
  final TextEditingController valueController;
  final FocusNode keyFocus = FocusNode();
  final FocusNode valueFocus = FocusNode();

  MapEntry<String, String> get entry =>
      MapEntry<String, String>(keyController.text, valueController.text);

  void dispose() {
    keyController.dispose();
    valueController.dispose();
    keyFocus.dispose();
    valueFocus.dispose();
  }
}

bool _sameEntries(
  List<MapEntry<String, String>> a,
  List<MapEntry<String, String>> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].key != b[i].key || a[i].value != b[i].value) return false;
  }
  return true;
}

void _setText(TextEditingController controller, String text) {
  if (controller.text != text) controller.text = text;
}

class _HiveKeyValueEditorState extends State<HiveKeyValueEditor> {
  final List<_EntryRow> _rows = <_EntryRow>[];
  final FocusNode _addFocus = FocusNode();

  bool get _enabled => widget.enabled && widget.onChanged != null;

  List<MapEntry<String, String>> get _entries => <MapEntry<String, String>>[
    for (final row in _rows) row.entry,
  ];

  @override
  void initState() {
    super.initState();
    _sync(widget.entries);
  }

  @override
  void didUpdateWidget(HiveKeyValueEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameEntries(widget.entries, oldWidget.entries) &&
        !_sameEntries(widget.entries, _entries)) {
      _sync(widget.entries);
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

  /// Matches the rows to [entries], reusing rows by position so focus and
  /// selection survive.
  void _sync(List<MapEntry<String, String>> entries) {
    while (_rows.length > entries.length) {
      _rows.removeLast().dispose();
    }
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (i < _rows.length) {
        _setText(_rows[i].keyController, entry.key);
        _setText(_rows[i].valueController, entry.value);
      } else {
        _rows.add(_EntryRow(entry.key, entry.value));
      }
    }
  }

  void _emit() {
    setState(() {});
    widget.onChanged?.call(_entries);
  }

  void _focusLater(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node.requestFocus();
    });
  }

  void _add() {
    final row = _EntryRow('', '');
    _rows.add(row);
    _emit();
    _focusLater(row.keyFocus);
  }

  void _remove(_EntryRow row) {
    final index = _rows.indexOf(row);
    _rows.removeAt(index);
    _emit();
    _focusLater(
      _rows.isEmpty
          ? _addFocus
          : _rows[index < _rows.length ? index : _rows.length - 1].keyFocus,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _submitValue(_EntryRow row) {
    final index = _rows.indexOf(row);
    if (index == _rows.length - 1) {
      _add();
    } else {
      _rows[index + 1].keyFocus.requestFocus();
    }
  }

  String? _keyError(_EntryRow row, Map<String, int> counts) {
    final key = row.keyController.text;
    if (key.trim().isEmpty) {
      return row.valueController.text.isEmpty ? null : widget.emptyKeyText;
    }
    return (counts[key] ?? 0) > 1 ? widget.duplicateKeyText : null;
  }

  String _removeLabel(_EntryRow row, int index) {
    final key = row.keyController.text.trim();
    return '${widget.removeButtonLabel} '
        '${key.isEmpty ? '${widget.keyLabel} ${index + 1}' : key}';
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    final enabled = _enabled;
    final counts = <String, int>{};
    for (final row in _rows) {
      final key = row.keyController.text;
      counts[key] = (counts[key] ?? 0) + 1;
    }

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
                  label: '${widget.keyLabel} ${index + 1}',
                  showLabel: false,
                  controller: row.keyController,
                  focusNode: row.keyFocus,
                  hint: widget.keyPlaceholder,
                  errorText: _keyError(row, counts),
                  enabled: enabled,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _emit(),
                  onSubmitted: (_) => row.valueFocus.requestFocus(),
                ),
              ),
              SizedBox(width: spacing.space1),
              Expanded(
                child: HiveTextField(
                  label: '${widget.valueLabel} ${index + 1}',
                  showLabel: false,
                  controller: row.valueController,
                  focusNode: row.valueFocus,
                  hint: widget.valuePlaceholder,
                  enabled: enabled,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => _emit(),
                  onSubmitted: (_) => _submitValue(row),
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
        onPressed: enabled ? _add : null,
      ),
    );
  }
}
