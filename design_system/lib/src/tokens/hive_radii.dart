import 'package:material_ui/material_ui.dart';

/// Corner radius by role. Two components with the same role share one radius.
@immutable
class HiveRadii extends ThemeExtension<HiveRadii> {
  /// Creates the radii. Prefer [HiveRadii.standard].
  const new({
    required this.radiusPill,
    required this.radiusCard,
    required this.radiusPanel,
  });

  /// Pill 999 (full), card 24, panel 32.
  static const HiveRadii standard = HiveRadii(
    radiusPill: 999,
    radiusCard: 24,
    radiusPanel: 32,
  );

  /// Full pill or circle: buttons, inputs, chips, badges, nav items, avatars.
  final double radiusPill;

  /// Cards.
  final double radiusCard;

  /// Large containers, dialogs and the side rail.
  final double radiusPanel;

  /// [radiusPill] as a [BorderRadius].
  BorderRadius get pill => BorderRadius.circular(radiusPill);

  /// [radiusCard] as a [BorderRadius].
  BorderRadius get card => BorderRadius.circular(radiusCard);

  /// [radiusPanel] as a [BorderRadius].
  BorderRadius get panel => BorderRadius.circular(radiusPanel);

  /// Every role by token name.
  Map<String, double> get roles => <String, double>{
    'radiusPill': radiusPill,
    'radiusCard': radiusCard,
    'radiusPanel': radiusPanel,
  };

  @override
  HiveRadii copyWith({
    double? radiusPill,
    double? radiusCard,
    double? radiusPanel,
  }) {
    return HiveRadii(
      radiusPill: radiusPill ?? this.radiusPill,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusPanel: radiusPanel ?? this.radiusPanel,
    );
  }

  @override
  HiveRadii lerp(covariant HiveRadii? other, double t) {
    if (other == null) return this;
    double d(double a, double b) => a + (b - a) * t;
    return HiveRadii(
      radiusPill: d(radiusPill, other.radiusPill),
      radiusCard: d(radiusCard, other.radiusCard),
      radiusPanel: d(radiusPanel, other.radiusPanel),
    );
  }
}
