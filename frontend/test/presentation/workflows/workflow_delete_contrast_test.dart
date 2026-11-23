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

    group('delete flow contrast ($name)', () {
      test('C1 dialogs title and message on surface1', () {
        checkRatio(
          reportRows,
          name,
          'C1',
          'onSurface / surface1',
          c.onSurface,
          c.surface1,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C1',
          'onSurfaceMuted / surface1',
          c.onSurfaceMuted,
          c.surface1,
          HiveContrastLevel.text,
        );
      });

      test('C2 dialogs Cancel ghost button on surface1', () {
        final restBg = over(HiveButtonVariant.ghost.background(c), c.surface1);
        final hoverBg = layer(c, restBg, c.onSurface, {WidgetState.hovered});
        final pressBg = layer(c, restBg, c.onSurface, {WidgetState.pressed});
        checkRatio(
          reportRows,
          name,
          'C2',
          'Cancel rest',
          c.onSurface,
          restBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C2',
          'Cancel hover',
          c.onSurface,
          hoverBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C2',
          'Cancel pressed',
          c.onSurface,
          pressBg,
          HiveContrastLevel.text,
        );
      });

      test('C3 dialogs Confirm danger button', () {
        final restBg = c.danger;
        final hoverBg = layer(c, restBg, c.onDanger, {WidgetState.hovered});
        final pressBg = layer(c, restBg, c.onDanger, {WidgetState.pressed});
        checkRatio(
          reportRows,
          name,
          'C3',
          'Confirm rest',
          c.onDanger,
          restBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C3',
          'Confirm hover',
          c.onDanger,
          hoverBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C3',
          'Confirm pressed',
          c.onDanger,
          pressBg,
          HiveContrastLevel.text,
        );
      });

      test('C4 dialogs focus ring on surface1', () {
        checkRatio(
          reportRows,
          name,
          'C4',
          'focusRing / surface1',
          c.focusRing,
          c.surface1,
          HiveContrastLevel.ui,
        );
      });

      test('C5 rows name and meta on surface2', () {
        checkRatio(
          reportRows,
          name,
          'C5',
          'onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C5',
          'onSurfaceMuted / surface2',
          c.onSurfaceMuted,
          c.surface2,
          HiveContrastLevel.text,
        );
      });

      test('C6 rows deleting badge text on warning background', () {
        checkRatio(
          reportRows,
          name,
          'C6',
          'warning badge fg / bg',
          HiveBadgeTone.warning.foreground(c),
          HiveBadgeTone.warning.background(c),
          HiveContrastLevel.text,
        );
      });

      test('C7 rows deleting badge edge on surface2', () {
        checkRatio(
          reportRows,
          name,
          'C7',
          'warning badge bg / surface2',
          HiveBadgeTone.warning.background(c),
          c.surface2,
          HiveContrastLevel.ui,
        );
      });

      test('C8 rows enabled action icon on surface2', () {
        final restBg = over(HiveButtonVariant.ghost.background(c), c.surface2);
        final hoverBg = layer(c, restBg, c.onSurface, {WidgetState.hovered});
        final pressBg = layer(c, restBg, c.onSurface, {WidgetState.pressed});
        checkRatio(
          reportRows,
          name,
          'C8',
          'action rest',
          c.onSurface,
          restBg,
          HiveContrastLevel.ui,
        );
        checkRatio(
          reportRows,
          name,
          'C8',
          'action hover',
          c.onSurface,
          hoverBg,
          HiveContrastLevel.ui,
        );
        checkRatio(
          reportRows,
          name,
          'C8',
          'action pressed',
          c.onSurface,
          pressBg,
          HiveContrastLevel.ui,
        );
      });

      test('C9 rows focus ring on surface2', () {
        checkRatio(
          reportRows,
          name,
          'C9',
          'focusRing / surface2',
          c.focusRing,
          c.surface2,
          HiveContrastLevel.ui,
        );
      });

      test('C10 tooltip onSurface on surface3', () {
        checkRatio(
          reportRows,
          name,
          'C10',
          'onSurface / surface3',
          c.onSurface,
          c.surface3,
          HiveContrastLevel.text,
        );
      });

      test('C11 notices title, message, sentence, ids on surface2', () {
        checkRatio(
          reportRows,
          name,
          'C11',
          'onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C11',
          'onSurfaceMuted / surface2',
          c.onSurfaceMuted,
          c.surface2,
          HiveContrastLevel.text,
        );
      });

      test('C12 notices tone hairline on surface2 and surface1', () {
        for (final tone in <HiveFeedbackTone>[
          HiveFeedbackTone.success,
          HiveFeedbackTone.warning,
          HiveFeedbackTone.danger,
        ]) {
          checkRatio(
            reportRows,
            name,
            'C12',
            '${tone.name} / surface2',
            tone.color(c),
            c.surface2,
            HiveContrastLevel.ui,
          );
          checkRatio(
            reportRows,
            name,
            'C12',
            '${tone.name} / surface1',
            tone.color(c),
            c.surface1,
            HiveContrastLevel.ui,
          );
        }
      });

      test('C13 notices tone badge icon onColor on color', () {
        for (final tone in <HiveFeedbackTone>[
          HiveFeedbackTone.success,
          HiveFeedbackTone.warning,
          HiveFeedbackTone.danger,
        ]) {
          checkRatio(
            reportRows,
            name,
            'C13',
            '${tone.name} onColor / color',
            tone.onColor(c),
            tone.color(c),
            HiveContrastLevel.ui,
          );
        }
      });

      test('C14 notices Retry/Reload secondary button label', () {
        final fg = HiveButtonVariant.secondary.foreground(c);
        final restBg = HiveButtonVariant.secondary.background(c);
        final hoverBg = layer(c, restBg, fg, {WidgetState.hovered});
        final pressBg = layer(c, restBg, fg, {WidgetState.pressed});
        checkRatio(
          reportRows,
          name,
          'C14',
          'secondary rest',
          fg,
          restBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C14',
          'secondary hover',
          fg,
          hoverBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'C14',
          'secondary pressed',
          fg,
          pressBg,
          HiveContrastLevel.text,
        );
      });

      test('C15 notices Retry/Reload secondary boundary (report only)', () {
        checkRatio(
          reportRows,
          name,
          'C15',
          'borderSubtle / surface2',
          HiveButtonVariant.secondary.border?.call(c) ?? c.borderSubtle,
          c.surface2,
          HiveContrastLevel.ui,
          reportOnly: true,
        );
        checkRatio(
          reportRows,
          name,
          'C15',
          'surface3 / surface2',
          c.surface3,
          c.surface2,
          HiveContrastLevel.ui,
          reportOnly: true,
        );
      });

      test('C16 notices dismiss icon on surface2', () {
        final restBg = over(HiveButtonVariant.ghost.background(c), c.surface2);
        final hoverBg = layer(c, restBg, c.onSurface, {WidgetState.hovered});
        final pressBg = layer(c, restBg, c.onSurface, {WidgetState.pressed});
        checkRatio(
          reportRows,
          name,
          'C16',
          'dismiss rest',
          c.onSurface,
          restBg,
          HiveContrastLevel.ui,
        );
        checkRatio(
          reportRows,
          name,
          'C16',
          'dismiss hover',
          c.onSurface,
          hoverBg,
          HiveContrastLevel.ui,
        );
        checkRatio(
          reportRows,
          name,
          'C16',
          'dismiss pressed',
          c.onSurface,
          pressBg,
          HiveContrastLevel.ui,
        );
      });

      test('C17 disabled actions (report only)', () {
        final disabledFg = over(
          c.onSurface.withValues(alpha: c.disabledOpacity),
          c.surface2,
        );
        checkRatio(
          reportRows,
          name,
          'C17',
          'disabled onSurface / surface2',
          disabledFg,
          c.surface2,
          HiveContrastLevel.ui,
          reportOnly: true,
        );
      });
    });
  }

  test('contrast report', () {
    reportRows.forEach(debugPrint);
  });
}
