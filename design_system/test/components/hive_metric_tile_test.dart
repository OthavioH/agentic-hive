import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  group('HiveMetricTile', () {
    testWidgets('focal uses the number role, compact the display role', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const Column(
            children: <Widget>[
              HiveMetricTile(
                value: '12',
                label: 'Active runs',
                size: HiveMetricTileSize.focal,
              ),
              HiveMetricTile(value: '3', label: 'Pending pauses'),
            ],
          ),
        ),
      );
      final typography = tester
          .element(find.byType(HiveMetricTile).first)
          .hiveTypography;

      final focal = tester.widget<Text>(find.text('12'));
      expect(focal.style?.fontSize, typography.number.fontSize);
      expect(focal.style?.fontFamily, endsWith(HiveFontFamilies.display));

      final compact = tester.widget<Text>(find.text('3'));
      expect(compact.style?.fontSize, typography.display.fontSize);
      expect(compact.style?.fontFamily, endsWith(HiveFontFamilies.display));

      for (final label in <String>['Active runs', 'Pending pauses']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.style?.fontFamily, endsWith(HiveFontFamilies.ui));
        expect(text.style?.fontSize, typography.label.fontSize);
      }
    });

    testWidgets('focal pads with space3, compact with space2', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const Column(
            children: <Widget>[
              HiveMetricTile(
                value: '12',
                label: 'Active runs',
                size: HiveMetricTileSize.focal,
              ),
              HiveMetricTile(value: '3', label: 'Pending pauses'),
            ],
          ),
        ),
      );
      final spacing = tester
          .element(find.byType(HiveMetricTile).first)
          .hiveSpacing;
      final paddings = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(HiveMetricTile),
              matching: find.byType(Padding),
            ),
          )
          .map((p) => p.padding)
          .toList();
      expect(paddings, <EdgeInsetsGeometry>[
        EdgeInsets.all(spacing.space3),
        EdgeInsets.all(spacing.space2),
      ]);
    });

    testWidgets('exposes one default semantics node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveMetricTile(
            value: '7',
            label: 'Failed runs',
            tone: HiveFeedbackTone.danger,
          ),
        ),
      );

      expect(find.bySemanticsLabel('Failed runs: 7'), findsOneWidget);
      expect(find.bySemanticsLabel('Failed runs'), findsNothing);
      handle.dispose();
    });

    testWidgets('uses a custom semantics label when given', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveMetricTile(
            value: '7',
            label: 'Failed runs',
            tone: HiveFeedbackTone.danger,
            semanticLabel: 'Failed runs: 7, needs attention',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Failed runs: 7, needs attention'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('no tone means no tone icon', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveMetricTile(value: '4', label: 'Agents'),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(HiveMetricTile),
          matching: find.byType(HiveIcon),
        ),
        findsNothing,
      );
    });

    testWidgets('a long value scales down instead of overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const Center(
            child: SizedBox(
              width: 160,
              child: HiveMetricTile(
                value: '1,284,356,027',
                label: 'Harness output lines streamed this week',
                size: HiveMetricTileSize.focal,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    for (final entry in <String, ThemeData>{
      'dark': HiveTheme.dark(),
      'light': HiveTheme.light(),
    }.entries) {
      for (final surface in HiveCardSurface.values) {
        testWidgets(
          '${entry.key} ${surface.name}: tone icon, onSurface text, card shape',
          (tester) async {
            await tester.pumpWidget(
              hiveTestApp(
                theme: entry.value,
                child: HiveMetricTile(
                  value: '3',
                  label: 'Pending pauses',
                  tone: HiveFeedbackTone.warning,
                  surface: surface,
                ),
              ),
            );
            final context = tester.element(find.byType(HiveMetricTile));
            final colors = context.hiveColors;

            final box = tester.widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(HiveMetricTile),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            );
            final decoration = box.decoration as BoxDecoration;
            expect(decoration.color, surface.color(colors));
            expect(decoration.borderRadius, context.hiveRadii.card);
            expect(
              decoration.border,
              Border.all(
                color: colors.borderSubtle,
                width: context.hiveElevation.hairline,
              ),
            );

            final icon = tester.widget<HiveIcon>(find.byType(HiveIcon));
            expect(icon.icon, HiveFeedbackTone.warning.icon);
            expect(icon.color, colors.warning);

            expect(
              tester.widget<Text>(find.text('3')).style?.color,
              colors.onSurface,
            );
            expect(
              tester.widget<Text>(find.text('Pending pauses')).style?.color,
              colors.onSurfaceMuted,
            );
          },
        );
      }

      test('${entry.key}: text 4.5:1 and tone icons 3:1 on tile surfaces', () {
        final colors = entry.value.extension<HiveColors>()!;
        for (final surface in HiveCardSurface.values) {
          final background = surface.color(colors);
          for (final text in <Color>[colors.onSurface, colors.onSurfaceMuted]) {
            expect(
              HiveContrast.ratio(text, background),
              greaterThanOrEqualTo(HiveContrastLevel.text.minimumRatio),
            );
          }
          for (final tone in HiveFeedbackTone.values) {
            expect(
              HiveContrast.ratio(tone.color(colors), background),
              greaterThanOrEqualTo(HiveContrastLevel.ui.minimumRatio),
              reason: '${tone.name} on ${surface.name}',
            );
          }
        }
      });
    }
  });
}
