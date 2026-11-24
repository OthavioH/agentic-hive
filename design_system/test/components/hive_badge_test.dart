import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  group('HiveBadge', () {
    for (final entry in <String, ({ThemeData theme, HiveColors colors})>{
      'dark': (theme: HiveTheme.dark(), colors: HiveColors.dark),
      'light': (theme: HiveTheme.light(), colors: HiveColors.light),
    }.entries) {
      testWidgets(
        'neutral tone draws 1px borderStrong foreground outline (${entry.key})',
        (tester) async {
          await tester.pumpWidget(
            hiveTestApp(
              theme: entry.value.theme,
              child: const HiveBadge(label: 'Not installed'),
            ),
          );

          final foregroundBoxes = tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: find.byType(HiveBadge),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .where((box) => box.position == DecorationPosition.foreground)
              .toList();

          expect(foregroundBoxes, hasLength(1));
          final decoration = foregroundBoxes.single.decoration as BoxDecoration;
          expect(decoration.borderRadius, HiveRadii.standard.pill);
          final border = decoration.border! as Border;
          expect(border.top.color, entry.value.colors.borderStrong);
          expect(border.top.width, HiveElevation.dark.hairline);
        },
      );
    }

    testWidgets('non-neutral tones do not draw a foreground outline', (
      tester,
    ) async {
      for (final tone in HiveBadgeTone.values.where(
        (t) => t != HiveBadgeTone.neutral,
      )) {
        expect(tone.border, isNull, reason: tone.name);

        await tester.pumpWidget(
          hiveTestApp(
            child: HiveBadge(label: tone.name, tone: tone),
          ),
        );

        final foregroundBoxes = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(HiveBadge),
                matching: find.byType(DecoratedBox),
              ),
            )
            .where((box) => box.position == DecorationPosition.foreground);

        expect(foregroundBoxes, isEmpty, reason: tone.name);
      }
    });

    testWidgets('neutral and info badges with the same label have equal size', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HiveBadge(label: 'Status'),
              HiveBadge(label: 'Status', tone: HiveBadgeTone.info),
            ],
          ),
        ),
      );

      final neutralSize = tester.getSize(find.byType(HiveBadge).at(0));
      final infoSize = tester.getSize(find.byType(HiveBadge).at(1));
      expect(neutralSize, infoSize);
    });
  });
}
