import 'dart:ui' as ui show Color;

import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Color over(Color top, Color base) => ui.Color.alphaBlend(top, base);

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

    group('model and effort contrast ($name)', () {
      test('M1 field label onSurface on panel surface1', () {
        checkRatio(
          reportRows,
          name,
          'M1',
          'onSurface / surface1',
          c.onSurface,
          c.surface1,
          HiveContrastLevel.text,
        );
      });

      test('M2 typed value onSurface on well surface3 rest', () {
        checkRatio(
          reportRows,
          name,
          'M2',
          'onSurface / surface3 rest',
          c.onSurface,
          c.surface3,
          HiveContrastLevel.text,
        );
      });

      test('M3 typed value onSurface on well surface3 hovered', () {
        final hoverBg = layer(c, c.surface3, c.onSurface, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'M3',
          'onSurface / surface3 hovered',
          c.onSurface,
          hoverBg,
          HiveContrastLevel.text,
        );
      });

      test(
        'M4 hint and select placeholder onSurfaceMuted on well surface3 rest',
        () {
          checkRatio(
            reportRows,
            name,
            'M4',
            'onSurfaceMuted / surface3 rest',
            c.onSurfaceMuted,
            c.surface3,
            HiveContrastLevel.text,
          );
        },
      );

      test('M5 hint onSurfaceMuted on well surface3 hovered', () {
        final hoverBg = layer(c, c.surface3, c.onSurface, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'M5',
          'onSurfaceMuted / surface3 hovered',
          c.onSurfaceMuted,
          hoverBg,
          HiveContrastLevel.text,
        );
      });

      test('M6 error line text danger on panel surface1', () {
        checkRatio(
          reportRows,
          name,
          'M6',
          'danger / surface1',
          c.danger,
          c.surface1,
          HiveContrastLevel.text,
        );
      });

      test('M7 error hairline danger on well surface3', () {
        checkRatio(
          reportRows,
          name,
          'M7',
          'danger / surface3',
          c.danger,
          c.surface3,
          HiveContrastLevel.ui,
        );
      });

      test('M8 focus ring focusRing on panel surface1', () {
        checkRatio(
          reportRows,
          name,
          'M8',
          'focusRing / surface1',
          c.focusRing,
          c.surface1,
          HiveContrastLevel.ui,
        );
      });

      test(
        'M9 well hairline borderSubtle on surface3 and surface1 (report only)',
        () {
          checkRatio(
            reportRows,
            name,
            'M9',
            'borderSubtle / surface3',
            c.borderSubtle,
            c.surface3,
            HiveContrastLevel.ui,
            reportOnly: true,
          );
          checkRatio(
            reportRows,
            name,
            'M9',
            'borderSubtle / surface1',
            c.borderSubtle,
            c.surface1,
            HiveContrastLevel.ui,
            reportOnly: true,
          );
        },
      );

      test('M10 select menu item onSurface on menu surface2 rest, hovered, '
          'focused', () {
        final hoverBg = layer(c, c.surface2, c.onSurface, const <WidgetState>{
          WidgetState.hovered,
        });
        final focusBg = layer(c, c.surface2, c.onSurface, const <WidgetState>{
          WidgetState.focused,
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'M10',
          'menu item rest',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'M10',
          'menu item hovered',
          c.onSurface,
          hoverBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'M10',
          'menu item focused',
          c.onSurface,
          focusBg,
          HiveContrastLevel.text,
        );
      });

      test('M11 select chevron onSurfaceMuted on well surface3', () {
        checkRatio(
          reportRows,
          name,
          'M11',
          'onSurfaceMuted / surface3',
          c.onSurfaceMuted,
          c.surface3,
          HiveContrastLevel.ui,
        );
      });

      test('M12 disabled well onSurface at disabledOpacity over surface3 '
          '(report only)', () {
        final disabledFg = over(
          c.onSurface.withValues(alpha: c.disabledOpacity),
          c.surface3,
        );
        checkRatio(
          reportRows,
          name,
          'M12',
          'disabled onSurface / surface3',
          disabledFg,
          c.surface3,
          HiveContrastLevel.ui,
          reportOnly: true,
        );
      });
    });
  }

  tearDownAll(() {
    reportRows.forEach(debugPrint);
  });
}
