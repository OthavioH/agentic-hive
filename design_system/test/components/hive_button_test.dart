import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  group('HiveButton', () {
    testWidgets('fires onPressed when enabled', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveButton(label: 'Run workflow', onPressed: () => tapped++),
        ),
      );

      await tester.tap(find.text('Run workflow'));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('ignores taps when disabled (onPressed is null)', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveButton(label: 'Disabled', onPressed: null),
        ),
      );

      await tester.tap(find.text('Disabled'));
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(HiveButton));
      expect(semantics.label, 'Disabled');
    });

    testWidgets('shows spinner and ignores taps when loading', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveButton(
            label: 'Saving',
            loading: true,
            onPressed: () => tapped++,
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);

      await tester.tap(find.text('Saving'));
      await tester.pump();

      expect(tapped, 0);
    });

    testWidgets('activates via keyboard Enter when focused', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveButton(
            label: 'Confirm',
            autofocus: true,
            onPressed: () => tapped++,
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('uses custom semanticLabel when provided', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveButton(
            label: 'Run',
            semanticLabel: 'Run selected workflow',
            onPressed: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('Run selected workflow'), findsOneWidget);
    });
  });

  group('HiveIconButton', () {
    testWidgets('fires onPressed when enabled and exposes semanticLabel', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveIconButton(
            icon: HiveIcons.settings,
            semanticLabel: 'Open settings',
            onPressed: () => tapped++,
          ),
        ),
      );

      expect(find.bySemanticsLabel('Open settings'), findsOneWidget);

      await tester.tap(find.byType(HiveIconButton));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('ignores taps when disabled', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveIconButton(
            icon: HiveIcons.settings,
            semanticLabel: 'Disabled settings',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(find.byType(HiveIconButton));
      await tester.pump();

      expect(find.bySemanticsLabel('Disabled settings'), findsOneWidget);
    });

    testWidgets('shows a spinner and ignores taps and keys when loading', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveIconButton(
            icon: HiveIcons.refresh,
            semanticLabel: 'Re-check Claude Code',
            loading: true,
            autofocus: true,
            onPressed: () => tapped++,
          ),
        ),
      );
      await tester.pump();

      final inButton = find.byType(HiveIconButton);
      expect(
        find.descendant(of: inButton, matching: find.byType(HiveIcon)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: inButton,
          matching: find.byType(RotationTransition),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Re-check Claude Code'), findsOneWidget);

      await tester.tap(inButton);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tapped, 0);
    });

    testWidgets('restores the icon and activation after loading', (
      tester,
    ) async {
      var tapped = 0;
      Widget button({required bool loading}) => hiveTestApp(
        child: HiveIconButton(
          icon: HiveIcons.refresh,
          semanticLabel: 'Re-check Codex',
          loading: loading,
          onPressed: () => tapped++,
        ),
      );

      await tester.pumpWidget(button(loading: true));
      await tester.pumpWidget(button(loading: false));

      expect(
        find.descendant(
          of: find.byType(HiveIconButton),
          matching: find.byType(HiveIcon),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(HiveIconButton));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('keeps its diameter while loading', (tester) async {
      Widget button({required bool loading}) => hiveTestApp(
        child: Center(
          child: HiveIconButton(
            icon: HiveIcons.refresh,
            semanticLabel: 'Re-check Gemini CLI',
            loading: loading,
            onPressed: () {},
          ),
        ),
      );

      await tester.pumpWidget(button(loading: false));
      final resting = tester.getSize(find.byType(HiveIconButton));
      await tester.pumpWidget(button(loading: true));

      expect(tester.getSize(find.byType(HiveIconButton)), resting);
    });
  });
}
