import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_elevation.dart';
import 'package:design_system/src/tokens/hive_motion_tokens.dart';
import 'package:design_system/src/tokens/hive_radii.dart';
import 'package:design_system/src/tokens/hive_spacing.dart';
import 'package:design_system/src/tokens/hive_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Context accessors for the design system tokens.
///
/// Each accessor reads the [ThemeExtension] from the nearest `Theme` and
/// falls back to the dark defaults when a theme was not built with
/// `HiveTheme`.
extension HiveTokensContext on BuildContext {
  /// Semantic color roles.
  HiveColors get hiveColors =>
      Theme.of(this).extension<HiveColors>() ?? HiveColors.dark;

  /// The 8-point spacing scale.
  HiveSpacing get hiveSpacing =>
      Theme.of(this).extension<HiveSpacing>() ?? HiveSpacing.standard;

  /// Radius by role.
  HiveRadii get hiveRadii =>
      Theme.of(this).extension<HiveRadii>() ?? HiveRadii.standard;

  /// Typography roles.
  HiveTypography get hiveTypography =>
      Theme.of(this).extension<HiveTypography>() ?? HiveTypography.standard;

  /// Hairlines, focus ring width and the two shadow tokens.
  HiveElevation get hiveElevation =>
      Theme.of(this).extension<HiveElevation>() ?? HiveElevation.dark;

  /// Motion durations and curves.
  HiveMotionTokens get hiveMotion =>
      Theme.of(this).extension<HiveMotionTokens>() ?? HiveMotionTokens.standard;
}
