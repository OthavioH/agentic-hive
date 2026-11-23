import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// The tone of a `HiveBanner` or `HiveToast`: a color role pair and an icon,
/// so the tone is shown by icon shape as well as color.
enum HiveFeedbackTone {
  /// Neutral information (an agent changed on disk).
  info(_info, _onInfo, HiveIcons.info),

  /// A completed action (agent saved).
  success(_success, _onSuccess, HiveIcons.success),

  /// Needs attention but nothing failed (unsaved external changes).
  warning(_warning, _onWarning, HiveIcons.alert),

  /// Something failed (a file that cannot be parsed).
  danger(_danger, _onDanger, HiveIcons.alert);

  new(this.color, this.onColor, this.icon);

  /// Tone role: borders and the icon badge fill.
  final HiveColorRole color;

  /// Foreground on [color]: the icon inside the badge.
  final HiveColorRole onColor;

  /// The icon shown in the badge.
  final HiveIconData icon;
}

Color _info(HiveColors c) => c.info;
Color _onInfo(HiveColors c) => c.onInfo;
Color _success(HiveColors c) => c.success;
Color _onSuccess(HiveColors c) => c.onSuccess;
Color _warning(HiveColors c) => c.warning;
Color _onWarning(HiveColors c) => c.onWarning;
Color _danger(HiveColors c) => c.danger;
Color _onDanger(HiveColors c) => c.onDanger;

/// The tone icon in a filled circle (`space4`), used by banners and toasts.
class HiveToneBadge extends StatelessWidget {
  /// Creates the badge for [tone].
  const new({required this.tone, required this.diameter, super.key});

  /// The tone.
  final HiveFeedbackTone tone;

  /// Circle diameter.
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: tone.color(colors),
        shape: const CircleBorder(),
      ),
      child: HiveIcon(
        tone.icon,
        size: diameter / 2,
        color: tone.onColor(colors),
      ),
    );
  }
}
