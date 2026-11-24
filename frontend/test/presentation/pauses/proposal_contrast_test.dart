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

    group('approval pause proposal contrast ($name)', () {
      test('P1 title, instructions and proposal heading on card surface2', () {
        checkRatio(
          reportRows,
          name,
          'P1',
          'onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
      });

      test('P2 waiting label on card surface2', () {
        checkRatio(
          reportRows,
          name,
          'P2',
          'onSurfaceMuted / surface2',
          c.onSurfaceMuted,
          c.surface2,
          HiveContrastLevel.text,
        );
      });

      test('P3 code block text on surface1', () {
        checkRatio(
          reportRows,
          name,
          'P3',
          'onSurface / surface1',
          c.onSurface,
          c.surface1,
          HiveContrastLevel.text,
        );
      });

      test('P4 code block hairline borderSubtle on surface2 (report only)', () {
        checkRatio(
          reportRows,
          name,
          'P4',
          'borderSubtle / surface2',
          c.borderSubtle,
          c.surface2,
          HiveContrastLevel.ui,
          reportOnly: true,
        );
      });

      test('P5 editor typed text on well surface3 rest and hovered', () {
        final hoverBg = layer(c, c.surface3, c.onSurface, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'P5',
          'onSurface / surface3 rest',
          c.onSurface,
          c.surface3,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'P5',
          'onSurface / surface3 hovered',
          c.onSurface,
          hoverBg,
          HiveContrastLevel.text,
        );
      });

      test('P6 editor hint and label on well surface3', () {
        checkRatio(
          reportRows,
          name,
          'P6',
          'onSurfaceMuted / surface3',
          c.onSurfaceMuted,
          c.surface3,
          HiveContrastLevel.text,
        );
      });

      test('P7 field error line text danger on card surface2', () {
        checkRatio(
          reportRows,
          name,
          'P7',
          'danger / surface2',
          c.danger,
          c.surface2,
          HiveContrastLevel.text,
        );
      });

      test('P8 error hairline danger on well surface3', () {
        checkRatio(
          reportRows,
          name,
          'P8',
          'danger / surface3',
          c.danger,
          c.surface3,
          HiveContrastLevel.ui,
        );
      });

      test('P9 focus ring on card surface2 and well surface3', () {
        checkRatio(
          reportRows,
          name,
          'P9',
          'focusRing / surface2',
          c.focusRing,
          c.surface2,
          HiveContrastLevel.ui,
        );
        checkRatio(
          reportRows,
          name,
          'P9',
          'focusRing / surface3',
          c.focusRing,
          c.surface3,
          HiveContrastLevel.ui,
        );
      });

      test('P10 copy icon button glyph on surface1 rest and hovered', () {
        final fg = HiveButtonVariant.ghost.foreground(c);
        final restBg = over(HiveButtonVariant.ghost.background(c), c.surface1);
        final hoverBg = layer(c, restBg, fg, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'P10',
          'copy icon rest',
          fg,
          restBg,
          HiveContrastLevel.ui,
        );
        checkRatio(
          reportRows,
          name,
          'P10',
          'copy icon hovered',
          fg,
          hoverBg,
          HiveContrastLevel.ui,
        );
      });

      test('P11 primary Approve button rest, hovered, disabled', () {
        final fg = HiveButtonVariant.primary.foreground(c);
        final restBg = HiveButtonVariant.primary.background(c);
        final hoverBg = layer(c, restBg, fg, const <WidgetState>{
          WidgetState.hovered,
        });
        final disabledBg = over(
          restBg.withValues(alpha: c.disabledOpacity),
          c.surface2,
        );
        final disabledFg = over(
          fg.withValues(alpha: c.disabledOpacity),
          disabledBg,
        );
        checkRatio(
          reportRows,
          name,
          'P11',
          'primary rest',
          fg,
          restBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'P11',
          'primary hovered',
          fg,
          hoverBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'P11',
          'primary disabled',
          disabledFg,
          disabledBg,
          HiveContrastLevel.text,
          reportOnly: true,
        );
      });

      test('P12 secondary Reject/Edit button rest, hovered, disabled', () {
        final fg = HiveButtonVariant.secondary.foreground(c);
        final restBg = HiveButtonVariant.secondary.background(c);
        final hoverBg = layer(c, restBg, fg, const <WidgetState>{
          WidgetState.hovered,
        });
        final disabledBg = over(
          restBg.withValues(alpha: c.disabledOpacity),
          c.surface2,
        );
        final disabledFg = over(
          fg.withValues(alpha: c.disabledOpacity),
          disabledBg,
        );
        checkRatio(
          reportRows,
          name,
          'P12',
          'secondary rest',
          fg,
          restBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'P12',
          'secondary hovered',
          fg,
          hoverBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'P12',
          'secondary disabled',
          disabledFg,
          disabledBg,
          HiveContrastLevel.text,
          reportOnly: true,
        );
      });

      test('P13 ghost Discard button rest, hovered, disabled', () {
        final fg = HiveButtonVariant.ghost.foreground(c);
        final restBg = over(HiveButtonVariant.ghost.background(c), c.surface2);
        final hoverBg = layer(c, restBg, fg, const <WidgetState>{
          WidgetState.hovered,
        });
        final disabledFg = over(
          fg.withValues(alpha: c.disabledOpacity),
          c.surface2,
        );
        checkRatio(
          reportRows,
          name,
          'P13',
          'ghost rest',
          fg,
          restBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'P13',
          'ghost hovered',
          fg,
          hoverBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'P13',
          'ghost disabled',
          disabledFg,
          c.surface2,
          HiveContrastLevel.text,
          reportOnly: true,
        );
      });
    });
  }

  tearDownAll(() {
    reportRows.forEach(debugPrint);
  });
}
