import 'package:material_ui/material_ui.dart';

/// The 8-point spacing scale.
///
/// [spaceHalf] is only for tight inner gaps inside small controls, such as
/// icon to text inside a badge. No other spacing values exist.
@immutable
class HiveSpacing extends ThemeExtension<HiveSpacing> {
  /// Creates the scale. Prefer [HiveSpacing.standard].
  const new({
    required this.spaceHalf,
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space5,
    required this.space6,
    required this.space8,
  });

  /// The standard scale: 4, 8, 16, 24, 32, 40, 48, 64.
  static const HiveSpacing standard = HiveSpacing(
    spaceHalf: 4,
    space1: 8,
    space2: 16,
    space3: 24,
    space4: 32,
    space5: 40,
    space6: 48,
    space8: 64,
  );

  /// 4: tight inner gaps inside small controls only.
  final double spaceHalf;

  /// 8.
  final double space1;

  /// 16.
  final double space2;

  /// 24.
  final double space3;

  /// 32.
  final double space4;

  /// 40.
  final double space5;

  /// 48.
  final double space6;

  /// 64.
  final double space8;

  /// Every step by token name, smallest first.
  Map<String, double> get steps => <String, double>{
    'spaceHalf': spaceHalf,
    'space1': space1,
    'space2': space2,
    'space3': space3,
    'space4': space4,
    'space5': space5,
    'space6': space6,
    'space8': space8,
  };

  @override
  HiveSpacing copyWith({
    double? spaceHalf,
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? space5,
    double? space6,
    double? space8,
  }) {
    return HiveSpacing(
      spaceHalf: spaceHalf ?? this.spaceHalf,
      space1: space1 ?? this.space1,
      space2: space2 ?? this.space2,
      space3: space3 ?? this.space3,
      space4: space4 ?? this.space4,
      space5: space5 ?? this.space5,
      space6: space6 ?? this.space6,
      space8: space8 ?? this.space8,
    );
  }

  @override
  HiveSpacing lerp(covariant HiveSpacing? other, double t) {
    if (other == null) return this;
    double d(double a, double b) => a + (b - a) * t;
    return HiveSpacing(
      spaceHalf: d(spaceHalf, other.spaceHalf),
      space1: d(space1, other.space1),
      space2: d(space2, other.space2),
      space3: d(space3, other.space3),
      space4: d(space4, other.space4),
      space5: d(space5, other.space5),
      space6: d(space6, other.space6),
      space8: d(space8, other.space8),
    );
  }
}
