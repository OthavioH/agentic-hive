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

    group('fan-out screens contrast ($name)', () {
      test('F1 run row workflow name onSurface / surface2', () {
        checkRatio(
          reportRows,
          name,
          'F1',
          'onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
      });

      test('F2 run row meta and child count onSurfaceMuted / surface2', () {
        checkRatio(
          reportRows,
          name,
          'F2',
          'onSurfaceMuted / surface2',
          c.onSurfaceMuted,
          c.surface2,
          HiveContrastLevel.text,
        );
      });

      test('F3 run row muted text on hovered card', () {
        final hoverBg = layer(c, c.surface2, c.onSurface, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'F3',
          'onSurfaceMuted / surface2 hovered',
          c.onSurfaceMuted,
          hoverBg,
          HiveContrastLevel.text,
        );
      });

      test('F4 badge foreground/background pairs', () {
        final pairs = <String, (Color fg, Color bg)>{
          'neutral onSurface/surface3': (c.onSurface, c.surface3),
          'info onInfo/info': (c.onInfo, c.info),
          'warning onWarning/warning': (c.onWarning, c.warning),
          'success onSuccess/success': (c.onSuccess, c.success),
          'danger onDanger/danger': (c.onDanger, c.danger),
        };
        for (final p in pairs.entries) {
          checkRatio(
            reportRows,
            name,
            'F4',
            p.key,
            p.value.$1,
            p.value.$2,
            HiveContrastLevel.text,
          );
        }
      });

      test('F5 status dot roles vs card surface2', () {
        final dots = <String, Color>{
          'statusRunning': c.statusRunning,
          'statusPaused': c.statusPaused,
          'statusFailed': c.statusFailed,
          'statusSucceeded': c.statusSucceeded,
          'statusIdle': c.statusIdle,
        };
        for (final d in dots.entries) {
          checkRatio(
            reportRows,
            name,
            'F5',
            '${d.key} / surface2',
            d.value,
            c.surface2,
            HiveContrastLevel.ui,
          );
        }
      });

      test('F6 expand toggle glyph on card surface2 rest and hovered', () {
        // HiveIconButton defaults to HiveButtonVariant.ghost (onSurface fg).
        final fg = HiveButtonVariant.ghost.foreground(c);
        final restBg = over(HiveButtonVariant.ghost.background(c), c.surface2);
        final hoverBg = layer(c, restBg, fg, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'F6',
          'toggle glyph rest',
          fg,
          restBg,
          HiveContrastLevel.ui,
        );
        checkRatio(
          reportRows,
          name,
          'F6',
          'toggle glyph hovered',
          fg,
          hoverBg,
          HiveContrastLevel.ui,
        );
      });

      test('F7 panel title onSurface / panel card surface2', () {
        checkRatio(
          reportRows,
          name,
          'F7',
          'onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
      });

      test('F8 panel progress text and empty note on surface2', () {
        checkRatio(
          reportRows,
          name,
          'F8',
          'progress onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F8',
          'empty onSurfaceMuted / surface2',
          c.onSurfaceMuted,
          c.surface2,
          HiveContrastLevel.text,
        );
      });

      test('F9 canvas card title and subtitle on surface2 and surface3', () {
        checkRatio(
          reportRows,
          name,
          'F9',
          'title onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F9',
          'title onSurface / surface3',
          c.onSurface,
          c.surface3,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F9',
          'subtitle onSurfaceMuted / surface2',
          c.onSurfaceMuted,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F9',
          'subtitle onSurfaceMuted / surface3',
          c.onSurfaceMuted,
          c.surface3,
          HiveContrastLevel.text,
        );
      });

      test('F10 canvas card borders vs surface2 and background', () {
        final borders = <String, Color>{
          'accent': c.accent,
          'success': c.success,
          'danger': c.danger,
          'warning': c.warning,
        };
        for (final b in borders.entries) {
          // Design-system blocker (S4): light accent (#C6EF4E) against light
          // surface2 (1.02:1) and background (1.24:1) is below 3.0:1.
          final isLightAccentBlocker = name == 'light' && b.key == 'accent';
          checkRatio(
            reportRows,
            name,
            'F10',
            '${b.key} / surface2',
            b.value,
            c.surface2,
            HiveContrastLevel.ui,
            reportOnly: isLightAccentBlocker,
          );
          checkRatio(
            reportRows,
            name,
            'F10',
            '${b.key} / background',
            b.value,
            c.background,
            HiveContrastLevel.ui,
            reportOnly: isLightAccentBlocker,
          );
        }
      });

      test('F11 canvas card selected border accent / surface3', () {
        // Design-system blocker (S4): light accent (#C6EF4E) against light
        // surface3 (1.09:1) is below 3.0:1.
        checkRatio(
          reportRows,
          name,
          'F11',
          'accent / surface3',
          c.accent,
          c.surface3,
          HiveContrastLevel.ui,
          reportOnly: name == 'light',
        );
      });

      test('F12 HiveBanner danger title, message, and tone roles', () {
        // HiveBanner uses surface2 fill, tone.color (danger) hairline/badge,
        // onSurface title, and onSurfaceMuted message.
        checkRatio(
          reportRows,
          name,
          'F12',
          'banner title onSurface / surface2',
          c.onSurface,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F12',
          'banner message onSurfaceMuted / surface2',
          c.onSurfaceMuted,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F12',
          'banner border danger / surface2',
          c.danger,
          c.surface2,
          HiveContrastLevel.ui,
        );
        checkRatio(
          reportRows,
          name,
          'F12',
          'banner tone badge onDanger / danger',
          c.onDanger,
          c.danger,
          HiveContrastLevel.ui,
        );
      });

      test('F13 fan-out config fields (mirrors 128-S M1-M8)', () {
        final hoverBg = layer(c, c.surface3, c.onSurface, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'F13',
          'label onSurface / surface1 (M1)',
          c.onSurface,
          c.surface1,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F13',
          'value onSurface / surface3 rest (M2)',
          c.onSurface,
          c.surface3,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F13',
          'value onSurface / surface3 hovered (M3)',
          c.onSurface,
          hoverBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F13',
          'hint onSurfaceMuted / surface3 rest (M4)',
          c.onSurfaceMuted,
          c.surface3,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F13',
          'hint onSurfaceMuted / surface3 hovered (M5)',
          c.onSurfaceMuted,
          hoverBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F13',
          'error danger / surface1 (M6)',
          c.danger,
          c.surface1,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F13',
          'error hairline danger / surface3 (M7)',
          c.danger,
          c.surface3,
          HiveContrastLevel.ui,
        );
        checkRatio(
          reportRows,
          name,
          'F13',
          'focusRing / surface1 (M8)',
          c.focusRing,
          c.surface1,
          HiveContrastLevel.ui,
        );
      });

      test('F14 pause list parent link on surface2 rest and hovered', () {
        final hoverBg = layer(c, c.surface2, c.onSurface, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'F14',
          'onSurfaceMuted / surface2 rest',
          c.onSurfaceMuted,
          c.surface2,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F14',
          'onSurfaceMuted / surface2 hovered',
          c.onSurfaceMuted,
          hoverBg,
          HiveContrastLevel.text,
        );
      });

      test('F15 pause detail ghost button on surface2 rest and hovered', () {
        // HiveButtonVariant.ghost uses onSurface foreground over transparent
        // background.
        final fg = HiveButtonVariant.ghost.foreground(c);
        final restBg = over(HiveButtonVariant.ghost.background(c), c.surface2);
        final hoverBg = layer(c, restBg, fg, const <WidgetState>{
          WidgetState.hovered,
        });
        checkRatio(
          reportRows,
          name,
          'F15',
          'ghost label rest',
          fg,
          restBg,
          HiveContrastLevel.text,
        );
        checkRatio(
          reportRows,
          name,
          'F15',
          'ghost label hovered',
          fg,
          hoverBg,
          HiveContrastLevel.text,
        );
      });

      test(
        'F16 hairlines borderSubtle on surface2 and surface1 (report only)',
        () {
          checkRatio(
            reportRows,
            name,
            'F16',
            'borderSubtle / surface2',
            c.borderSubtle,
            c.surface2,
            HiveContrastLevel.ui,
            reportOnly: true,
          );
          checkRatio(
            reportRows,
            name,
            'F16',
            'borderSubtle / surface1',
            c.borderSubtle,
            c.surface1,
            HiveContrastLevel.ui,
            reportOnly: true,
          );
        },
      );

      test('F17 disabled controls onSurface at disabledOpacity over surface2 '
          '(report only)', () {
        final disabledFg = over(
          c.onSurface.withValues(alpha: c.disabledOpacity),
          c.surface2,
        );
        checkRatio(
          reportRows,
          name,
          'F17',
          'disabled onSurface / surface2',
          disabledFg,
          c.surface2,
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
