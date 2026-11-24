import 'package:design_system/design_system.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  group('HiveInsetPanel', () {
    for (final entry in <String, ({ThemeData theme, HiveColors colors})>{
      'dark': (theme: HiveTheme.dark(), colors: HiveColors.dark),
      'light': (theme: HiveTheme.light(), colors: HiveColors.light),
    }.entries) {
      testWidgets(
        'uses surface2 fill, borderSubtle hairline and radiusCard (${entry.key})',
        (tester) async {
          await tester.pumpWidget(
            hiveTestApp(
              theme: entry.value.theme,
              child: const HiveInsetPanel(child: Text('Panel body')),
            ),
          );

          final decorated = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(HiveInsetPanel),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final decoration = decorated.decoration as BoxDecoration;
          expect(decoration.color, entry.value.colors.surface2);
          expect(decoration.borderRadius, HiveRadii.standard.card);
          final border = decoration.border! as Border;
          expect(border.top.color, entry.value.colors.borderSubtle);
          expect(border.top.width, HiveElevation.dark.hairline);
        },
      );
    }

    testWidgets('defaults to compact padding and matches each enum padding', (
      tester,
    ) async {
      const defaultPanel = HiveInsetPanel(child: SizedBox());
      expect(defaultPanel.padding, HiveInsetPadding.compact);

      final spacing = HiveSpacing.standard;
      final expected = <HiveInsetPadding, EdgeInsets>{
        HiveInsetPadding.tight: EdgeInsets.all(spacing.space1),
        HiveInsetPadding.compact: EdgeInsets.symmetric(
          horizontal: spacing.space2,
          vertical: spacing.space1,
        ),
        HiveInsetPadding.comfortable: EdgeInsets.all(spacing.space2),
      };

      for (final entry in expected.entries) {
        await tester.pumpWidget(
          hiveTestApp(
            child: HiveInsetPanel(
              padding: entry.key,
              child: const Text('Content'),
            ),
          ),
        );

        final padding = tester.widget<Padding>(
          find
              .descendant(
                of: find.byType(HiveInsetPanel),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect(padding.padding, entry.value, reason: entry.key.name);
      }
    });

    testWidgets('adds no semantics node of its own', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(child: const HiveInsetPanel(child: Text('Inside'))),
        );

        expect(
          find.descendant(
            of: find.byType(HiveInsetPanel),
            matching: find.byType(Semantics),
          ),
          findsNothing,
        );

        final panelNode = tester.getSemantics(find.byType(HiveInsetPanel));
        expect(panelNode.label, 'Inside');
        expect(
          panelNode.getSemanticsData().hasFlag(SemanticsFlag.isButton),
          isFalse,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'header row and stacked explanation do not overflow at 280px and 2.0x text',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: hiveTestApp(
              child: SizedBox(
                width: 280,
                child: HiveInsetPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: HiveSpacing.standard.space1,
                        runSpacing: HiveSpacing.standard.space1,
                        children: <Widget>[
                          const HiveBadge(
                            label: 'Skill not installed',
                            tone: HiveBadgeTone.neutral,
                          ),
                          HiveButton(
                            label: 'Install',
                            size: HiveButtonSize.small,
                            variant: HiveButtonVariant.secondary,
                            onPressed: () {},
                          ),
                        ],
                      ),
                      SizedBox(height: HiveSpacing.standard.space1),
                      const Text(
                        'Could not read the existing skill directory due to '
                        'a naming conflict with another file on disk.',
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
