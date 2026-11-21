import 'dart:ui' show Tristate;

import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

ShapeDecoration _decoration(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find
        .descendant(
          of: find.byType(HiveFilterChip),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return container.decoration! as ShapeDecoration;
}

void main() {
  group('HiveFilterChip', () {
    testWidgets('unselected chip sits on surface2 with a hairline pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveFilterChip(
            label: 'Failed',
            selected: false,
            onSelected: (_) {},
          ),
        ),
      );

      final decoration = _decoration(tester);
      expect(decoration.color, HiveColors.dark.surface2);
      final shape = decoration.shape as StadiumBorder;
      expect(shape.side.color, HiveColors.dark.borderSubtle);
      final text = tester.widget<Text>(find.text('Failed'));
      expect(text.style?.color, HiveColors.dark.onSurface);
    });

    testWidgets('selected chip fills with accent and onAccent text', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveFilterChip(
            label: 'Failed',
            selected: true,
            onSelected: (_) {},
          ),
        ),
      );

      expect(_decoration(tester).color, HiveColors.dark.accent);
      final text = tester.widget<Text>(find.text('Failed'));
      expect(text.style?.color, HiveColors.dark.onAccent);
    });

    testWidgets('tap reports the toggled selection', (tester) async {
      final reported = <bool>[];
      var selected = false;
      await tester.pumpWidget(
        hiveTestApp(
          child: StatefulBuilder(
            builder: (context, setState) => HiveFilterChip(
              label: 'Running',
              selected: selected,
              onSelected: (value) {
                reported.add(value);
                setState(() => selected = value);
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(HiveFilterChip));
      await tester.pump();
      await tester.tap(find.byType(HiveFilterChip));
      await tester.pump();

      expect(reported, <bool>[true, false]);
    });

    testWidgets('Enter and Space toggle the focused chip', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final reported = <bool>[];
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveFilterChip(
            label: 'Paused',
            selected: false,
            focusNode: focusNode,
            onSelected: reported.add,
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(reported, <bool>[true, true]);
    });

    testWidgets('null onSelected disables the chip and ignores taps', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveFilterChip(
            label: 'Cancelled',
            selected: false,
            onSelected: null,
          ),
        ),
      );

      await tester.tap(find.byType(HiveFilterChip), warnIfMissed: false);
      await tester.pump();

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(HiveFilterChip),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, HiveColors.dark.disabledOpacity);
      final data = tester
          .getSemantics(find.bySemanticsLabel('Cancelled'))
          .getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('announces label, selection and count', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveFilterChip(
            label: 'Failed',
            selected: true,
            count: 3,
            leading: const HiveStatusDot(
              status: HiveNodeStatus.failed,
              semanticLabel: 'Failed status',
            ),
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.byType(HiveStatusDot), findsOneWidget);
      // The leading glyph's own label is excluded; the chip is one node.
      expect(find.bySemanticsLabel('Failed status'), findsNothing);
      final data = tester
          .getSemantics(find.bySemanticsLabel('Failed'))
          .getSemanticsData();
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.value, '3');
      handle.dispose();
    });

    testWidgets('unselected chip reports isSelected false', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveFilterChip(
            label: 'Succeeded',
            semanticLabel: 'Show succeeded events',
            selected: false,
            onSelected: (_) {},
          ),
        ),
      );

      final data = tester
          .getSemantics(find.bySemanticsLabel('Show succeeded events'))
          .getSemanticsData();
      expect(data.flagsCollection.isSelected, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('hover adds a state layer and focus draws the ring', (
      tester,
    ) async {
      final controller = WidgetStatesController(<WidgetState>{
        WidgetState.hovered,
        WidgetState.focused,
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveFilterChip(
            label: 'Running',
            selected: false,
            statesController: controller,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_decoration(tester).color, isNot(HiveColors.dark.surface2));
      expect(
        tester.widget<HiveFocusRing>(find.byType(HiveFocusRing)).focused,
        isTrue,
      );
    });

    testWidgets('long label ellipsizes inside a narrow width', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: Center(
            child: SizedBox(
              width: 120,
              child: HiveFilterChip(
                label: 'Waiting for approval from the release owner',
                selected: false,
                count: 128,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('128'), findsOneWidget);
    });
  });
}
