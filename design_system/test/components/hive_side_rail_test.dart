import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  const destinations = <HiveRailDestination>[
    HiveRailDestination(icon: HiveIcons.overview, label: 'Overview'),
    HiveRailDestination(icon: HiveIcons.workflows, label: 'Workflows'),
    HiveRailDestination(icon: HiveIcons.runs, label: 'Runs'),
  ];

  Widget buildRail({
    int? selectedIndex = 0,
    ValueChanged<int>? onSelected,
    bool? expanded,
    bool initiallyExpanded = false,
    ValueChanged<bool>? onExpandedChanged,
  }) {
    return hiveTestApp(
      child: Row(
        children: <Widget>[
          HiveSideRail(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onSelected: onSelected ?? (_) {},
            markLabel: 'Agentic Hive',
            expandLabel: 'Expand navigation',
            collapseLabel: 'Collapse navigation',
            expanded: expanded,
            initiallyExpanded: initiallyExpanded,
            onExpandedChanged: onExpandedChanged,
          ),
        ],
      ),
    );
  }

  group('HiveSideRail', () {
    testWidgets('is collapsed by default and hides destination labels', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildRail());

      expect(find.text('Overview'), findsNothing);
      expect(find.text('Workflows'), findsNothing);
      expect(find.bySemanticsLabel('Expand navigation'), findsOneWidget);
      expect(find.bySemanticsLabel('Agentic Hive'), findsOneWidget);
    });

    testWidgets('expands to show labels and collapses back', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildRail());

      await tester.tap(find.bySemanticsLabel('Expand navigation'));
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Workflows'), findsOneWidget);
      expect(find.text('Runs'), findsOneWidget);
      expect(find.bySemanticsLabel('Collapse navigation'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Collapse navigation'));
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsNothing);
      expect(find.bySemanticsLabel('Expand navigation'), findsOneWidget);
    });

    testWidgets('fires onSelected with tapped destination index', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      int? selected;
      await tester.pumpWidget(
        buildRail(
          initiallyExpanded: true,
          onSelected: (index) => selected = index,
        ),
      );

      await tester.tap(find.text('Workflows'));
      await tester.pump();

      expect(selected, 1);
    });

    testWidgets('supports controlled expanded state and onExpandedChanged', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool? requested;
      await tester.pumpWidget(
        buildRail(
          expanded: false,
          onExpandedChanged: (value) => requested = value,
        ),
      );

      await tester.tap(find.bySemanticsLabel('Expand navigation'));
      await tester.pump();

      expect(requested, isTrue);
      // Still collapsed because parent owns `expanded: false`.
      expect(find.text('Overview'), findsNothing);
    });

    testWidgets('supports keyboard activation on toggle', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildRail());

      // Tab past the 3 destinations to focus the toggle button, then Space.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsOneWidget);

      // Collapse back with Enter.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsNothing);
    });
  });
}
