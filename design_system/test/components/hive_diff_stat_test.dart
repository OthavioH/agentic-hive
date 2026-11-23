import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  group('HiveDiffStat', () {
    testWidgets('shows +A ~M -D in Geist Mono', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveDiffStat(added: 12, modified: 3, deleted: 1),
        ),
      );

      final mono = tester
          .element(find.byType(HiveDiffStat))
          .hiveTypography
          .mono;
      for (final label in <String>['+12', '~3', '-1']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.style?.fontFamily, mono.fontFamily);
        expect(text.style?.fontFamily, endsWith(HiveFontFamilies.mono));
      }
    });

    testWidgets('exposes a default semantics label', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveDiffStat(added: 2, modified: 0, deleted: 5),
        ),
      );

      expect(
        find.bySemanticsLabel('2 added, 0 modified, 5 deleted'),
        findsOneWidget,
      );
    });

    testWidgets('uses a custom semantics label when given', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveDiffStat(
            added: 1,
            modified: 1,
            deleted: 1,
            semanticLabel: 'Snapshot changes',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Snapshot changes'), findsOneWidget);
    });

    for (final entry in <String, ThemeData>{
      'dark': HiveTheme.dark(),
      'light': HiveTheme.light(),
    }.entries) {
      testWidgets('${entry.key}: surface2 pill, tone icons, onSurface text', (
        tester,
      ) async {
        await tester.pumpWidget(
          hiveTestApp(
            theme: entry.value,
            child: const HiveDiffStat(added: 4, modified: 2, deleted: 0),
          ),
        );
        final context = tester.element(find.byType(HiveDiffStat));
        final colors = context.hiveColors;

        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(HiveDiffStat),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, colors.surface2);
        expect(decoration.borderRadius, context.hiveRadii.pill);

        final icons = tester
            .widgetList<HiveIcon>(find.byType(HiveIcon))
            .toList();
        expect(icons.map((i) => i.icon), <HiveIconData>[
          HiveIcons.add,
          HiveIcons.edit,
          HiveIcons.delete,
        ]);
        expect(icons.map((i) => i.color), <Color>[
          colors.success,
          colors.warning,
          colors.onSurfaceMuted,
        ]);

        expect(
          tester.widget<Text>(find.text('+4')).style?.color,
          colors.onSurface,
        );
        expect(
          tester.widget<Text>(find.text('-0')).style?.color,
          colors.onSurfaceMuted,
        );
      });

      test('${entry.key}: text and icons meet WCAG AA on surface2', () {
        final colors = entry.value.extension<HiveColors>()!;
        for (final text in <Color>[colors.onSurface, colors.onSurfaceMuted]) {
          expect(
            HiveContrast.ratio(text, colors.surface2),
            greaterThanOrEqualTo(HiveContrastLevel.text.minimumRatio),
          );
        }
        for (final kind in HiveDiffKind.values) {
          expect(
            HiveContrast.ratio(kind.tone(colors), colors.surface2),
            greaterThanOrEqualTo(HiveContrastLevel.ui.minimumRatio),
          );
        }
      });
    }
  });
}
