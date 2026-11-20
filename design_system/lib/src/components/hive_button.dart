import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/foundation/hive_spinner.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_spacing.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:design_system/src/tokens/hive_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Visual weight of a button, as color roles.
enum HiveButtonVariant {
  /// The one primary action of a screen: `accent` with `onAccent`.
  primary(_accent, _onAccent, null),

  /// Secondary actions: `surface3` with `onSurface` and a hairline.
  secondary(_surface3, _onSurface, _borderSubtle),

  /// Low-emphasis actions: transparent with `onSurface`.
  ghost(_transparent, _onSurface, null);

  new(this.background, this.foreground, this.border);

  /// Resting background role.
  final HiveColorRole background;

  /// Label and icon role.
  final HiveColorRole foreground;

  /// Hairline border role, or null for none.
  final HiveColorRole? border;
}

Color _accent(HiveColors c) => c.accent;
Color _onAccent(HiveColors c) => c.onAccent;
Color _surface3(HiveColors c) => c.surface3;
Color _onSurface(HiveColors c) => c.onSurface;
Color _borderSubtle(HiveColors c) => c.borderSubtle;
Color _transparent(HiveColors c) => c.background.withValues(alpha: 0);

/// Button size, as spacing and typography tokens.
enum HiveButtonSize {
  /// Height `space4` (32), label 12/16.
  small(_space4, _space2, _label),

  /// Height `space5` (40), label 16/24.
  medium(_space5, _space3, _labelLarge),

  /// Height `space6` (48), label 16/24.
  large(_space6, _space3, _labelLarge);

  new(this.height, this.horizontalPadding, this.textStyle);

  /// Height of the button.
  final double Function(HiveSpacing spacing) height;

  /// Horizontal padding inside the pill.
  final double Function(HiveSpacing spacing) horizontalPadding;

  /// Label style.
  final TextStyle Function(HiveTypography typography) textStyle;
}

double _space2(HiveSpacing s) => s.space2;
double _space3(HiveSpacing s) => s.space3;
double _space4(HiveSpacing s) => s.space4;
double _space5(HiveSpacing s) => s.space5;
double _space6(HiveSpacing s) => s.space6;
TextStyle _label(HiveTypography t) => t.label;
TextStyle _labelLarge(HiveTypography t) => t.labelLarge;

/// A pill-shaped text button with hover, focus, pressed, disabled and loading
/// states.
class HiveButton extends StatelessWidget {
  /// Creates a button. A null [onPressed] disables it.
  const new({
    required this.label,
    required this.onPressed,
    this.variant = HiveButtonVariant.primary,
    this.size = HiveButtonSize.medium,
    this.icon,
    this.loading = false,
    this.semanticLabel,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Visible label.
  final String label;

  /// Called when activated; null disables the button.
  final VoidCallback? onPressed;

  /// Visual weight.
  final HiveButtonVariant variant;

  /// Size.
  final HiveButtonSize size;

  /// Optional leading icon.
  final HiveIconData? icon;

  /// Shows a spinner in place of the icon and ignores activation.
  final bool loading;

  /// Accessibility label; defaults to [label].
  final String? semanticLabel;

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
    final iconSize = spacing.space2;
    final leading = icon;

    return HiveInteraction(
      semanticLabel: semanticLabel ?? label,
      onPressed: onPressed,
      busy: loading,
      statesController: statesController,
      focusNode: focusNode,
      autofocus: autofocus,
      builder: (context, states) {
        final background = hiveStateLayer(
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
            shape: const StadiumBorder(),
            child: AnimatedContainer(
              duration: motion.resolve(context, motion.short),
              curve: motion.standardCurve,
              height: size.height(spacing),
              padding: EdgeInsets.symmetric(
                horizontal: size.horizontalPadding(spacing),
              ),
              decoration: ShapeDecoration(
                color: background,
                shape: StadiumBorder(
                  side: borderRole == null
                      ? BorderSide.none
                      : BorderSide(
                          color: borderRole(colors),
                          width: context.hiveElevation.hairline,
                        ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (loading)
                    HiveSpinner(size: iconSize, color: foreground)
                  else if (leading != null)
                    HiveIcon(leading, size: iconSize, color: foreground),
                  if (loading || leading != null)
                    SizedBox(width: spacing.space1),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: size
                          .textStyle(context.hiveTypography)
                          .copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
