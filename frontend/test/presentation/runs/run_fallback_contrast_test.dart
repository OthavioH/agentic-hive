import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in <String, HiveColors>{
    'dark': HiveColors.dark,
    'light': HiveColors.light,
  }.entries) {
    final name = entry.key;
    final c = entry.value;

    group('run fallback contrast ($name)', () {
      test('ran-on chip onSurface on surface3 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface3);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface3: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('event summary onSurface on surface1 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface1);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface1: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('node.fallback warning badge onWarning on warning meets AA', () {
        final ratio = HiveContrast.ratio(c.onWarning, c.warning);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onWarning/warning: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('events column header onSurface on surface2 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface2: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('events row metadata onSurfaceMuted on surface1 meets AA', () {
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
