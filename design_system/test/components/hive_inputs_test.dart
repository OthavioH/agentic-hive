import 'package:design_system/design_system.dart';
import 'package:design_system/src/foundation/hive_text_input.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

ShapeDecoration _wellDecoration(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find
        .descendant(
          of: find.byType(HiveTextField),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return container.decoration! as ShapeDecoration;
}

Color _borderColor(WidgetTester tester) =>
    (_wellDecoration(tester).shape as OutlinedBorder).side.color;

bool _hasFocusRing(WidgetTester tester, Finder of) {
  return tester
      .widgetList<HiveFocusRing>(
        find.descendant(of: of, matching: find.byType(HiveFocusRing)),
      )
      .any((ring) => ring.focused);
}

void main() {
  group('HiveTextField', () {
    testWidgets('edits text, reports changes and submits', (tester) async {
      final changes = <String>[];
      String? submitted;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveTextField(
            label: 'Name',
            hintText: 'Code reviewer',
            onChanged: changes.add,
            onSubmitted: (value) => submitted = value,
          ),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Code reviewer'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Release manager');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(changes.last, 'Release manager');
      expect(submitted, 'Release manager');
    });

    testWidgets('exposes the label as its semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveTextField(
            semanticLabel: 'Search agents',
            leadingIcon: HiveIcons.search,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(TextField)),
        matchesSemantics(
          label: 'Search agents',
          isTextField: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('shows the focus ring while focused', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveTextField(label: 'Description')),
      );
      expect(_hasFocusRing(tester, find.byType(HiveTextField)), isFalse);

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(_hasFocusRing(tester, find.byType(HiveTextField)), isTrue);
    });

    testWidgets('changes the fill on hover', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveTextField(label: 'Name')),
      );
      final resting = _wellDecoration(tester).color;

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(TextField)));
      await tester.pumpAndSettle();

      expect(_wellDecoration(tester).color, isNot(resting));
    });

    testWidgets('error state shows the message and a danger border', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveTextField(
            label: 'Agent id',
            helperText: 'Lowercase letters, digits, - and _',
            errorText: 'An agent with this id already exists',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('An agent with this id already exists'), findsOneWidget);
      expect(find.text('Lowercase letters, digits, - and _'), findsNothing);
      expect(_borderColor(tester), HiveColors.dark.danger);
    });

    testWidgets('disabled field ignores input', (tester) async {
      final controller = TextEditingController(text: 'code-reviewer');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveTextField(
            label: 'Agent id',
            controller: controller,
            enabled: false,
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
      expect(controller.text, 'code-reviewer');
    });
  });

  group('HiveTextArea', () {
    testWidgets('accepts multi-line text in the mono role', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveTextArea(
            label: 'Prompt',
            mono: true,
            controller: controller,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '# Role\n\nReview PRs.');
      await tester.pump();

      expect(controller.text, '# Role\n\nReview PRs.');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.fontFamily, contains(HiveFontFamilies.mono));
      expect(field.keyboardType, TextInputType.multiline);
      expect(field.maxLines, isNull);
    });

    testWidgets('uses the body role by default', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveTextArea(label: 'Description')),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.fontFamily, contains(HiveFontFamilies.ui));
      expect(field.minLines, 4);
    });

    testWidgets('expands to fill its parent', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const SizedBox(
            height: 320,
            child: HiveTextArea(semanticLabel: 'Prompt', expands: true),
          ),
        ),
      );

      expect(tester.getSize(find.byType(HiveTextInput)).height, 320);
      expect(tester.widget<TextField>(find.byType(TextField)).expands, isTrue);
    });
  });

  group('HiveChip', () {
    testWidgets('removable chip calls onRemoved from its button', (
      tester,
    ) async {
      var removed = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: Center(
            child: HiveChip.removable(
              label: 'review',
              removeSemanticLabel: 'Remove tag review',
              onRemoved: () => removed++,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('review'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Remove tag review'));
      await tester.pump();

      expect(removed, 1);
    });

    testWidgets('removable chip removes with Backspace when focused', (
      tester,
    ) async {
      var removed = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: Center(
            child: HiveChip.removable(
              label: 'git',
              removeSemanticLabel: 'Remove tool git',
              onRemoved: () => removed++,
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(removed, 1);
    });

    testWidgets('removable chip without onRemoved has no button', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const Center(
            child: HiveChip.removable(
              label: 'review',
              removeSemanticLabel: 'Remove tag review',
              onRemoved: null,
            ),
          ),
        ),
      );

      expect(find.byType(HiveInteraction), findsNothing);
    });

    testWidgets('filter chip toggles and announces selection', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        hiveTestApp(
          child: StatefulBuilder(
            builder: (context, setState) => Center(
              child: HiveChip.filter(
                label: 'backend',
                selected: selected,
                onSelected: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(HiveIcon), findsNothing);
      await tester.tap(find.text('backend'));
      await tester.pump();
      expect(selected, isTrue);
      expect(find.byType(HiveIcon), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(HiveChipFilter)),
        matchesSemantics(
          label: 'backend',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(selected, isFalse);
    });

    testWidgets('disabled filter chip ignores taps', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const Center(
            child: HiveChip.filter(
              label: 'backend',
              selected: false,
              onSelected: null,
            ),
          ),
        ),
      );

      await tester.tap(find.text('backend'));
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(HiveChipFilter)),
        matchesSemantics(
          label: 'backend',
          isButton: true,
          hasSelectedState: true,
          hasEnabledState: true,
        ),
      );
    });
  });

  group('HiveSegmentedControl', () {
    const segments = <HiveSegment<String>>[
      HiveSegment<String>(value: 'raw', label: 'Raw'),
      HiveSegment<String>(value: 'preview', label: 'Preview'),
    ];

    testWidgets('reports the chosen segment', (tester) async {
      var value = 'raw';
      await tester.pumpWidget(
        hiveTestApp(
          child: StatefulBuilder(
            builder: (context, setState) => Center(
              child: HiveSegmentedControl<String>(
                segments: segments,
                selected: value,
                semanticLabel: 'Prompt view',
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Preview'));
      await tester.pump();

      expect(value, 'preview');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Preview')),
        matchesSemantics(
          label: 'Preview',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('Prompt view'), findsOneWidget);
    });

    testWidgets('activates a segment with the keyboard', (tester) async {
      var value = 'raw';
      await tester.pumpWidget(
        hiveTestApp(
          child: StatefulBuilder(
            builder: (context, setState) => Center(
              child: HiveSegmentedControl<String>(
                segments: segments,
                selected: value,
                semanticLabel: 'Prompt view',
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(value, 'preview');
    });

    testWidgets('disabled control ignores taps', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const Center(
            child: HiveSegmentedControl<String>(
              segments: segments,
              selected: 'raw',
              semanticLabel: 'Prompt view',
              onChanged: null,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Preview'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
