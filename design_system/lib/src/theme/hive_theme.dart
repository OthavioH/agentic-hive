import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_elevation.dart';
import 'package:design_system/src/tokens/hive_motion_tokens.dart';
import 'package:design_system/src/tokens/hive_radii.dart';
import 'package:design_system/src/tokens/hive_spacing.dart';
import 'package:design_system/src/tokens/hive_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the app `ThemeData` from the design system tokens.
///
/// Dark is the default. Both themes carry every token `ThemeExtension`, map
/// the color roles onto the `ColorScheme`, use Geist as the default family
/// and turn off Material ink splashes.
abstract final class HiveTheme {
  /// The default dark theme.
  static ThemeData dark() => _build(HiveColors.dark, HiveElevation.dark);

  /// The light theme.
  static ThemeData light() => _build(HiveColors.light, HiveElevation.light);

  static ThemeData _build(HiveColors colors, HiveElevation elevation) {
    final typography = HiveTypography.standard;
    final scheme = ColorScheme(
      brightness: colors.brightness,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: colors.accentMuted,
      onSecondary: colors.onAccentMuted,
      tertiary: colors.info,
      onTertiary: colors.onInfo,
      error: colors.danger,
      onError: colors.onDanger,
      surface: colors.surface1,
      onSurface: colors.onSurface,
      onSurfaceVariant: colors.onSurfaceMuted,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface1,
      surfaceContainer: colors.surface2,
      surfaceContainerHigh: colors.surface3,
      surfaceContainerHighest: colors.surface3,
      outline: colors.borderSubtle,
      outlineVariant: colors.borderSubtle,
    );
    TextStyle on(TextStyle style) => style.copyWith(color: colors.onSurface);
    TextStyle muted(TextStyle style) =>
        style.copyWith(color: colors.onSurfaceMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      fontFamily: HiveFontFamilies.ui,
      package: HiveFontFamilies.package,
      splashFactory: NoSplash.splashFactory,
      focusColor: colors.focusRing.withValues(alpha: colors.hoverOpacity),
      hoverColor: colors.onSurface.withValues(alpha: colors.hoverOpacity),
      highlightColor: colors.onSurface.withValues(alpha: colors.pressedOpacity),
      dividerColor: colors.borderSubtle,
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
        displayLarge: on(typography.number),
        displayMedium: on(typography.display),
        headlineSmall: on(typography.title),
        titleLarge: on(typography.title),
        titleMedium: on(typography.titleSmall),
        bodyLarge: on(typography.body),
        bodyMedium: on(typography.body),
        bodySmall: muted(typography.bodySmall),
        labelLarge: on(typography.labelLarge),
        labelMedium: on(typography.label),
        labelSmall: on(typography.label),
      ),
      extensions: <ThemeExtension<dynamic>>[
        colors,
        HiveSpacing.standard,
        HiveRadii.standard,
        typography,
        elevation,
        HiveMotionTokens.standard,
      ],
    );
  }
}

/// Paints the theme background and default text style under [child].
///
/// Use it at the root of any tree that is not inside a `Scaffold`, such as a
/// Widgetbook canvas or a test harness.
class HiveSurface extends StatelessWidget {
  /// Creates a background surface.
  const new({required this.child, super.key});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<HiveColors>() ?? HiveColors.dark;
    final typography =
        theme.extension<HiveTypography>() ?? HiveTypography.standard;
    return ColoredBox(
      color: colors.background,
      child: DefaultTextStyle(
        style: typography.body.copyWith(color: colors.onSurface),
        child: IconTheme(
          data: IconThemeData(color: colors.onSurface),
          child: child,
        ),
      ),
    );
  }
}
