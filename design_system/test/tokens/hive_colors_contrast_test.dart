import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WCAG AA contrast', () {
    for (final entry in <String, HiveColors>{
      'dark': HiveColors.dark,
      'light': HiveColors.light,
    }.entries) {
      group('${entry.key} palette', () {
        for (final pair in entry.value.contrastPairs) {
          test('${pair.foregroundRole} on ${pair.backgroundRole} '
              '(${pair.level.name} >= ${pair.level.minimumRatio}:1)', () {
            expect(
              pair.ratio,
              greaterThanOrEqualTo(pair.level.minimumRatio),
              reason:
                  '${entry.key}: ${pair.foregroundRole} on '
                  '${pair.backgroundRole} is '
                  '${pair.ratio.toStringAsFixed(2)}:1, '
                  'expected >= ${pair.level.minimumRatio}:1',
            );
            expect(pair.passes, isTrue);
          });
        }

        test('covers the inverse pair and feedback tones on every surface', () {
          final pairs = entry.value.contrastPairs;
          expect(
            pairs.any(
              (p) =>
                  p.foregroundRole == 'background' &&
                  p.backgroundRole == 'onSurface' &&
                  p.level == HiveContrastLevel.text,
            ),
            isTrue,
          );
          for (final tone in <String>['success', 'warning', 'danger', 'info']) {
            for (final surface in entry.value.surfaces.keys) {
              expect(
                pairs.any(
                  (p) =>
                      p.foregroundRole == tone &&
                      p.backgroundRole == surface &&
                      p.level == HiveContrastLevel.ui,
                ),
                isTrue,
                reason: '$tone on $surface is not tested',
              );
            }
          }
        });
      });
    }
  });
}
