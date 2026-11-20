import 'package:material_ui/material_ui.dart';

/// Motion duration and curve tokens.
///
/// Every motion widget must respect `MediaQuery.disableAnimations`; use
/// [resolve] to get a zero duration when animations are disabled.
@immutable
class HiveMotionTokens extends ThemeExtension<HiveMotionTokens> {
  /// Creates the tokens. Prefer [HiveMotionTokens.standard].
  const new({
    required this.short,
    required this.medium,
    required this.long,
    required this.standardCurve,
    required this.emphasizedCurve,
    required this.exitCurve,
  });

  /// Short 120 ms, medium 240 ms, long 400 ms.
  static const HiveMotionTokens standard = HiveMotionTokens(
    short: Duration(milliseconds: 120),
    medium: Duration(milliseconds: 240),
    long: Duration(milliseconds: 400),
    standardCurve: Cubic(0.2, 0, 0, 1),
    emphasizedCurve: Cubic(0.05, 0.7, 0.1, 1),
    exitCurve: Cubic(0.3, 0, 1, 1),
  );

  /// State changes: hover, press, focus.
  final Duration short;

  /// Component transitions: rail expand, fades.
  final Duration medium;

  /// Page transitions and large entrances.
  final Duration long;

  /// Default curve for most motion.
  final Curve standardCurve;

  /// Entrances that deserve attention.
  final Curve emphasizedCurve;

  /// Elements leaving the screen.
  final Curve exitCurve;

  /// [duration], or [Duration.zero] when the platform asks for no animation.
  Duration resolve(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }

  /// Every duration by token name.
  Map<String, Duration> get durations => <String, Duration>{
    'short': short,
    'medium': medium,
    'long': long,
  };

  /// Every curve by token name.
  Map<String, Curve> get curves => <String, Curve>{
    'standard': standardCurve,
    'emphasized': emphasizedCurve,
    'exit': exitCurve,
  };

  @override
  HiveMotionTokens copyWith({
    Duration? short,
    Duration? medium,
    Duration? long,
    Curve? standardCurve,
    Curve? emphasizedCurve,
    Curve? exitCurve,
  }) {
    return HiveMotionTokens(
      short: short ?? this.short,
      medium: medium ?? this.medium,
      long: long ?? this.long,
      standardCurve: standardCurve ?? this.standardCurve,
      emphasizedCurve: emphasizedCurve ?? this.emphasizedCurve,
      exitCurve: exitCurve ?? this.exitCurve,
    );
  }

  @override
  HiveMotionTokens lerp(covariant HiveMotionTokens? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}
