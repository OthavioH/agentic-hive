import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  Widget buildItem({
    int? badgeCount,
    String? semanticLabel,
    bool expanded = false,
    bool selected = false,
    ThemeData? theme,
  }) {
    return hiveTestApp(
      theme: theme,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: expanded ? 256 : null,
          child: HiveRailItem(
            icon: HiveIcons.pauses,
            label: 'Pauses',
            expanded: expanded,
            selected: selected,
            badgeCount: badgeCount,
            semanticLabel: semanticLabel,
            onPressed: () {},
          ),
        ),
      ),
    );
  }

  group('HiveRailItem.badgeText', () {
    test('shows counts up to the maximum in full', () {
      expect(HiveRailItem.badgeText(1), '1');
      expect(HiveRailItem.badgeText(99), '99');
    });

    test('caps counts above the maximum', () {
      expect(HiveRailItem.badgeText(100), '99+');
      expect(HiveRailItem.badgeText(12345), '99+');
    });
  });

  group('HiveRailItem badge', () {
    for (final expanded in <bool>[false, true]) {
      final mode = expanded ? 'expanded' : 'collapsed';

      testWidgets('shows the count while $mode', (tester) async {
        await tester.pumpWidget(buildItem(badgeCount: 3, expanded: expanded));

        expect(find.text('3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows 99+ for large counts while $mode', (tester) async {
        await tester.pumpWidget(
          buildItem(badgeCount: 1000, expanded: expanded, selected: true),
        );

        expect(find.text('99+'), findsOneWidget);
        expect(find.text('1000'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('hides the badge for null and zero while $mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildItem(expanded: expanded));
        expect(find.text('0'), findsNothing);

        await tester.pumpWidget(buildItem(badgeCount: 0, expanded: expanded));
        expect(find.text('0'), findsNothing);
      });
    }

    testWidgets('keeps the collapsed item a 48 px circle', (tester) async {
      await tester.pumpWidget(buildItem(badgeCount: 1000));

      expect(tester.getSize(find.byType(HiveRailItem)), const Size(48, 48));
    });

    testWidgets('paints onWarning text on a warning pill', (tester) async {
      final theme = HiveTheme.light();
      await tester.pumpWidget(buildItem(badgeCount: 7, theme: theme));

      final colors = theme.extension<HiveColors>()!;
      final text = tester.widget<Text>(find.text('7'));
      expect(text.style?.color, colors.onWarning);

      final pill = tester.widget<Container>(
        find
            .ancestor(of: find.text('7'), matching: find.byType(Container))
            .first,
      );
      final decoration = pill.decoration! as ShapeDecoration;
      expect(decoration.color, colors.warning);
    });

    testWidgets('announces the consumer semantics label, not the pill', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        buildItem(badgeCount: 3, semanticLabel: 'Pauses, 3 pending'),
      );

      expect(find.bySemanticsLabel('Pauses, 3 pending'), findsOneWidget);
      expect(find.bySemanticsLabel('3'), findsNothing);
      handle.dispose();
    });

    testWidgets('falls back to the label for semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(buildItem(badgeCount: 3, expanded: true));

      expect(find.bySemanticsLabel('Pauses'), findsOneWidget);
      handle.dispose();
    });
  });

  group('HiveSideRail destination badge', () {
    Widget buildRail({required bool expanded}) {
      return hiveTestApp(
        child: Row(
          children: <Widget>[
            HiveSideRail(
              destinations: const <HiveRailDestination>[
                HiveRailDestination(icon: HiveIcons.runs, label: 'Runs'),
                HiveRailDestination(
                  icon: HiveIcons.pauses,
                  label: 'Pauses',
                  badgeCount: 3,
                  semanticLabel: 'Pauses, 3 pending',
                ),
              ],
              selectedIndex: 0,
              onSelected: (_) {},
              markLabel: 'Agentic Hive',
              expandLabel: 'Expand navigation',
              collapseLabel: 'Collapse navigation',
              expanded: expanded,
            ),
          ],
        ),
      );
    }

    for (final expanded in <bool>[false, true]) {
      testWidgets(
        'forwards count and label while ${expanded ? 'expanded' : 'collapsed'}',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final handle = tester.ensureSemantics();

          await tester.pumpWidget(buildRail(expanded: expanded));
          await tester.pumpAndSettle();

          expect(find.text('3'), findsOneWidget);
          expect(find.bySemanticsLabel('Pauses, 3 pending'), findsOneWidget);
          expect(tester.takeException(), isNull);
          handle.dispose();
        },
      );
    }
  });
}
