import 'package:material_ui/material_ui.dart';

/// Reads one semantic color role from a [HiveColors] palette.
///
/// Used wherever a component or a node visual needs to name a role without
/// holding a literal color, for example `(colors) => colors.accentMuted`.
typedef HiveColorRole = Color Function(HiveColors colors);

/// Minimum WCAG 2.x contrast ratio a [HiveContrastPair] must reach.
enum HiveContrastLevel {
  /// Normal-size text: 4.5:1 (WCAG AA, success criterion 1.4.3).
  text(4.5),

  /// Large text and non-text UI components: 3:1 (WCAG AA, 1.4.3 / 1.4.11).
  ui(3);

  new(this.minimumRatio);

  /// The minimum contrast ratio this level requires.
  final double minimumRatio;
}

/// A foreground/background token pair that must pass WCAG AA contrast.
@immutable
class HiveContrastPair {
  /// Creates a pair named after its two roles.
  const new({
    required this.foregroundRole,
    required this.backgroundRole,
    required this.foreground,
    required this.background,
    required this.level,
  });

  /// Name of the foreground role, for example `onAccent`.
  final String foregroundRole;

  /// Name of the background role, for example `accent`.
  final String backgroundRole;

  /// The resolved foreground color.
  final Color foreground;

  /// The resolved background color.
  final Color background;

  /// The WCAG level this pair is held to.
  final HiveContrastLevel level;

  /// The WCAG 2.x contrast ratio between [foreground] and [background].
  double get ratio => HiveContrast.ratio(foreground, background);

  /// Whether [ratio] meets [level].
  bool get passes => ratio >= level.minimumRatio;
}

/// WCAG 2.x contrast math on composed (opaque) colors.
abstract final class HiveContrast {
  /// The contrast ratio between [a] and [b], from 1 to 21.
  ///
  /// Translucent colors must be composed over their real background first
  /// (for example with [Color.alphaBlend]) before calling this.
  static double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }
}

/// Semantic color roles of the Agentic Hive design system.
///
/// Features read these through `context.hiveColors` and never use literal
/// colors. Hex values are the starting palette pending owner approval in
/// Widgetbook; the role names are fixed.
@immutable
class HiveColors extends ThemeExtension<HiveColors> {
  /// Creates a palette. Prefer [HiveColors.dark] or [HiveColors.light].
  const new({
    required this.brightness,
    required this.background,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.borderSubtle,
    required this.borderStrong,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.accent,
    required this.onAccent,
    required this.accentMuted,
    required this.onAccentMuted,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.info,
    required this.onInfo,
    required this.statusIdle,
    required this.statusRunning,
    required this.statusPaused,
    required this.statusFailed,
    required this.statusSucceeded,
    required this.chart,
    required this.focusRing,
    required this.hoverOpacity,
    required this.pressedOpacity,
    required this.disabledOpacity,
    required this.scrimOpacity,
  });

  /// Dark palette (the default theme).
  static const HiveColors dark = HiveColors(
    brightness: Brightness.dark,
    background: Color(0xFF050706),
    surface1: Color(0xFF0E1210),
    surface2: Color(0xFF161B18),
    surface3: Color(0xFF1F2622),
    borderSubtle: Color(0xFF26302A),
    borderStrong: Color(0xFF66726B),
    onSurface: Color(0xFFE9EEEA),
    onSurfaceMuted: Color(0xFF9AA59E),
    accent: Color(0xFFC6EF4E),
    onAccent: Color(0xFF0B0F0C),
    accentMuted: Color(0xFF5DBB63),
    onAccentMuted: Color(0xFF06100A),
    success: Color(0xFF4FB878),
    onSuccess: Color(0xFF04120A),
    warning: Color(0xFFE2B04A),
    onWarning: Color(0xFF1A1204),
    danger: Color(0xFFE86A5E),
    onDanger: Color(0xFF1C0604),
    info: Color(0xFF72A9C4),
    onInfo: Color(0xFF04121A),
    statusIdle: Color(0xFF7F8A84),
    statusRunning: Color(0xFF8FD16A),
    statusPaused: Color(0xFFE2B04A),
    statusFailed: Color(0xFFE86A5E),
    statusSucceeded: Color(0xFF4FB878),
    chart: <Color>[
      Color(0xFFC6EF4E),
      Color(0xFF8FD16A),
      Color(0xFF5DBB63),
      Color(0xFF3E9F5A),
      Color(0xFF2E8A5E),
      Color(0xFF72A9C4),
      Color(0xFFD8C27A),
    ],
    focusRing: Color(0xFFE9EEEA),
    hoverOpacity: 0.08,
    pressedOpacity: 0.14,
    disabledOpacity: 0.38,
    scrimOpacity: 0.72,
  );

  /// Light palette.
  static const HiveColors light = HiveColors(
    brightness: Brightness.light,
    background: Color(0xFFF6F7F7),
    surface1: Color(0xFFEAECDF),
    surface2: Color(0xFFE0E3D4),
    surface3: Color(0xFFD5D9C7),
    borderSubtle: Color(0xFFCBD0BC),
    borderStrong: Color(0xFF6F7B6B),
    onSurface: Color(0xFF0B0F0C),
    onSurfaceMuted: Color(0xFF4A544D),
    accent: Color(0xFFC6EF4E),
    onAccent: Color(0xFF0B0F0C),
    accentMuted: Color(0xFF2F7D3F),
    onAccentMuted: Color(0xFFFFFFFF),
    success: Color(0xFF2E7D4F),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFF8A5D00),
    onWarning: Color(0xFFFFFFFF),
    danger: Color(0xFFB3362B),
    onDanger: Color(0xFFFFFFFF),
    info: Color(0xFF2C6A88),
    onInfo: Color(0xFFFFFFFF),
    statusIdle: Color(0xFF5E6862),
    statusRunning: Color(0xFF337826),
    statusPaused: Color(0xFF8A5D00),
    statusFailed: Color(0xFFB3362B),
    statusSucceeded: Color(0xFF2E7D4F),
    chart: <Color>[
      Color(0xFF4C7509),
      Color(0xFF337826),
      Color(0xFF2F7D3F),
      Color(0xFF1F6B47),
      Color(0xFF195A47),
      Color(0xFF2C6A88),
      Color(0xFF8A6D1F),
    ],
    focusRing: Color(0xFF0B0F0C),
    hoverOpacity: 0.08,
    pressedOpacity: 0.14,
    disabledOpacity: 0.38,
    scrimOpacity: 0.48,
  );

  /// Whether this palette is the light or the dark one.
  final Brightness brightness;

  /// App background (near black in dark).
  final Color background;

  /// First surface step (cards, the side rail).
  final Color surface1;

  /// Second surface step (raised elements inside cards).
  final Color surface2;

  /// Third surface step (inputs, secondary buttons, hover wells).
  final Color surface3;

  /// 1px hairline border between surfaces. Decorative; not a text color.
  final Color borderSubtle;

  /// 1px border for non-text UI boundaries that must reach 3:1 on every
  /// surface; [borderSubtle] stays the decorative hairline.
  final Color borderStrong;

  /// Primary text and icon color on [background] and every surface.
  final Color onSurface;

  /// Secondary text and icon color on [background] and every surface.
  final Color onSurfaceMuted;

  /// Lime accent: the primary action and the active item only.
  final Color accent;

  /// Foreground on [accent].
  final Color onAccent;

  /// Secondary green for charts, success and running.
  final Color accentMuted;

  /// Foreground on [accentMuted].
  final Color onAccentMuted;

  /// Desaturated success.
  final Color success;

  /// Foreground on [success].
  final Color onSuccess;

  /// Desaturated warning.
  final Color warning;

  /// Foreground on [warning].
  final Color onWarning;

  /// Desaturated danger.
  final Color danger;

  /// Foreground on [danger].
  final Color onDanger;

  /// Desaturated info.
  final Color info;

  /// Foreground on [info].
  final Color onInfo;

  /// Node status: idle.
  final Color statusIdle;

  /// Node status: running.
  final Color statusRunning;

  /// Node status: paused.
  final Color statusPaused;

  /// Node status: failed.
  final Color statusFailed;

  /// Node status: succeeded.
  final Color statusSucceeded;

  /// Categorical chart palette: lime to forest green, then two neutrals.
  final List<Color> chart;

  /// Keyboard focus indicator color.
  final Color focusRing;

  /// Opacity of the foreground state layer on hover.
  final double hoverOpacity;

  /// Opacity of the foreground state layer while pressed.
  final double pressedOpacity;

  /// Opacity applied to a whole disabled control.
  final double disabledOpacity;

  /// Opacity of the [background] scrim behind modal dialogs.
  final double scrimOpacity;

  /// Every surface a foreground role may sit on, by role name.
  Map<String, Color> get surfaces => <String, Color>{
    'background': background,
    'surface1': surface1,
    'surface2': surface2,
    'surface3': surface3,
  };

  /// Every foreground/background pair that must pass WCAG AA.
  ///
  /// Covers text on every surface, each `on*` pair, the inverse pair used by
  /// selected segments and filter chips, and the status roles, feedback
  /// tones (borders and icons of banners, toasts and input errors), focus
  /// ring and chart palette as UI components on every surface.
  List<HiveContrastPair> get contrastPairs {
    HiveContrastPair pair(
      String fgRole,
      Color fg,
      String bgRole,
      Color bg,
      HiveContrastLevel level,
    ) => HiveContrastPair(
      foregroundRole: fgRole,
      backgroundRole: bgRole,
      foreground: fg,
      background: bg,
      level: level,
    );

    final onSurfaces = <String, Color>{
      'onSurface': onSurface,
      'onSurfaceMuted': onSurfaceMuted,
    };
    final uiRoles = <String, Color>{
      'borderStrong': borderStrong,
      'statusIdle': statusIdle,
      'statusRunning': statusRunning,
      'statusPaused': statusPaused,
      'statusFailed': statusFailed,
      'statusSucceeded': statusSucceeded,
      'focusRing': focusRing,
      'success': success,
      'warning': warning,
      'danger': danger,
      'info': info,
      for (var i = 0; i < chart.length; i++) 'chart[$i]': chart[i],
    };
    return <HiveContrastPair>[
      for (final s in surfaces.entries)
        for (final f in onSurfaces.entries)
          pair(f.key, f.value, s.key, s.value, HiveContrastLevel.text),
      pair('onAccent', onAccent, 'accent', accent, HiveContrastLevel.text),
      pair(
        'onAccentMuted',
        onAccentMuted,
        'accentMuted',
        accentMuted,
        HiveContrastLevel.text,
      ),
      pair('onSuccess', onSuccess, 'success', success, HiveContrastLevel.text),
      pair('onWarning', onWarning, 'warning', warning, HiveContrastLevel.text),
      pair('onDanger', onDanger, 'danger', danger, HiveContrastLevel.text),
      pair('onInfo', onInfo, 'info', info, HiveContrastLevel.text),
      pair(
        'background',
        background,
        'onSurface',
        onSurface,
        HiveContrastLevel.text,
      ),
      for (final s in surfaces.entries)
        for (final u in uiRoles.entries)
          pair(u.key, u.value, s.key, s.value, HiveContrastLevel.ui),
    ];
  }

  @override
  HiveColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? borderSubtle,
    Color? borderStrong,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? accent,
    Color? onAccent,
    Color? accentMuted,
    Color? onAccentMuted,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
    Color? info,
    Color? onInfo,
    Color? statusIdle,
    Color? statusRunning,
    Color? statusPaused,
    Color? statusFailed,
    Color? statusSucceeded,
    List<Color>? chart,
    Color? focusRing,
    double? hoverOpacity,
    double? pressedOpacity,
    double? disabledOpacity,
    double? scrimOpacity,
  }) {
    return HiveColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentMuted: accentMuted ?? this.accentMuted,
      onAccentMuted: onAccentMuted ?? this.onAccentMuted,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      statusIdle: statusIdle ?? this.statusIdle,
      statusRunning: statusRunning ?? this.statusRunning,
      statusPaused: statusPaused ?? this.statusPaused,
      statusFailed: statusFailed ?? this.statusFailed,
      statusSucceeded: statusSucceeded ?? this.statusSucceeded,
      chart: chart ?? this.chart,
      focusRing: focusRing ?? this.focusRing,
      hoverOpacity: hoverOpacity ?? this.hoverOpacity,
      pressedOpacity: pressedOpacity ?? this.pressedOpacity,
      disabledOpacity: disabledOpacity ?? this.disabledOpacity,
      scrimOpacity: scrimOpacity ?? this.scrimOpacity,
    );
  }

  @override
  HiveColors lerp(covariant HiveColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => a + (b - a) * t;
    return HiveColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface1: c(surface1, other.surface1),
      surface2: c(surface2, other.surface2),
      surface3: c(surface3, other.surface3),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      borderStrong: c(borderStrong, other.borderStrong),
      onSurface: c(onSurface, other.onSurface),
      onSurfaceMuted: c(onSurfaceMuted, other.onSurfaceMuted),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentMuted: c(accentMuted, other.accentMuted),
      onAccentMuted: c(onAccentMuted, other.onAccentMuted),
      success: c(success, other.success),
      onSuccess: c(onSuccess, other.onSuccess),
      warning: c(warning, other.warning),
      onWarning: c(onWarning, other.onWarning),
      danger: c(danger, other.danger),
      onDanger: c(onDanger, other.onDanger),
      info: c(info, other.info),
      onInfo: c(onInfo, other.onInfo),
      statusIdle: c(statusIdle, other.statusIdle),
      statusRunning: c(statusRunning, other.statusRunning),
      statusPaused: c(statusPaused, other.statusPaused),
      statusFailed: c(statusFailed, other.statusFailed),
      statusSucceeded: c(statusSucceeded, other.statusSucceeded),
      chart: <Color>[
        for (var i = 0; i < chart.length && i < other.chart.length; i++)
          c(chart[i], other.chart[i]),
      ],
      focusRing: c(focusRing, other.focusRing),
      hoverOpacity: d(hoverOpacity, other.hoverOpacity),
      pressedOpacity: d(pressedOpacity, other.pressedOpacity),
      disabledOpacity: d(disabledOpacity, other.disabledOpacity),
      scrimOpacity: d(scrimOpacity, other.scrimOpacity),
    );
  }
}
