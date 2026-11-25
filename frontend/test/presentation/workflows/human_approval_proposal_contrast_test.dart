import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Color layer(HiveColors c, Color base, Color fg, Set<WidgetState> states) =>
      hiveStateLayer(base: base, foreground: fg, states: states, colors: c);

  void checkRatio(
    List<String> rows,
    String themeName,
    String id,
    String label,
    Color fg,
    Color bg,
    HiveContrastLevel level, {
    bool reportOnly = false,
  }) {
    final ratio = HiveContrast.ratio(fg, bg);
    final min = level == HiveContrastLevel.text ? 4.5 : 3.0;
    final pass = ratio >= min;
    rows.add(
      '| $themeName | $id | $label | ${ratio.toStringAsFixed(2)}:1 '
      '| ${min.toStringAsFixed(1)}:1 | '
      '${reportOnly ? 'report-only' : (pass ? 'PASS' : 'FAIL')} |',
    );
    if (!reportOnly) {
      expect(
        ratio,
        greaterThanOrEqualTo(min),
        reason: '$themeName $id ($label): ${ratio.toStringAsFixed(2)} < $min',
      );
    }
  }

  final reportRows = <String>[];

  for (final entry in <String, HiveColors>{
    'dark': HiveColors.dark,
    'light': HiveColors.light,
  }.entries) {
    final name = entry.key;
    final c = entry.value;

    // Select option rows (onSurface / surface2 rest, hovered, focused) are
    // already covered by 128-S test M10 in harness_model_effort_contrast_test.
    group('approval node config proposal contrast ($name)', () {
      test('C1 group heading onSurface on panel surface1', () {
        checkRatio(
          reportRows,
          name,
          'C1',
          'onSurface / surface1',
          c.onSurface,
          c.surface1,
          HiveContrastLevel.text,
        );
      });

      test('C2 schema typed text onSurface on well surface3 rest and '
          'hovered', () {
        final hoverBg = layer(c, c.surface3, c.onSurface, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'C2',
          'onSurface / surface3 rest',
          c.onSurface,
          c.surface3,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C2',
          'onSurface / surface3 hovered',
          c.onSurface,
          hoverBg,
          HiveContrastLevel.text,
        );
      });

      test('C3 schema and path hints onSurfaceMuted on well surface3', () {
        final hoverBg = layer(c, c.surface3, c.onSurface, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'C3',
          'onSurfaceMuted / surface3 rest',
          c.onSurfaceMuted,
          c.surface3,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C3',
          'onSurfaceMuted / surface3 hovered',
          c.onSurfaceMuted,
          hoverBg,
          HiveContrastLevel.text,
        );
      });

      test('C4 error line danger on panel surface1', () {
        checkRatio(
          reportRows,
          name,
          'C4',
          'danger / surface1',
          c.danger,
          c.surface1,
          HiveContrastLevel.text,
        );
      });
    });
  }

  tearDownAll(() {
    reportRows.forEach(debugPrint);
  });
}
