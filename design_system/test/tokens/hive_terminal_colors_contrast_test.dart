import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('HiveTerminalColors WCAG AA contrast', () {
    for (final entry in <String, HiveTerminalColors>{
      'dark': HiveTerminalColors.dark,
      'light': HiveTerminalColors.light,
    }.entries) {
      group('${entry.key} palette', () {
        for (final pair in entry.value.contrastPairs) {
          test('${pair.foregroundRole} on ${pair.backgroundRole} '
              '(>= ${pair.level.minimumRatio}:1)', () {
            expect(
              pair.ratio,
              greaterThanOrEqualTo(pair.level.minimumRatio),
              reason:
                  '${entry.key}: ${pair.foregroundRole} on '
                  '${pair.backgroundRole} is '
                  '${pair.ratio.toStringAsFixed(2)}:1',
            );
          });
        }

        test('covers all 16 ANSI colors as text or as a fill', () {
          final palette = entry.value;
          final roles = <String>{
            for (final p in palette.contrastPairs) ...<String>[
              p.foregroundRole,
              p.backgroundRole,
            ],
          };
          expect(palette.ansi, hasLength(16));
          expect(roles, containsAll(palette.ansi.keys));
        });
      });
    }

    test('derives surface, text and tones from HiveColors', () {
      for (final colors in <HiveColors>[HiveColors.dark, HiveColors.light]) {
        final palette = HiveTerminalColors.from(colors);
        expect(palette.brightness, colors.brightness);
        expect(palette.background, colors.background);
        expect(palette.foreground, colors.onSurface);
        expect(palette.red, colors.danger);
        expect(palette.green, colors.success);
        expect(palette.yellow, colors.warning);
        expect(palette.blue, colors.info);
        expect(palette.brightBlack, colors.onSurfaceMuted);
      }
    });

    test('selection is translucent so the selected text stays visible', () {
      expect(HiveTerminalColors.dark.selection.a, lessThan(1));
      expect(HiveTerminalColors.light.selection.a, lessThan(1));
      expect(HiveTerminalColors.dark.brightness, Brightness.dark);
    });
  });
}
