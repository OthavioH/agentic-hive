import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/foundation/hive_spinner.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A circular icon-only button. It shares variants and sizes with
/// [HiveButton]; its diameter is the button height.
///
/// While [loading], it shows a spinner in place of the icon and ignores
/// activation, like `HiveButton.loading`.
class HiveIconButton extends StatelessWidget {
  /// Creates an icon button. A null [onPressed] disables it.
  const new({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.variant = HiveButtonVariant.ghost,
    this.size = HiveButtonSize.medium,
    this.loading = false,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : _dangerHover = false;

  /// Creates a ghost icon button whose hover and pressed states use the
  /// `danger` color role with `onDanger` foreground, for window close buttons.
  const new dangerHover({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = HiveButtonSize.medium,
    this.loading = false,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : variant = HiveButtonVariant.ghost,
       _dangerHover = true;

  /// The icon.
  final HiveIconData icon;

  /// Required: icon-only controls have no visible text.
  final String semanticLabel;

  /// Called when activated; null disables the button.
  final VoidCallback? onPressed;

  /// Visual weight.
  final HiveButtonVariant variant;

  /// Size; the diameter equals [HiveButtonSize.height].
  final HiveButtonSize size;

  final bool _dangerHover;

  /// Shows a spinner in place of the icon and ignores activation.
  final bool loading;

  /// Optional external states controller (hover, focus, pressed).
  final WidgetStatesController? statesController;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Whether to request focus when first built.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final foreground = variant.foreground(colors);
    final borderRole = variant.border;
    final diameter = size.height(spacing);

    return HiveInteraction(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      busy: loading,
      statesController: statesController,
      focusNode: focusNode,
      autofocus: autofocus,
      builder: (context, states) {
        final isDangerActive =
            _dangerHover &&
            !states.contains(WidgetState.disabled) &&
            (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed));
        final effectiveForeground = isDangerActive
            ? colors.onDanger
            : foreground;
        final effectiveBackground = isDangerActive
            ? (states.contains(WidgetState.pressed)
                  ? Color.alphaBlend(
                      colors.onDanger.withValues(alpha: colors.pressedOpacity),
                      colors.danger,
                    )
                  : colors.danger)
            : hiveStateLayer(
                base: variant.background(colors),
                foreground: foreground,
                states: states,
                colors: colors,
              );
        return Opacity(
          opacity: states.contains(WidgetState.disabled)
              ? colors.disabledOpacity
              : 1,
          child: HiveFocusRing(
            focused: states.contains(WidgetState.focused),
            shape: const CircleBorder(),
            child: AnimatedContainer(
              duration: motion.resolve(context, motion.short),
              curve: motion.standardCurve,
              width: diameter,
              height: diameter,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: effectiveBackground,
                shape: CircleBorder(
                  side: borderRole == null
                      ? BorderSide.none
                      : BorderSide(
                          color: borderRole(colors),
                          width: context.hiveElevation.hairline,
                        ),
                ),
              ),
              child: loading
                  ? HiveSpinner(size: diameter / 2, color: effectiveForeground)
                  : HiveIcon(
                      icon,
                      size: diameter / 2,
                      color: effectiveForeground,
                    ),
            ),
          ),
        );
      },
    );
  }
}
