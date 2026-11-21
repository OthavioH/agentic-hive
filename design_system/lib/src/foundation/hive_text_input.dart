import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// The shape and density a [HiveTextInput] is drawn with.
///
/// Each kind is one variation of the shared input frame: single-line inputs
/// are pills, multi-line inputs are `radiusCard` containers because a pill
/// radius on a tall box turns into a stadium.
abstract class HiveTextInputKind {
  /// Creates a kind.
  const new();

  /// The frame outline.
  OutlinedBorder shape(BuildContext context, BorderSide side);

  /// Padding between the frame and the text.
  EdgeInsets padding(BuildContext context);

  /// The text style role, without color.
  TextStyle textStyle(BuildContext context);

  /// Minimum frame height, or null to size by the text.
  double? minHeight(BuildContext context);

  /// Configures the editable text: line counts and keyboard.
  int? get maxLines;

  /// Minimum visible lines.
  int? get minLines;

  /// Whether the text fills the frame's height.
  bool get expands;

  /// Keyboard type for the platform input method.
  TextInputType get keyboardType;
}

/// A single-line pill input: height `space5` (40), `body` text.
class HiveSingleLineInput extends HiveTextInputKind {
  /// Creates the single-line kind.
  const new();

  @override
  OutlinedBorder shape(BuildContext context, BorderSide side) =>
      StadiumBorder(side: side);

  @override
  EdgeInsets padding(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: context.hiveSpacing.space2);

  @override
  TextStyle textStyle(BuildContext context) => context.hiveTypography.body;

  @override
  double? minHeight(BuildContext context) => context.hiveSpacing.space5;

  @override
  int? get maxLines => 1;

  @override
  int? get minLines => null;

  @override
  bool get expands => false;

  @override
  TextInputType get keyboardType => TextInputType.text;
}

/// A multi-line `radiusCard` input, in `body` or `mono` text.
class HiveMultiLineInput extends HiveTextInputKind {
  /// Creates the multi-line kind.
  const new({
    required this.mono,
    required this.minLines,
    required this.maxLines,
    required this.expands,
  });

  /// Whether the text uses the `mono` role (Markdown, code, logs).
  final bool mono;

  @override
  final int? minLines;

  @override
  final int? maxLines;

  @override
  final bool expands;

  @override
  OutlinedBorder shape(BuildContext context, BorderSide side) =>
      RoundedRectangleBorder(borderRadius: context.hiveRadii.card, side: side);

  @override
  EdgeInsets padding(BuildContext context) =>
      EdgeInsets.all(context.hiveSpacing.space2);

  @override
  TextStyle textStyle(BuildContext context) =>
      mono ? context.hiveTypography.mono : context.hiveTypography.body;

  @override
  double? minHeight(BuildContext context) => null;

  @override
  TextInputType get keyboardType => TextInputType.multiline;
}

/// The shared text input used by `HiveTextField` and `HiveTextArea`.
///
/// Draws a `surface3` frame with a `borderSubtle` hairline that turns
/// `onSurfaceMuted` on hover and `danger` on error, the keyboard focus ring
/// while focused, an optional visible [label] above and a helper or error
/// line below. Pass a [statesController] to show hovered or focused
/// statically (Widgetbook, golden tests).
class HiveTextInput extends StatefulWidget {
  /// Creates an input of the given [kind].
  const new({
    required this.kind,
    this.label,
    this.semanticLabel,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.errorText,
    this.leadingIcon,
    this.trailing,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.statesController,
    super.key,
  }) : assert(
         label != null || semanticLabel != null,
         'Inputs need a visible label or a semanticLabel.',
       );

  /// Shape, density, text role and line configuration.
  final HiveTextInputKind kind;

  /// Visible label above the input; also the semantics label.
  final String? label;

  /// Semantics label when there is no visible [label] (search inputs).
  final String? semanticLabel;

  /// Text controller; one is created when null.
  final TextEditingController? controller;

  /// Focus node; one is created when null.
  final FocusNode? focusNode;

  /// Placeholder shown while empty.
  final String? hintText;

  /// Help text below the input, hidden while [errorText] is set.
  final String? helperText;

  /// Error message below the input; non-null puts the input in error state.
  final String? errorText;

  /// Optional leading icon (single-line inputs, for example search).
  final HiveIconData? leadingIcon;

  /// Optional trailing widget, for example a clear `HiveIconButton`.
  final Widget? trailing;

  /// Whether the input accepts focus and edits.
  final bool enabled;

  /// Whether the text is selectable but not editable.
  final bool readOnly;

  /// Whether to request focus when first built.
  final bool autofocus;

  /// Whether to hide the text (secrets).
  final bool obscureText;

  /// The keyboard action button.
  final TextInputAction? textInputAction;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits (Enter on single-line inputs).
  final ValueChanged<String>? onSubmitted;

  /// Optional external states (hovered, focused) for static previews.
  final WidgetStatesController? statesController;

  @override
  State<HiveTextInput> createState() => _HiveTextInputState();
}

class _HiveTextInputState extends State<HiveTextInput> {
  // Keeps the editable text's state when the focus ring wraps the frame.
  final GlobalKey _fieldKey = GlobalKey();
  FocusNode? _ownFocusNode;
  bool _hovered = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onChanged);
    widget.statesController?.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(HiveTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onChanged);
      _focusNode.addListener(_onChanged);
    }
    if (oldWidget.statesController != widget.statesController) {
      oldWidget.statesController?.removeListener(_onChanged);
      widget.statesController?.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onChanged);
    widget.statesController?.removeListener(_onChanged);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Set<WidgetState> get _states {
    final external = widget.statesController?.value ?? const <WidgetState>{};
    return <WidgetState>{
      ...external,
      if (_hovered) WidgetState.hovered,
      if (_focusNode.hasFocus) WidgetState.focused,
      if (!widget.enabled) WidgetState.disabled,
      if (widget.errorText != null) WidgetState.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final motion = context.hiveMotion;
    final kind = widget.kind;
    final states = _states;
    final error = widget.errorText;
    final helper = widget.helperText;
    final label = widget.label;
    final leading = widget.leadingIcon;
    final trailing = widget.trailing;

    final Color borderColor;
    if (states.contains(WidgetState.error)) {
      borderColor = colors.danger;
    } else if (states.contains(WidgetState.hovered) &&
        !states.contains(WidgetState.disabled)) {
      borderColor = colors.onSurfaceMuted;
    } else {
      borderColor = colors.borderSubtle;
    }
    final side = BorderSide(
      color: borderColor,
      width: context.hiveElevation.hairline,
    );
    final textStyle = kind.textStyle(context);

    final field = TextField(
      key: _fieldKey,
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText,
      maxLines: kind.expands ? null : kind.maxLines,
      minLines: kind.expands ? null : kind.minLines,
      expands: kind.expands,
      keyboardType: kind.keyboardType,
      textInputAction: widget.textInputAction,
      textAlignVertical: kind.expands ? TextAlignVertical.top : null,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      cursorColor: colors.onSurface,
      style: textStyle.copyWith(color: colors.onSurface),
      decoration: InputDecoration.collapsed(
        hintText: widget.hintText,
        hintStyle: textStyle.copyWith(color: colors.onSurfaceMuted),
      ),
    );

    final frame = HiveFocusRing(
      focused: states.contains(WidgetState.focused),
      shape: kind.shape(context, BorderSide.none),
      child: AnimatedContainer(
        duration: motion.resolve(context, motion.short),
        curve: motion.standardCurve,
        constraints: BoxConstraints(minHeight: kind.minHeight(context) ?? 0),
        padding: kind.padding(context),
        alignment: kind.expands ? Alignment.topLeft : Alignment.centerLeft,
        decoration: ShapeDecoration(
          color: colors.surface3,
          shape: kind.shape(context, side),
        ),
        child: Row(
          crossAxisAlignment: kind.expands
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              HiveIcon(
                leading,
                size: spacing.space2,
                color: colors.onSurfaceMuted,
              ),
              SizedBox(width: spacing.space1),
            ],
            Expanded(
              child: MergeSemantics(
                child: Semantics(
                  label: label ?? widget.semanticLabel,
                  child: field,
                ),
              ),
            ),
            if (trailing != null) ...<Widget>[
              SizedBox(width: spacing.space1),
              trailing,
            ],
          ],
        ),
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: kind.expands ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        if (label != null) ...<Widget>[
          ExcludeSemantics(
            child: Text(
              label,
              style: typography.label.copyWith(color: colors.onSurfaceMuted),
            ),
          ),
          SizedBox(height: spacing.space1),
        ],
        if (kind.expands) Expanded(child: frame) else frame,
        if (error != null)
          Padding(
            padding: EdgeInsets.only(top: spacing.space1),
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  HiveIcon(
                    HiveIcons.alert,
                    size: spacing.space2,
                    color: colors.danger,
                  ),
                  SizedBox(width: spacing.spaceHalf),
                  Expanded(
                    child: Text(
                      error,
                      style: typography.bodySmall.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (helper != null)
          Padding(
            padding: EdgeInsets.only(top: spacing.space1),
            child: Text(
              helper,
              style: typography.bodySmall.copyWith(
                color: colors.onSurfaceMuted,
              ),
            ),
          ),
      ],
    );

    return Material(
      type: MaterialType.transparency,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Opacity(
          opacity: widget.enabled ? 1 : colors.disabledOpacity,
          child: body,
        ),
      ),
    );
  }
}
