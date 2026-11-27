import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in <String, HiveColors>{
    'dark': HiveColors.dark,
    'light': HiveColors.light,
  }.entries) {
    final name = entry.key;
    final c = entry.value;

    group('run detail inspector contrast ($name)', () {
      test('inspector header title onSurface on surface2 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface2: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('following active badge onInfo on info meets AA', () {
        final ratio = HiveContrast.ratio(c.onInfo, c.info);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onInfo/info: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('transcript body onSurface on surface1 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface1);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface1: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('transcript thinking onSurfaceMuted on surface1 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurfaceMuted, c.surface1);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurfaceMuted/surface1: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('final result metric chip onSurface on surface3 meets AA', () {
        final ratio = HiveContrast.ratio(c.onSurface, c.surface3);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name onSurface/surface3: ${ratio.toStringAsFixed(2)}',
        );
      });

      test('warning and danger icons on surface2 meet 3:1 AA', () {
        final warningRatio = HiveContrast.ratio(c.warning, c.surface2);
        final dangerRatio = HiveContrast.ratio(c.danger, c.surface2);
        expect(
          warningRatio,
          greaterThanOrEqualTo(3.0),
          reason: '$name warning/surface2: ${warningRatio.toStringAsFixed(2)}',
        );
        expect(
          dangerRatio,
          greaterThanOrEqualTo(3.0),
          reason: '$name danger/surface2: ${dangerRatio.toStringAsFixed(2)}',
        );
      });
    });
  }
}
