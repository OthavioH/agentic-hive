import 'package:flutter/foundation.dart';

/// Persisted splitter fractions for the Run Detail work area.
@immutable
final class RunDetailSplitterPreference {
  /// Creates a [RunDetailSplitterPreference].
  const new({
    this.sideBySide = defaultFraction,
    this.stacked = defaultFraction,
  });

  /// Default fraction of available extent given to the graph pane.
  static const double defaultFraction = 0.45;

  /// Fraction (`0..1`) used when graph and inspector are side by side.
  final double sideBySide;

  /// Fraction (`0..1`) used when graph and inspector are stacked vertically.
  final double stacked;

  /// Returns a copy with updated fractions.
  RunDetailSplitterPreference copyWith({double? sideBySide, double? stacked}) {
    return RunDetailSplitterPreference(
      sideBySide: sideBySide ?? this.sideBySide,
      stacked: stacked ?? this.stacked,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RunDetailSplitterPreference &&
        other.sideBySide == sideBySide &&
        other.stacked == stacked;
  }

  @override
  int get hashCode => Object.hash(sideBySide, stacked);
}
