import 'package:material_ui/material_ui.dart';

/// Elevation: surface steps plus 1px hairline borders, with at most two small
/// layered shadow tokens. No large diffuse shadows.
@immutable
class HiveElevation extends ThemeExtension<HiveElevation> {
  /// Creates the elevation tokens. Prefer [dark] or [light].
  const new({
    required this.hairline,
    required this.focusRingWidth,
    required this.shadowSmall,
    required this.shadowMedium,
  });

  /// Elevation for the dark theme.
  static const HiveElevation dark = HiveElevation(
    hairline: 1,
    focusRingWidth: 2,
    shadowSmall: <BoxShadow>[
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
    ],
    shadowMedium: <BoxShadow>[
      BoxShadow(color: Color(0x59000000), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x40000000), offset: Offset(0, 4), blurRadius: 8),
    ],
  );

  /// Elevation for the light theme.
  static const HiveElevation light = HiveElevation(
    hairline: 1,
    focusRingWidth: 2,
    shadowSmall: <BoxShadow>[
      BoxShadow(color: Color(0x1A0B0F0C), offset: Offset(0, 1), blurRadius: 2),
    ],
    shadowMedium: <BoxShadow>[
      BoxShadow(color: Color(0x140B0F0C), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x0F0B0F0C), offset: Offset(0, 4), blurRadius: 8),
    ],
  );

  /// Width of the `borderSubtle` hairline: 1.
  final double hairline;

  /// Width of the keyboard focus ring: 2.
  final double focusRingWidth;

  /// Small shadow for floating controls (one layer).
  final List<BoxShadow> shadowSmall;

  /// Medium shadow for the floating side rail and menus (two small layers).
  final List<BoxShadow> shadowMedium;

  @override
  HiveElevation copyWith({
    double? hairline,
    double? focusRingWidth,
    List<BoxShadow>? shadowSmall,
    List<BoxShadow>? shadowMedium,
  }) {
    return HiveElevation(
      hairline: hairline ?? this.hairline,
      focusRingWidth: focusRingWidth ?? this.focusRingWidth,
      shadowSmall: shadowSmall ?? this.shadowSmall,
      shadowMedium: shadowMedium ?? this.shadowMedium,
    );
  }

  @override
  HiveElevation lerp(covariant HiveElevation? other, double t) {
    if (other == null) return this;
    return HiveElevation(
      hairline: hairline + (other.hairline - hairline) * t,
      focusRingWidth:
          focusRingWidth + (other.focusRingWidth - focusRingWidth) * t,
      shadowSmall: BoxShadow.lerpList(shadowSmall, other.shadowSmall, t)!,
      shadowMedium: BoxShadow.lerpList(shadowMedium, other.shadowMedium, t)!,
    );
  }
}
