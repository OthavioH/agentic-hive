import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// The shared frame of every form field (`HiveTextField`, `HiveSelect`).
///
/// Draws the visible label above, the `surface3` well with its hover layer,
/// a `borderSubtle` hairline (`danger` while [errorText] is set), the focus
/// ring while focused, and the helper or error text below. The visible label
/// is excluded from semantics: each field announces it on its own node.
class HiveFieldFrame extends StatelessWidget {
  /// Creates a field frame around [child].
  const new({
    required this.label,
    required this.states,
    required this.shape,
    required this.padding,
    required this.child,
    this.helperText,
    this.errorText,
    this.onTap,
    this.onHover,
    this.cursor = SystemMouseCursors.text,
    this.showLabel = true,
    super.key,
  });

  /// Visible label above the well.
  final String label;

  /// Whether [label] is drawn above the well. Rows of a list editor hide it
  /// and announce their label through semantics only.
  final bool showLabel;

  /// Current interaction states (hovered, focused, disabled).
  final Set<WidgetState> states;

  /// Outline of the well: a pill or a card.
  final OutlinedBorder shape;

  /// Padding inside the well.
  final EdgeInsetsGeometry padding;

  /// The input.
  final Widget child;

  /// Supporting text below the well; hidden while [errorText] is set.
  final String? helperText;

  /// Error text below the well.
  final String? errorText;

  /// Called when the well is tapped outside the input.
  final VoidCallback? onTap;

  /// Called when the pointer enters (true) or leaves (false) the well.
  final ValueChanged<bool>? onHover;

  /// Cursor over an enabled well.
  final MouseCursor cursor;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final motion = context.hiveMotion;
    final disabled = states.contains(WidgetState.disabled);
    final error = errorText;
    final helper = error ?? helperText;
    final hasError = error != null;

    final well = HiveFocusRing(
      focused: states.contains(WidgetState.focused),
      shape: shape,
      child: AnimatedContainer(
        duration: motion.resolve(context, motion.short),
        curve: motion.standardCurve,
        constraints: BoxConstraints(minHeight: spacing.space5),
        alignment: AlignmentDirectional.centerStart,
        padding: padding,
        decoration: ShapeDecoration(
          color: hiveStateLayer(
            base: colors.surface3,
            foreground: colors.onSurface,
            states: states.difference(<WidgetState>{WidgetState.pressed}),
            colors: colors,
          ),
          shape: shape.copyWith(
            side: BorderSide(
              color: hasError ? colors.danger : colors.borderSubtle,
              width: context.hiveElevation.hairline,
            ),
          ),
        ),
        child: child,
      ),
    );

    return Opacity(
      opacity: disabled ? colors.disabledOpacity : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showLabel) ...<Widget>[
            ExcludeSemantics(
              child: Text(
                label,
                style: typography.label.copyWith(color: colors.onSurface),
              ),
            ),
            SizedBox(height: spacing.space1),
          ],
          MouseRegion(
            cursor: disabled ? SystemMouseCursors.basic : cursor,
            onEnter: disabled ? null : (_) => onHover?.call(true),
            onExit: (_) => onHover?.call(false),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: disabled ? null : onTap,
              child: well,
            ),
          ),
          if (helper != null) ...<Widget>[
            SizedBox(height: spacing.space1),
            HiveFieldMessage(text: helper, isError: hasError),
          ],
        ],
      ),
    );
  }
}

/// The helper or error line below a form field: `onSurfaceMuted` body text,
/// or `danger` text with the alert icon while [isError] is set.
class HiveFieldMessage extends StatelessWidget {
  /// Creates a field message.
  const new({required this.text, this.isError = false, super.key});

  /// The message.
  final String text;

  /// Whether the message reports an error.
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (isError) ...<Widget>[
          HiveIcon(HiveIcons.alert, size: spacing.space2, color: colors.danger),
          SizedBox(width: spacing.spaceHalf),
        ],
        Expanded(
          child: Text(
            text,
            style: context.hiveTypography.bodySmall.copyWith(
              color: isError ? colors.danger : colors.onSurfaceMuted,
            ),
          ),
        ),
      ],
    );
  }
}
