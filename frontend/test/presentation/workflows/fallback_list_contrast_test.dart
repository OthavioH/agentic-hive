import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in <String, HiveColors>{
    'dark': HiveColors.dark,
    'light': HiveColors.light,
  }.entries) {
    final name = entry.key;
    final c = entry.value;

    group('fallback list contrast ($name)', () {
      test('row card onSurface on surface2 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface2: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('warning badge onWarning on warning meets AA', () {
        final ratio = HiveContrast.ratio(c.onWarning, c.warning);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onWarning/warning: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('add button onSurface on surface3 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface3);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface3: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('error text danger on surface2 meets AA', () {
        final ratio = HiveContrast.ratio(c.danger, c.surface2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name danger/surface2: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('compact empty message onSurfaceMuted on surface2 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurfaceMuted, c.surface2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurfaceMuted/surface2: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('non-text borderStrong on surface2 meets 3:1', () {
        final ratio = HiveContrast.ratio(c.borderStrong, c.surface2);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: '$name borderStrong/surface2: ${ratio.toStringAsFixed(2)}',
        );
      });
    });
  }
}
