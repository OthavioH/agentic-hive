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
      test('secondary button label on surface3 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface3);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface3: ${ratio.toStringAsFixed(2)}',
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

      test('select option label and icon on surface2 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface2: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('select chevron muted icon on surface3 meets non-text 3:1', () {
        final ratio = HiveContrast.ratio(c.onSurfaceMuted, c.surface3);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: '$name onSurfaceMuted/surface3: ${ratio.toStringAsFixed(2)}',
        );
      });
    });
  }
}
