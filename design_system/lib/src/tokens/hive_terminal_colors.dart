import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// The terminal palette of `HiveTerminalView`: surface, text, cursor,
/// selection and the 16 ANSI colors, derived from a [HiveColors] palette.
///
/// The surface, text and the four tone hues come straight from
/// [HiveColors] roles (`background`, `onSurface`, `onSurfaceMuted`,
/// `danger`, `success`, `warning`, `info`). Magenta, cyan and the bright
/// variants have no app role, so they are defined here per brightness in
/// the same desaturated family; magenta is a dusty rose, never purple.
///
/// Every ANSI color a program uses as text reaches 4.5:1 on [background].
/// The ANSI colors that sit on the far side of the palette (`black` in the
/// dark theme, `white` and `brightWhite` in the light theme) are what
/// programs paint behind text (`SGR 40`, `SGR 47`), so they are held to
/// 4.5:1 with [foreground] on top instead. See [contrastPairs].
@immutable
class HiveTerminalColors {
  /// Creates a palette. Prefer [HiveTerminalColors.from].
  const new({
    required this.brightness,
    required this.background,
    required this.foreground,
    required this.cursor,
    required this.selection,
    required this.black,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.magenta,
    required this.cyan,
    required this.white,
    required this.brightBlack,
    required this.brightRed,
    required this.brightGreen,
    required this.brightYellow,
    required this.brightBlue,
    required this.brightMagenta,
    required this.brightCyan,
    required this.brightWhite,
    required this.searchHitBackground,
    required this.searchHitBackgroundCurrent,
    required this.searchHitForeground,
  });

  /// Derives the terminal palette from the app palette [colors].
  factory from(HiveColors colors) {
    return colors.brightness == Brightness.dark
        ? HiveTerminalColors(
            brightness: Brightness.dark,
            background: colors.background,
            foreground: colors.onSurface,
            cursor: colors.onSurface,
            selection: colors.onSurface.withValues(alpha: 0.24),
            black: colors.surface3,
            red: colors.danger,
            green: colors.success,
            yellow: colors.warning,
            blue: colors.info,
            magenta: const Color(0xFFD487B6),
            cyan: const Color(0xFF5DBFB8),
            white: const Color(0xFFC3CCC6),
            brightBlack: colors.onSurfaceMuted,
            brightRed: const Color(0xFFF2988F),
            brightGreen: colors.statusRunning,
            brightYellow: const Color(0xFFF0CF82),
            brightBlue: const Color(0xFFA0C8DD),
            brightMagenta: const Color(0xFFE7B0D2),
            brightCyan: const Color(0xFF92DDD6),
            brightWhite: const Color(0xFFF7FAF8),
            searchHitBackground: colors.warning.withValues(alpha: 0.32),
            searchHitBackgroundCurrent: colors.warning.withValues(alpha: 0.56),
            searchHitForeground: colors.onSurface,
          )
        : HiveTerminalColors(
            brightness: Brightness.light,
            background: colors.background,
            foreground: colors.onSurface,
            cursor: colors.onSurface,
            selection: colors.onSurface.withValues(alpha: 0.18),
            black: colors.onSurface,
            red: colors.danger,
            green: colors.success,
            yellow: colors.warning,
            blue: colors.info,
            magenta: const Color(0xFF94386F),
            cyan: const Color(0xFF1A6B68),
            white: colors.surface3,
            brightBlack: colors.onSurfaceMuted,
            brightRed: const Color(0xFF9A2A21),
            brightGreen: const Color(0xFF245F3C),
            brightYellow: const Color(0xFF6E4A00),
            brightBlue: const Color(0xFF1F5470),
            brightMagenta: const Color(0xFF782A59),
            brightCyan: const Color(0xFF12524F),
            brightWhite: colors.surface1,
            searchHitBackground: colors.warning.withValues(alpha: 0.24),
            searchHitBackgroundCurrent: colors.warning.withValues(alpha: 0.4),
            searchHitForeground: colors.onSurface,
          );
  }

  /// Dark terminal palette, derived from [HiveColors.dark].
  static final HiveTerminalColors dark = HiveTerminalColors.from(
    HiveColors.dark,
  );

  /// Light terminal palette, derived from [HiveColors.light].
  static final HiveTerminalColors light = HiveTerminalColors.from(
    HiveColors.light,
  );

  /// Whether this palette belongs to the light or the dark theme.
  final Brightness brightness;

  /// Terminal surface (the app `background`).
  final Color background;

  /// Default text (`onSurface`).
  final Color foreground;

  /// Cursor block or outline.
  final Color cursor;

  /// Translucent selection painted over the selected cells.
  final Color selection;

  /// ANSI 0, black.
  final Color black;

  /// ANSI 1, red (`danger`).
  final Color red;

  /// ANSI 2, green (`success`).
  final Color green;

  /// ANSI 3, yellow (`warning`).
  final Color yellow;

  /// ANSI 4, blue (`info`).
  final Color blue;

  /// ANSI 5, magenta (a dusty rose).
  final Color magenta;

  /// ANSI 6, cyan.
  final Color cyan;

  /// ANSI 7, white.
  final Color white;

  /// ANSI 8, bright black (`onSurfaceMuted`).
  final Color brightBlack;

  /// ANSI 9, bright red.
  final Color brightRed;

  /// ANSI 10, bright green.
  final Color brightGreen;

  /// ANSI 11, bright yellow.
  final Color brightYellow;

  /// ANSI 12, bright blue.
  final Color brightBlue;

  /// ANSI 13, bright magenta.
  final Color brightMagenta;

  /// ANSI 14, bright cyan.
  final Color brightCyan;

  /// ANSI 15, bright white.
  final Color brightWhite;

  /// Translucent background of a search hit.
  final Color searchHitBackground;

  /// Translucent background of the current search hit.
  final Color searchHitBackgroundCurrent;

  /// Text of a search hit.
  final Color searchHitForeground;

  /// The 16 ANSI colors by name, in ANSI order (0 to 15).
  Map<String, Color> get ansi => <String, Color>{
    'black': black,
    'red': red,
    'green': green,
    'yellow': yellow,
    'blue': blue,
    'magenta': magenta,
    'cyan': cyan,
    'white': white,
    'brightBlack': brightBlack,
    'brightRed': brightRed,
    'brightGreen': brightGreen,
    'brightYellow': brightYellow,
    'brightBlue': brightBlue,
    'brightMagenta': brightMagenta,
    'brightCyan': brightCyan,
    'brightWhite': brightWhite,
  };

  /// ANSI colors that programs paint behind text in this brightness: they
  /// are tested with [foreground] on top instead of as text.
  Set<String> get fillRoles => brightness == Brightness.dark
      ? const <String>{'black'}
      : const <String>{'white', 'brightWhite'};

  /// Every pair that must pass WCAG AA (4.5:1, normal text).
  ///
  /// Covers [foreground] and every ANSI text color on [background], and
  /// [foreground] on every ANSI fill color ([fillRoles]).
  List<HiveContrastPair> get contrastPairs {
    final fills = fillRoles;
    return <HiveContrastPair>[
      HiveContrastPair(
        foregroundRole: 'foreground',
        backgroundRole: 'background',
        foreground: foreground,
        background: background,
        level: HiveContrastLevel.text,
      ),
      for (final entry in ansi.entries)
        if (fills.contains(entry.key))
          HiveContrastPair(
            foregroundRole: 'foreground',
            backgroundRole: entry.key,
            foreground: foreground,
            background: entry.value,
            level: HiveContrastLevel.text,
          )
        else
          HiveContrastPair(
            foregroundRole: entry.key,
            backgroundRole: 'background',
            foreground: entry.value,
            background: background,
            level: HiveContrastLevel.text,
          ),
    ];
  }
}

/// Context accessor for the terminal palette.
extension HiveTerminalColorsContext on BuildContext {
  /// The terminal palette derived from the ambient `context.hiveColors`.
  HiveTerminalColors get hiveTerminalColors =>
      HiveTerminalColors.from(hiveColors);
}
