import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Color;

void main() {
  for (final entry in <String, HiveColors>{
    'dark': HiveColors.dark,
    'light': HiveColors.light,
  }.entries) {
    final colors = entry.value;
    group('HiveTitleBar caption contrast (${entry.key})', () {
      Color layer(Color base, Color foreground, double opacity) =>
          Color.alphaBlend(foreground.withValues(alpha: opacity), base);

      test('resting icon reads on the strip background', () {
        final ratio = HiveContrast.ratio(colors.onSurface, colors.background);
        expect(ratio, greaterThanOrEqualTo(HiveContrastLevel.ui.minimumRatio));
      });

      test('hovered and pressed ghost buttons keep the icon readable', () {
        for (final opacity in <double>[
          colors.hoverOpacity,
          colors.pressedOpacity,
        ]) {
          final fill = layer(colors.background, colors.onSurface, opacity);
          final ratio = HiveContrast.ratio(colors.onSurface, fill);
          expect(
            ratio,
            greaterThanOrEqualTo(HiveContrastLevel.ui.minimumRatio),
            reason: 'opacity $opacity gives ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('close on danger keeps AA text contrast on hover and pressed', () {
        final hover = HiveContrast.ratio(colors.onDanger, colors.danger);
        final pressed = HiveContrast.ratio(
          colors.onDanger,
          layer(colors.danger, colors.onDanger, colors.pressedOpacity),
        );
        expect(
          hover,
          greaterThanOrEqualTo(HiveContrastLevel.text.minimumRatio),
        );
        expect(
          pressed,
          greaterThanOrEqualTo(HiveContrastLevel.text.minimumRatio),
          reason: 'pressed is ${pressed.toStringAsFixed(2)}:1',
        );
      });

      test('focus ring is visible against the strip background', () {
        final ratio = HiveContrast.ratio(colors.focusRing, colors.background);
        expect(ratio, greaterThanOrEqualTo(HiveContrastLevel.ui.minimumRatio));
      });
    });
  }
}
