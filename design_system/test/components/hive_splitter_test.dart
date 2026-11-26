import 'dart:ui';

import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

const _label = 'Resize graph and inspector';
const _firstKey = ValueKey<String>('first');
const _secondKey = ValueKey<String>('second');

Widget _buildSplitter({
  double initialPosition = 0.5,
  Axis axis = Axis.horizontal,
  double width = 800,
  double height = 400,
  double? minFirst,
  double? minSecond,
  ValueChanged<double>? onChanged,
  WidgetStatesController? statesController,
  Widget? first,
  Widget? second,
}) {
  return hiveTestApp(
    child: Center(
      child: SizedBox(
        width: width,
        height: height,
        child: HiveSplitter(
          initialPosition: initialPosition,
          semanticLabel: _label,
          axis: axis,
          minFirst: minFirst,
          minSecond: minSecond,
          onChanged: onChanged,
          statesController: statesController,
          first:
              first ??
              const SizedBox.expand(
                key: _firstKey,
                child: ColoredBox(color: Color(0xFF111111)),
              ),
          second:
              second ??
              const SizedBox.expand(
                key: _secondKey,
                child: ColoredBox(color: Color(0xFF222222)),
              ),
        ),
      ),
    ),
  );
}

Finder _handleFinder() => find
    .descendant(
      of: find.byType(HiveSplitter),
      matching: find.byType(FocusableActionDetector),
    )
    .last;

void main() {
  group('HiveSplitter', () {
    testWidgets(
      'horizontal layout splits available extent and leaves space2 gap',
      (tester) async {
        await tester.pumpWidget(_buildSplitter());

        final firstSize = tester.getSize(find.byKey(_firstKey));
        final secondSize = tester.getSize(find.byKey(_secondKey));
        expect(firstSize.width, 392);
        expect(secondSize.width, 392);
        expect(firstSize.height, 400);
        expect(secondSize.height, 400);

        final gap =
            tester.getTopLeft(find.byKey(_secondKey)).dx -
            tester.getTopRight(find.byKey(_firstKey)).dx;
        expect(gap, HiveSpacing.standard.space2);
      },
    );

    testWidgets('drag updates pane width and reports new fraction', (
      tester,
    ) async {
      double? reported;
      await tester.pumpWidget(
        _buildSplitter(onChanged: (value) => reported = value),
      );

      await tester.drag(_handleFinder(), const Offset(100, 0));
      await tester.pump();

      final firstWidth = tester.getSize(find.byKey(_firstKey)).width;
      expect(firstWidth, greaterThan(392));
      expect(reported, isNotNull);
      expect(firstWidth, closeTo(reported! * 784, 1e-4));
    });

    testWidgets('multiple drag updates in the same frame accumulate deltas', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSplitter());

      final gesture = await tester.startGesture(
        tester.getCenter(_handleFinder()),
      );
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();

      final before = tester.getSize(find.byKey(_firstKey)).width;
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(10, 0));
      }
      await tester.pump();

      expect(tester.getSize(find.byKey(_firstKey)).width, before + 50);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('clamps drag to minFirst and minSecond', (tester) async {
      await tester.pumpWidget(_buildSplitter());

      await tester.drag(_handleFinder(), const Offset(-2000, 0));
      await tester.pump();
      expect(tester.getSize(find.byKey(_firstKey)).width, 256);

      await tester.drag(_handleFinder(), const Offset(2000, 0));
      await tester.pump();
      expect(tester.getSize(find.byKey(_secondKey)).width, 256);
    });

    testWidgets(
      're-clamps on container shrink and splits proportionally below minimums',
      (tester) async {
        await tester.pumpWidget(
          _buildSplitter(initialPosition: 0.9, width: 800),
        );
        expect(tester.getSize(find.byKey(_secondKey)).width, 256);

        await tester.pumpWidget(
          _buildSplitter(initialPosition: 0.9, width: 600),
        );
        expect(
          tester.getSize(find.byKey(_secondKey)).width,
          greaterThanOrEqualTo(256),
        );

        await tester.pumpWidget(
          _buildSplitter(initialPosition: 0.9, width: 400),
        );
        expect(tester.takeException(), isNull);
        final firstWidth = tester.getSize(find.byKey(_firstKey)).width;
        final secondWidth = tester.getSize(find.byKey(_secondKey)).width;
        expect(firstWidth, 192);
        expect(secondWidth, 192);
        expect(firstWidth, greaterThanOrEqualTo(0));
        expect(secondWidth, greaterThanOrEqualTo(0));
      },
    );

    testWidgets(
      'vertical axis splits height, drags vertically, and responds to keys',
      (tester) async {
        await tester.pumpWidget(
          _buildSplitter(
            axis: Axis.vertical,
            width: 400,
            height: 560,
            minFirst: 100,
            minSecond: 100,
          ),
        );

        expect(tester.getSize(find.byKey(_firstKey)).height, 272);
        expect(tester.getSize(find.byKey(_secondKey)).height, 272);

        await tester.drag(_handleFinder(), const Offset(0, 80));
        await tester.pump();
        final afterDrag = tester.getSize(find.byKey(_firstKey)).height;
        expect(afterDrag, greaterThan(272));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(tester.getSize(find.byKey(_firstKey)).height, afterDrag + 16);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(tester.getSize(find.byKey(_firstKey)).height, afterDrag);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(tester.getSize(find.byKey(_firstKey)).height, afterDrag);
      },
    );

    testWidgets(
      'horizontal keyboard arrows nudge by space2 and respect minimums',
      (tester) async {
        double? reported;
        await tester.pumpWidget(
          _buildSplitter(onChanged: (value) => reported = value),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(tester.getSize(find.byKey(_firstKey)).width, 392 + 16);
        expect(reported, closeTo((392 + 16) / 784, 1e-6));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(tester.getSize(find.byKey(_firstKey)).width, 392);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(tester.getSize(find.byKey(_firstKey)).width, 392);

        await tester.drag(_handleFinder(), const Offset(-2000, 0));
        await tester.pump();
        expect(tester.getSize(find.byKey(_firstKey)).width, 256);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(tester.getSize(find.byKey(_firstKey)).width, 256);
      },
    );

    testWidgets(
      'focus order visits first pane, then handle, then second pane',
      (tester) async {
        await tester.pumpWidget(
          _buildSplitter(
            first: SizedBox.expand(
              key: _firstKey,
              child: Center(
                child: HiveButton(label: 'First action', onPressed: () {}),
              ),
            ),
            second: SizedBox.expand(
              key: _secondKey,
              child: Center(
                child: HiveButton(label: 'Second action', onPressed: () {}),
              ),
            ),
          ),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final firstFocus = FocusManager.instance.primaryFocus!.context!;
        expect(
          find.ancestor(
            of: find.byWidget(firstFocus.widget),
            matching: find.byKey(_firstKey),
          ),
          findsOneWidget,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final ring = tester.widget<HiveFocusRing>(
          find.descendant(
            of: _handleFinder(),
            matching: find.byType(HiveFocusRing),
          ),
        );
        expect(ring.focused, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final secondFocus = FocusManager.instance.primaryFocus!.context!;
        expect(
          find.ancestor(
            of: find.byWidget(secondFocus.widget),
            matching: find.byKey(_secondKey),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('focus ring shows only when handle has keyboard focus', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSplitter());

      HiveFocusRing ring() => tester.widget<HiveFocusRing>(
        find.descendant(
          of: find.byType(HiveSplitter),
          matching: find.byType(HiveFocusRing),
        ),
      );

      expect(ring().focused, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring().focused, isTrue);
    });

    testWidgets('grip color reflects idle, hovered, and pressed states', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      final controller = WidgetStatesController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_buildSplitter(statesController: controller));

      Color gripColor() {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(HiveFocusRing),
            matching: find.byType(DecoratedBox),
          ),
        );
        return (box.decoration as BoxDecoration).color!;
      }

      expect(gripColor(), HiveColors.dark.borderStrong);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(_handleFinder()));
      await tester.pumpAndSettle();
      expect(controller.value, contains(WidgetState.hovered));
      expect(gripColor(), HiveColors.dark.onSurfaceMuted);

      controller.value = <WidgetState>{WidgetState.pressed};
      await tester.pump();
      expect(gripColor(), HiveColors.dark.onSurface);
    });

    testWidgets(
      'uses resizeColumn cursor for horizontal and resizeRow for vertical',
      (tester) async {
        await tester.pumpWidget(_buildSplitter());
        expect(
          tester.widget<FocusableActionDetector>(_handleFinder()).mouseCursor,
          SystemMouseCursors.resizeColumn,
        );

        await tester.pumpWidget(_buildSplitter(axis: Axis.vertical));
        expect(
          tester.widget<FocusableActionDetector>(_handleFinder()).mouseCursor,
          SystemMouseCursors.resizeRow,
        );
      },
    );

    testWidgets('exposes slider semantics and meets tap target guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        double? reported;
        await tester.pumpWidget(
          _buildSplitter(onChanged: (value) => reported = value),
        );

        final node = tester.getSemantics(find.bySemanticsLabel(_label));
        expect(
          node,
          matchesSemantics(
            label: _label,
            value: '50%',
            isSlider: true,
            isFocusable: true,
            hasIncreaseAction: true,
            hasDecreaseAction: true,
            increasedValue: '52%',
            decreasedValue: '48%',
          ),
        );

        tester.semantics.performAction(
          find.semantics.byLabel(_label),
          SemanticsAction.increase,
        );
        await tester.pump();
        expect(reported, closeTo((392 + 16) / 784, 1e-6));
        expect(tester.getSemantics(find.bySemanticsLabel(_label)).value, '52%');

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('drag resizes without throwing when onChanged is null', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSplitter());
      await tester.drag(_handleFinder(), const Offset(80, 0));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(_firstKey)).width, greaterThan(392));
    });
  });
}
