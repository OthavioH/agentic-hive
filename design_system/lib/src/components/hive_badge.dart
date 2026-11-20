import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// The color pair of a [HiveBadge].
enum HiveBadgeTone {
  /// `surface3` with `onSurface`.
  neutral(_surface3, _onSurface),

  /// `accentMuted` with `onAccentMuted`.
  accentMuted(_accentMuted, _onAccentMuted),

  /// `success` with `onSuccess`.
  success(_success, _onSuccess),

  /// `warning` with `onWarning`.
  warning(_warning, _onWarning),

  /// `danger` with `onDanger`.
  danger(_danger, _onDanger),

  /// `info` with `onInfo`.
  info(_info, _onInfo);

  new(this.background, this.foreground);

  /// Background role.
  final HiveColorRole background;

  /// Foreground role.
  final HiveColorRole foreground;
}

Color _surface3(HiveColors c) => c.surface3;
Color _onSurface(HiveColors c) => c.onSurface;
Color _accentMuted(HiveColors c) => c.accentMuted;
Color _onAccentMuted(HiveColors c) => c.onAccentMuted;
Color _success(HiveColors c) => c.success;
Color _onSuccess(HiveColors c) => c.onSuccess;
Color _warning(HiveColors c) => c.warning;
Color _onWarning(HiveColors c) => c.onWarning;
Color _danger(HiveColors c) => c.danger;
Color _onDanger(HiveColors c) => c.onDanger;
Color _info(HiveColors c) => c.info;
Color _onInfo(HiveColors c) => c.onInfo;

/// A small pill label, optionally with a leading icon.
class HiveBadge extends StatelessWidget {
  /// Creates a badge.
  const new({
    required this.label,
    this.tone = HiveBadgeTone.neutral,
    this.icon,
    this.semanticLabel,
    super.key,
  });

  /// Visible text.
  final String label;

  /// Color pair.
  final HiveBadgeTone tone;

  /// Optional leading icon.
  final HiveIconData? icon;

  /// Accessibility label; defaults to [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final foreground = tone.foreground(colors);
    final leading = icon;
    return Semantics(
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tone.background(colors),
            borderRadius: context.hiveRadii.pill,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.space1,
              vertical: spacing.spaceHalf,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  HiveIcon(leading, size: spacing.space2, color: foreground),
                  SizedBox(width: spacing.spaceHalf),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.hiveTypography.label.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
