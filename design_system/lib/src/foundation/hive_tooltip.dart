import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// Shared token-styled [Tooltip] for truncated labels and chips.
class HiveTooltip extends StatelessWidget {
  /// Creates a tooltip that shows [message] on hover without duplicating
  /// semantics.
  const new({required this.message, required this.child, super.key});

  /// Tooltip text.
  final String message;

  /// Child widget wrapped by the tooltip.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final typography = context.hiveTypography;
    return Tooltip(
      message: message,
      excludeFromSemantics: true,
      waitDuration: motion.resolve(context, motion.long),
      exitDuration: motion.resolve(context, motion.short),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space1,
        vertical: spacing.spaceHalf,
      ),
      decoration: ShapeDecoration(
        color: colors.surface3,
        shape: StadiumBorder(
          side: BorderSide(
            color: colors.borderSubtle,
            width: context.hiveElevation.hairline,
          ),
        ),
      ),
      textStyle: typography.bodySmall.copyWith(color: colors.onSurface),
      child: child,
    );
  }
}
