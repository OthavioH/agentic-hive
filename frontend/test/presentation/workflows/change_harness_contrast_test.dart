import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in <String, HiveColors>{
    'dark': HiveColors.dark,
    'light': HiveColors.light,
  }.entries) {
    final name = entry.key;
    final c = entry.value;

    group('change harness contrast ($name)', () {
      test('secondary button label on surface1 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface1);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface1: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('dialog muted message on surface1 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurfaceMuted, c.surface1);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurfaceMuted/surface1: ${ratio.toStringAsFixed(2)}',
        );
      });
    });
  }
}
