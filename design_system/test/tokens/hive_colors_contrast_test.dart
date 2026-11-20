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
      });
    }
  });
}
