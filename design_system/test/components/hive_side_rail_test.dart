import 'package:design_system/design_system.dart';
import 'package:flutter/gestures.dart';
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

  group('HiveSideRail section', () {
    Widget buildWithSection({
      bool expanded = false,
      bool pinned = false,
      int? badgeCount,
      String? semanticLabel,
      ValueChanged<bool>? onPinnedChanged,
      HiveRailSectionController? controller,
      bool disableAnimations = false,
    }) {
      final rail = HiveSideRail(
        destinations: destinations,
        selectedIndex: 0,
        onSelected: (_) {},
        markLabel: 'Agentic Hive',
        expandLabel: 'Expand navigation',
        collapseLabel: 'Collapse navigation',
        initiallyExpanded: expanded,
        section: HiveRailSection(
          icon: HiveIcons.folder,
          label: 'Workspaces',
          title: 'Workspaces',
          badgeCount: badgeCount,
          semanticLabel: semanticLabel,
          pinned: pinned,
          onPinnedChanged: onPinnedChanged,
          controller: controller,
          child: ListView(
            children: <Widget>[
              HiveButton(label: 'Panel Action', onPressed: () {}),
            ],
          ),
        ),
      );

      final child = Row(
        children: <Widget>[
          rail,
          const Expanded(child: SizedBox()),
        ],
      );

      return hiveTestApp(
        child: disableAnimations
            ? MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: child,
              )
            : child,
      );
    }

    testWidgets('renders section entry with badge excluded from semantics', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildWithSection(
          badgeCount: 2,
          semanticLabel: 'Workspaces, 2 active runs',
        ),
      );

      expect(
        find.bySemanticsLabel('Workspaces, 2 active runs'),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.bySemanticsLabel('2'), findsNothing);
      expect(find.text('Panel Action'), findsNothing);
    });

    testWidgets('click toggles unpinned panel and controller closes it', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = HiveRailSectionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildWithSection(controller: controller));

      await tester.tap(find.bySemanticsLabel('Workspaces'));
      await tester.pumpAndSettle();
      expect(find.text('Panel Action'), findsOneWidget);

      controller.close();
      await tester.pumpAndSettle();
      expect(find.text('Panel Action'), findsNothing);
    });

    testWidgets('hover opens after short and closes after medium', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWithSection());

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(
        tester.getCenter(find.bySemanticsLabel('Workspaces')),
      );
      await tester.pump();
      expect(find.text('Panel Action'), findsNothing);

      // Motion short is 120ms.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('Panel Action'), findsOneWidget);

      // Move pointer away; closes after medium (220ms).
      await gesture.moveTo(const Offset(1000, 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Panel Action'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Panel Action'), findsNothing);
    });

    testWidgets('respects MediaQuery.disableAnimations on hover', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWithSection(disableAnimations: true));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(
        tester.getCenter(find.bySemanticsLabel('Workspaces')),
      );
      await tester.pump();
      expect(find.text('Panel Action'), findsOneWidget);
    });

    testWidgets('Enter opens and focuses panel; Escape closes and returns', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWithSection());

      // Tab past the 3 destinations to focus the section entry.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Panel Action'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Panel Action'), findsNothing);
    });

    testWidgets('pinned panel stays open in layout and toggles via pin', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool? nextPinned;
      await tester.pumpWidget(
        buildWithSection(
          pinned: true,
          onPinnedChanged: (value) => nextPinned = value,
        ),
      );

      expect(find.text('Panel Action'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Unpin panel'));
      await tester.pump();
      expect(nextPinned, isFalse);
    });
  });
}
