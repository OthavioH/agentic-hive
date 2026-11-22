import 'dart:ui' show PointerDeviceKind;

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  Widget buildTitleBar({
    bool isMaximized = false,
    bool showSystemMenuOnRelease = false,
    VoidCallback? onMinimize,
    VoidCallback? onToggleMaximize,
    VoidCallback? onClose,
    VoidCallback? onDragStart,
    ValueChanged<Offset>? onSystemMenu,
    ThemeData? theme,
  }) {
    return hiveTestApp(
      theme: theme,
      child: Align(
        alignment: Alignment.topCenter,
        child: HiveTitleBar(
          isMaximized: isMaximized,
          showSystemMenuOnRelease: showSystemMenuOnRelease,
          labels: const HiveTitleBarLabels(
            minimize: 'Minimize',
            maximize: 'Maximize',
            restore: 'Restore',
            close: 'Close to tray',
          ),
          onMinimize: onMinimize ?? () {},
          onToggleMaximize: onToggleMaximize ?? () {},
          onClose: onClose ?? () {},
          onDragStart: onDragStart,
          onSystemMenu: onSystemMenu,
        ),
      ),
    );
  }

  group('HiveTitleBar', () {
    testWidgets('each caption button calls its callback', (tester) async {
      var minimized = 0;
      var toggled = 0;
      var closed = 0;

      await tester.pumpWidget(
        buildTitleBar(
          onMinimize: () => minimized++,
          onToggleMaximize: () => toggled++,
          onClose: () => closed++,
        ),
      );

      await tester.tap(find.bySemanticsLabel('Minimize'));
      await tester.tap(find.bySemanticsLabel('Maximize'));
      await tester.tap(find.bySemanticsLabel('Close to tray'));
      await tester.pump();

      expect(minimized, 1);
      expect(toggled, 1);
      expect(closed, 1);
    });

    testWidgets('switches icon and accessible label with isMaximized', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(buildTitleBar());
      expect(find.bySemanticsLabel('Maximize'), findsOneWidget);
      expect(find.bySemanticsLabel('Restore'), findsNothing);
      expect(
        tester.widgetList<HiveIcon>(find.byType(HiveIcon)).map((i) => i.icon),
        contains(HiveIcons.maximize),
      );

      await tester.pumpWidget(buildTitleBar(isMaximized: true));
      expect(find.bySemanticsLabel('Restore'), findsOneWidget);
      expect(find.bySemanticsLabel('Maximize'), findsNothing);
      expect(
        tester.widgetList<HiveIcon>(find.byType(HiveIcon)).map((i) => i.icon),
        contains(HiveIcons.restore),
      );

      handle.dispose();
    });

    testWidgets('every caption button has an accessible name', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(buildTitleBar());

      expect(find.bySemanticsLabel('Minimize'), findsOneWidget);
      expect(find.bySemanticsLabel('Maximize'), findsOneWidget);
      expect(find.bySemanticsLabel('Close to tray'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('close button uses danger role on hover', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final theme = HiveTheme.dark();
      final colors = theme.extension<HiveColors>()!;

      await tester.pumpWidget(buildTitleBar(theme: theme));

      final closeButton = find.byType(HiveIconButton).last;
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(const Offset(10, 10));
      await tester.pump();

      await gesture.moveTo(tester.getCenter(closeButton));
      await tester.pumpAndSettle();

      final container = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: closeButton,
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final decoration = container.decoration! as ShapeDecoration;
      expect(decoration.color, colors.danger);

      final icon = tester.widget<HiveIcon>(
        find.descendant(of: closeButton, matching: find.byType(HiveIcon)),
      );
      expect(icon.color, colors.onDanger);
    });

    testWidgets('double-click on drag area toggles maximize', (tester) async {
      var toggled = 0;

      await tester.pumpWidget(buildTitleBar(onToggleMaximize: () => toggled++));

      final barTopLeft = tester.getTopLeft(find.byType(HiveTitleBar));
      final dragPoint = barTopLeft + const Offset(40, 16);
      await tester.tapAt(dragPoint);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(dragPoint);
      await tester.pumpAndSettle();

      expect(toggled, 1);
    });

    testWidgets('drag and secondary click on empty area invoke callbacks', (
      tester,
    ) async {
      var drags = 0;
      Offset? menuPosition;

      await tester.pumpWidget(
        buildTitleBar(
          onDragStart: () => drags++,
          onSystemMenu: (pos) => menuPosition = pos,
        ),
      );

      final barTopLeft = tester.getTopLeft(find.byType(HiveTitleBar));
      final dragPoint = barTopLeft + const Offset(40, 16);

      await tester.dragFrom(dragPoint, const Offset(30, 0));
      await tester.pump();
      expect(drags, 1);

      await tester.tapAt(dragPoint, buttons: kSecondaryMouseButton);
      await tester.pump(const Duration(milliseconds: 500));
      expect(menuPosition, dragPoint);
    });

    testWidgets(
      'showSystemMenuOnRelease fires on secondary pointer release only',
      (tester) async {
        Offset? menuPosition;

        await tester.pumpWidget(
          buildTitleBar(
            showSystemMenuOnRelease: true,
            onSystemMenu: (pos) => menuPosition = pos,
          ),
        );

        final barTopLeft = tester.getTopLeft(find.byType(HiveTitleBar));
        final dragPoint = barTopLeft + const Offset(40, 16);
        final gesture = await tester.startGesture(
          dragPoint,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await tester.pump();
        expect(menuPosition, isNull);

        await gesture.up();
        await tester.pump();
        expect(menuPosition, dragPoint);
      },
    );

    testWidgets(
      'showSystemMenuOnRelease false fires on secondary pointer press',
      (tester) async {
        Offset? menuPosition;

        await tester.pumpWidget(
          buildTitleBar(onSystemMenu: (pos) => menuPosition = pos),
        );

        final barTopLeft = tester.getTopLeft(find.byType(HiveTitleBar));
        final dragPoint = barTopLeft + const Offset(40, 16);
        final gesture = await tester.startGesture(
          dragPoint,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await tester.pump();
        expect(menuPosition, dragPoint);

        menuPosition = null;
        await gesture.up();
        await tester.pump();
        expect(menuPosition, isNull);
      },
    );
  });
}
