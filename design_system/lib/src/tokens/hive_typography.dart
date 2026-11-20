import 'package:material_ui/material_ui.dart';

/// Font families bundled in this package (all SIL OFL 1.1).
abstract final class HiveFontFamilies {
  /// The package that declares the font families.
  static const String package = 'design_system';

  /// Display and large numbers.
  static const String display = 'BricolageGrotesque';

  /// UI text: titles, body and labels.
  static const String ui = 'Geist';

  /// Logs and harness output.
  static const String mono = 'GeistMono';
}

/// Typography roles. Sizes and line heights follow the 4/8 rhythm.
///
/// Styles carry no color; components and `DefaultTextStyle` apply the color
/// role. Every family is a bundled variable font, so each style sets both
/// [TextStyle.fontWeight] and the matching `wght` [FontVariation].
@immutable
class HiveTypography extends ThemeExtension<HiveTypography> {
  /// Creates the roles. Prefer [HiveTypography.standard].
  const new({
    required this.number,
    required this.display,
    required this.title,
    required this.titleSmall,
    required this.body,
    required this.bodySmall,
    required this.labelLarge,
    required this.label,
    required this.mono,
  });

  /// The standard type scale.
  static final HiveTypography standard = HiveTypography(
    number: _style(HiveFontFamilies.display, 48, 56, 600, tabular: true),
    display: _style(HiveFontFamilies.display, 32, 40, 600),
    title: _style(HiveFontFamilies.ui, 24, 32, 600),
    titleSmall: _style(HiveFontFamilies.ui, 20, 28, 600),
    body: _style(HiveFontFamilies.ui, 16, 24, 400),
    bodySmall: _style(HiveFontFamilies.ui, 12, 16, 400),
    labelLarge: _style(HiveFontFamilies.ui, 16, 24, 500),
    label: _style(HiveFontFamilies.ui, 12, 16, 500),
    mono: _style(HiveFontFamilies.mono, 12, 20, 400, tabular: true),
  );

  static TextStyle _style(
    String family,
    double size,
    double lineHeight,
    int weight, {
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: family,
      package: HiveFontFamilies.package,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: FontWeight.values.firstWhere(
        (w) => w.value == weight,
        orElse: () => FontWeight.w400,
      ),
      fontVariations: <FontVariation>[FontVariation.weight(weight.toDouble())],
      fontFeatures: tabular
          ? const <FontFeature>[FontFeature.tabularFigures()]
          : null,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// Large display numbers (metrics): Bricolage Grotesque 48/56.
  final TextStyle number;

  /// Display headings: Bricolage Grotesque 32/40.
  final TextStyle display;

  /// Page titles: Geist 24/32.
  final TextStyle title;

  /// Section and card titles: Geist 20/28.
  final TextStyle titleSmall;

  /// Body text: Geist 16/24.
  final TextStyle body;

  /// Secondary and dense body text: Geist 12/16.
  final TextStyle bodySmall;

  /// Button and rail labels: Geist Medium 16/24.
  final TextStyle labelLarge;

  /// Badges and small labels: Geist Medium 12/16.
  final TextStyle label;

  /// Logs and harness output: Geist Mono 12/20.
  final TextStyle mono;

  /// Every role by token name, largest first.
  Map<String, TextStyle> get roles => <String, TextStyle>{
    'number': number,
    'display': display,
    'title': title,
    'titleSmall': titleSmall,
    'body': body,
    'bodySmall': bodySmall,
    'labelLarge': labelLarge,
    'label': label,
    'mono': mono,
  };

  @override
  HiveTypography copyWith({
    TextStyle? number,
    TextStyle? display,
    TextStyle? title,
    TextStyle? titleSmall,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? label,
    TextStyle? mono,
  }) {
    return HiveTypography(
      number: number ?? this.number,
      display: display ?? this.display,
      title: title ?? this.title,
      titleSmall: titleSmall ?? this.titleSmall,
      body: body ?? this.body,
      bodySmall: bodySmall ?? this.bodySmall,
      labelLarge: labelLarge ?? this.labelLarge,
      label: label ?? this.label,
      mono: mono ?? this.mono,
    );
  }

  @override
  HiveTypography lerp(covariant HiveTypography? other, double t) {
    if (other == null) return this;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return HiveTypography(
      number: s(number, other.number),
      display: s(display, other.display),
      title: s(title, other.title),
      titleSmall: s(titleSmall, other.titleSmall),
      body: s(body, other.body),
      bodySmall: s(bodySmall, other.bodySmall),
      labelLarge: s(labelLarge, other.labelLarge),
      label: s(label, other.label),
      mono: s(mono, other.mono),
    );
  }
}
