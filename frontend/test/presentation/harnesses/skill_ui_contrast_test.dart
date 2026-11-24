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
    String? exemptionNote,
  }) {
    final ratio = HiveContrast.ratio(fg, bg);
    final min = level == HiveContrastLevel.text ? 4.5 : 3.0;
    final pass = ratio >= min;
    rows.add(
      '| $themeName | $id | $label | ${ratio.toStringAsFixed(2)}:1 '
      '| ${min.toStringAsFixed(1)}:1 | '
      '${exemptionNote ?? (pass ? 'PASS' : 'FAIL')} |',
    );
    if (exemptionNote == null) {
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

    group('skill UI contrast ($name)', () {
      test('S1 status badge foreground on badge background (text 4.5:1)', () {
        for (final tone in <HiveBadgeTone>[
          HiveBadgeTone.success,
          HiveBadgeTone.neutral,
          HiveBadgeTone.warning,
          HiveBadgeTone.danger,
          HiveBadgeTone.info,
        ]) {
          checkRatio(
            reportRows,
            name,
            'S1',
            '${tone.name} badge fg / bg',
            tone.foreground(c),
            tone.background(c),
            HiveContrastLevel.text,
          );
        }
      });

      test('S2 status badge background vs panel surface2 (UI 3.0:1)', () {
        for (final tone in <HiveBadgeTone>[
          HiveBadgeTone.success,
          HiveBadgeTone.neutral,
          HiveBadgeTone.warning,
          HiveBadgeTone.danger,
          HiveBadgeTone.info,
        ]) {
          // Known catalog token exception: HiveBadgeTone.neutral uses surface3
          // on surface2 (1.13:1 dark, 1.10:1 light). Tracked in
          // https://github.com/OthavioH/agentic-hive/issues/146 while keeping
          // neutral badge tone per #125 frozen structure.
          final isKnownNeutralTokenGap = tone == HiveBadgeTone.neutral;
          checkRatio(
            reportRows,
            name,
            'S2',
            '${tone.name} badge bg / surface2',
            tone.background(c),
            c.surface2,
            HiveContrastLevel.ui,
            exemptionNote: isKnownNeutralTokenGap
                ? 'FAIL (known catalog gap #146)'
                : null,
          );
        }
      });

      test('S3 text roles on surface2 (panel) and surface1 (card)', () {
        checkRatio(
          reportRows,
          name,
          'S3',
          'onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'S3',
          'onSurfaceMuted / surface2',
          c.onSurfaceMuted,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'S3',
          'onSurface / surface1',
          c.onSurface,
          c.surface1,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'S3',
          'onSurfaceMuted / surface1',
          c.onSurfaceMuted,
          c.surface1,
          HiveContrastLevel.text,
        );
      });

      test('S4 banner text, borders, and icon badges on surface2', () {
        checkRatio(
          reportRows,
          name,
          'S4',
          'banner onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
        for (final tone in <HiveFeedbackTone>[
          HiveFeedbackTone.success,
          HiveFeedbackTone.warning,
          HiveFeedbackTone.danger,
        ]) {
          checkRatio(
            reportRows,
            name,
            'S4',
            '${tone.name} border / surface2',
            tone.color(c),
            c.surface2,
            HiveContrastLevel.ui,
          );
          checkRatio(
            reportRows,
            name,
            'S4',
            '${tone.name} badge onColor / color',
            tone.onColor(c),
            tone.color(c),
            HiveContrastLevel.ui,
          );
        }
      });

      test('S5 mono path and label text on surface2', () {
        checkRatio(
          reportRows,
          name,
          'S5',
          'mono onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'S5',
          'label onSurfaceMuted / surface2',
          c.onSurfaceMuted,
          c.surface2,
          HiveContrastLevel.text,
        );
      });

      test('S6 secondary and ghost button label across interaction states', () {
        final secFg = HiveButtonVariant.secondary.foreground(c);
        final secBase = HiveButtonVariant.secondary.background(c);
        for (final entry in <String, Set<WidgetState>>{
          'default': <WidgetState>{},
          'hover': <WidgetState>{WidgetState.hovered},
          'pressed': <WidgetState>{WidgetState.pressed},
          'focus': <WidgetState>{WidgetState.focused},
        }.entries) {
          final bg = layer(c, secBase, secFg, entry.value);
          checkRatio(
            reportRows,
            name,
            'S6',
            'secondary ${entry.key}',
            secFg,
            bg,
            HiveContrastLevel.text,
          );
        }

        final ghostFg = HiveButtonVariant.ghost.foreground(c);
        final ghostBase = over(
          HiveButtonVariant.ghost.background(c),
          c.surface2,
        );
        for (final entry in <String, Set<WidgetState>>{
          'default': <WidgetState>{},
          'hover': <WidgetState>{WidgetState.hovered},
          'pressed': <WidgetState>{WidgetState.pressed},
          'focus': <WidgetState>{WidgetState.focused},
        }.entries) {
          final bg = layer(c, ghostBase, ghostFg, entry.value);
          checkRatio(
            reportRows,
            name,
            'S6',
            'ghost ${entry.key}',
            ghostFg,
            bg,
            HiveContrastLevel.text,
          );
        }

        // Disabled state is exempt per WCAG 2.x SC 1.4.3.
        final disabledFg = over(
          c.onSurface.withValues(alpha: c.disabledOpacity),
          c.surface2,
        );
        checkRatio(
          reportRows,
          name,
          'S6',
          'disabled onSurface / surface2',
          disabledFg,
          c.surface2,
          HiveContrastLevel.text,
          exemptionNote: 'exempt (disabled)',
        );
      });

      test('S7 settings switch label/help and track/thumb states', () {
        checkRatio(
          reportRows,
          name,
          'S7',
          'switch label onSurface / background',
          c.onSurface,
          c.background,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'S7',
          'switch help onSurfaceMuted / background',
          c.onSurfaceMuted,
          c.background,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'S7',
          'switch label onSurface / surface1',
          c.onSurface,
          c.surface1,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'S7',
          'switch help onSurfaceMuted / surface1',
          c.onSurfaceMuted,
          c.surface1,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'S7',
          'switch ON thumb onAccent / accent',
          c.onAccent,
          c.accent,
          HiveContrastLevel.ui,
        );
        checkRatio(
          reportRows,
          name,
          'S7',
          'switch OFF thumb onSurfaceMuted / surface3',
          c.onSurfaceMuted,
          c.surface3,
          HiveContrastLevel.ui,
        );
      });
    });
  }

  tearDownAll(() {
    reportRows.forEach(debugPrint);
  });
}
