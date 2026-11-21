import 'package:design_system/src/foundation/hive_field_frame.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A labelled text input with hint, helper and error text.
///
/// Single-line fields are pills (`radiusPill`); multi-line fields use
/// `radiusCard`. The field shows a hover layer, the focus ring while it is
/// focused, a `danger` hairline when [errorText] is set and is announced to
/// screen readers with [label] (or [semanticLabel]).
class HiveTextField extends StatefulWidget {
  /// Creates a text field. Give it a visible [label], or a [semanticLabel]
  /// when the context already names it (for example a search input).
  const new({
    this.label,
    this.semanticLabel,
    this.controller,
    this.hint,
    this.hintText,
    this.helperText,
    this.errorText,
    this.leadingIcon,
    this.trailing,
    this.multiline = false,
    this.minLines = 3,
    this.maxLines = 8,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : assert(
         label != null || semanticLabel != null,
         'HiveTextField needs a visible label or a semanticLabel.',
       );

  /// Visible label above the field.
  final String? label;

  /// Accessibility label; defaults to [label].
  final String? semanticLabel;

  /// Optional controller; the field owns one when null.
  final TextEditingController? controller;

  /// Placeholder shown while the field is empty.
  final String? hint;

  /// Alias for [hint].
  final String? hintText;

  /// Supporting text below the field; hidden while [errorText] is set.
  final String? helperText;

  /// Error message below the field; also turns the hairline `danger`.
  final String? errorText;

  /// Optional leading icon inside a single-line field.
  final HiveIconData? leadingIcon;

  /// Optional trailing widget inside a single-line field.
  final Widget? trailing;

  /// Whether the field accepts several lines (uses `radiusCard`).
  final bool multiline;

  /// Visible lines of a [multiline] field when empty.
  final int minLines;

  /// Lines a [multiline] field grows to before it scrolls.
  final int maxLines;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether the text can be selected but not changed.
  final bool readOnly;

  /// Whether to obscure the text (single-line only).
  final bool obscureText;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits a single-line field.
  final ValueChanged<String>? onSubmitted;

  /// The keyboard action button.
  final TextInputAction? textInputAction;

  /// Optional external states controller (hover, focus), for previews.
  final WidgetStatesController? statesController;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Whether to request focus when first built.
  final bool autofocus;

  @override
  State<HiveTextField> createState() => _HiveTextFieldState();
}

class _HiveTextFieldState extends State<HiveTextField> {
  WidgetStatesController? _ownStates;
  FocusNode? _ownFocusNode;

  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _states
      ..update(WidgetState.disabled, !widget.enabled)
      ..addListener(_onChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(HiveTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      (oldWidget.statesController ?? _ownStates)?.removeListener(_onChanged);
      _states.addListener(_onChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocusChanged);
      _focusNode.addListener(_onFocusChanged);
    }
    _states.update(WidgetState.disabled, !widget.enabled);
  }

  @override
  void dispose() {
    _states.removeListener(_onChanged);
    _focusNode.removeListener(_onFocusChanged);
    _ownStates?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    _states.update(WidgetState.focused, _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final spacing = context.hiveSpacing;
    final states = _states.value;
    final enabled = widget.enabled;
    final effectiveHint = widget.hint ?? widget.hintText;
    final leading = widget.leadingIcon;
    final trailing = widget.trailing;

    final field = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      enabled: enabled,
      readOnly: widget.readOnly,
      obscureText: !widget.multiline && widget.obscureText,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      keyboardType: widget.multiline
          ? TextInputType.multiline
          : TextInputType.text,
      minLines: widget.multiline ? widget.minLines : 1,
      maxLines: widget.multiline ? widget.maxLines : 1,
      style: typography.body.copyWith(color: colors.onSurface),
      cursorColor: colors.onSurface,
      decoration: InputDecoration.collapsed(
        hintText: effectiveHint,
        hintStyle: typography.body.copyWith(color: colors.onSurfaceMuted),
      ),
    );

    final Widget content;
    if (leading == null && trailing == null) {
      content = field;
    } else {
      content = Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            HiveIcon(
              leading,
              size: spacing.space2,
              color: colors.onSurfaceMuted,
            ),
            SizedBox(width: spacing.space1),
          ],
          Expanded(child: field),
          if (trailing != null) ...<Widget>[
            SizedBox(width: spacing.space1),
            trailing,
          ],
        ],
      );
    }

    return HiveFieldFrame(
      label: widget.label,
      helperText: widget.helperText,
      errorText: widget.errorText,
      states: states,
      shape: widget.multiline
          ? RoundedRectangleBorder(borderRadius: context.hiveRadii.card)
          : const StadiumBorder(),
      padding: widget.multiline
          ? EdgeInsets.all(spacing.space2)
          : EdgeInsets.symmetric(horizontal: spacing.space2),
      onTap: enabled ? _focusNode.requestFocus : null,
      onHover: (hovered) => _states.update(WidgetState.hovered, hovered),
      child: MergeSemantics(
        child: Semantics(
          label: widget.semanticLabel ?? widget.label,
          // The field brings its own transparent Material, so it works
          // without a Scaffold or Material ancestor.
          child: Material(type: MaterialType.transparency, child: content),
        ),
      ),
    );
  }
}
