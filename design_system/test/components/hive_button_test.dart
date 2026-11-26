import 'dart:ui';

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

      // The spinner is the only painter inside the label row (the focus
      // ring's painter wraps the whole pill).
      expect(
        find.descendant(
          of: find.byType(Row),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

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

    testWidgets('dangerHover uses danger/onDanger on hover and pressed', (
      tester,
    ) async {
      final controller = WidgetStatesController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        hiveTestApp(
          child: HiveIconButton.dangerHover(
            icon: HiveIcons.close,
            semanticLabel: 'Close to tray',
            statesController: controller,
            onPressed: () {},
          ),
        ),
      );

      const colors = HiveColors.dark;
      ShapeDecoration decoration() =>
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: find.byType(HiveIconButton),
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as ShapeDecoration;

      HiveIcon iconWidget() => tester.widget<HiveIcon>(
        find.descendant(
          of: find.byType(HiveIconButton),
          matching: find.byType(HiveIcon),
        ),
      );

      // Resting: transparent background, onSurface icon, CircleBorder.
      expect(decoration().color, colors.background.withValues(alpha: 0));
      expect(decoration().shape, isA<CircleBorder>());
      expect(iconWidget().color, colors.onSurface);
      expect(find.bySemanticsLabel('Close to tray'), findsOneWidget);

      // Hovered: danger background, onDanger icon.
      controller.update(WidgetState.hovered, true);
      await tester.pump();
      expect(decoration().color, colors.danger);
      expect(iconWidget().color, colors.onDanger);

      // Pressed: pressed state layer over danger, onDanger icon.
      controller.update(WidgetState.pressed, true);
      await tester.pump();
      expect(
        decoration().color,
        Color.alphaBlend(
          colors.onDanger.withValues(alpha: colors.pressedOpacity),
          colors.danger,
        ),
      );
      expect(iconWidget().color, colors.onDanger);
    });

    testWidgets('dangerHover uses light theme danger/onDanger on hover', (
      tester,
    ) async {
      final controller = WidgetStatesController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        hiveTestApp(
          theme: HiveTheme.light(),
          child: HiveIconButton.dangerHover(
            icon: HiveIcons.close,
            semanticLabel: 'Close window',
            statesController: controller,
            onPressed: () {},
          ),
        ),
      );

      const colors = HiveColors.light;
      ShapeDecoration decoration() =>
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: find.byType(HiveIconButton),
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as ShapeDecoration;

      HiveIcon iconWidget() => tester.widget<HiveIcon>(
        find.descendant(
          of: find.byType(HiveIconButton),
          matching: find.byType(HiveIcon),
        ),
      );

      expect(decoration().color, colors.background.withValues(alpha: 0));
      expect(iconWidget().color, colors.onSurface);

      controller.update(WidgetState.hovered, true);
      await tester.pump();
      expect(decoration().color, colors.danger);
      expect(iconWidget().color, colors.onDanger);
    });

    testWidgets('dangerHover keeps ghost look when disabled', (tester) async {
      final controller = WidgetStatesController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        hiveTestApp(
          child: HiveIconButton.dangerHover(
            icon: HiveIcons.close,
            semanticLabel: 'Close disabled',
            statesController: controller,
            onPressed: null,
          ),
        ),
      );

      const colors = HiveColors.dark;
      ShapeDecoration decoration() =>
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: find.byType(HiveIconButton),
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as ShapeDecoration;

      HiveIcon iconWidget() => tester.widget<HiveIcon>(
        find.descendant(
          of: find.byType(HiveIconButton),
          matching: find.byType(HiveIcon),
        ),
      );

      expect(find.bySemanticsLabel('Close disabled'), findsOneWidget);
      expect(decoration().color, colors.background.withValues(alpha: 0));
      expect(iconWidget().color, colors.onSurface);

      controller
        ..update(WidgetState.hovered, true)
        ..update(WidgetState.pressed, true);
      await tester.pump();
      expect(decoration().color, colors.background.withValues(alpha: 0));
      expect(iconWidget().color, colors.onSurface);
    });

    testWidgets('window caption icons render and are listed in interface', (
      tester,
    ) async {
      expect(HiveIcons.interface['minimize'], HiveIcons.minimize);
      expect(HiveIcons.interface['maximize'], HiveIcons.maximize);
      expect(HiveIcons.interface['restore'], HiveIcons.restore);

      await tester.pumpWidget(
        hiveTestApp(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HiveIcon(HiveIcons.minimize, semanticLabel: 'Minimize'),
              HiveIcon(HiveIcons.maximize, semanticLabel: 'Maximize'),
              HiveIcon(HiveIcons.restore, semanticLabel: 'Restore'),
            ],
          ),
        ),
      );

      expect(find.byType(HiveIcon), findsNWidgets(3));
      expect(find.bySemanticsLabel('Minimize'), findsOneWidget);
      expect(find.bySemanticsLabel('Maximize'), findsOneWidget);
      expect(find.bySemanticsLabel('Restore'), findsOneWidget);
    });

    testWidgets('move icons render and are listed in interface', (
      tester,
    ) async {
      expect(HiveIcons.interface['moveUp'], HiveIcons.moveUp);
      expect(HiveIcons.interface['moveDown'], HiveIcons.moveDown);

      await tester.pumpWidget(
        hiveTestApp(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HiveIcon(HiveIcons.moveUp, semanticLabel: 'Move up'),
              HiveIcon(HiveIcons.moveDown, semanticLabel: 'Move down'),
            ],
          ),
        ),
      );

      expect(find.byType(HiveIcon), findsNWidgets(2));
      expect(find.bySemanticsLabel('Move up'), findsOneWidget);
      expect(find.bySemanticsLabel('Move down'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled button announces disabledReason as its hint', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        const reason = 'Unavailable while the workflow is being deleted.';
        await tester.pumpWidget(
          hiveTestApp(
            child: const HiveIconButton(
              icon: HiveIcons.copy,
              semanticLabel: 'Duplicate workflow',
              onPressed: null,
              disabledReason: reason,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.bySemanticsLabel('Duplicate workflow')),
          isSemantics(
            label: 'Duplicate workflow',
            hint: reason,
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('disabled button shows disabledReason in a tooltip on hover', (
      tester,
    ) async {
      const reason = 'Unavailable while the workflow is being deleted.';
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveIconButton(
            icon: HiveIcons.copy,
            semanticLabel: 'Duplicate workflow',
            onPressed: null,
            disabledReason: reason,
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(HiveIconButton)));
      await tester.pump(HiveMotionTokens.standard.long);
      await tester.pumpAndSettle();

      expect(find.text(reason), findsOneWidget);
    });

    testWidgets('the tooltip adds no semantics node', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        const reason = 'Unavailable while the workflow is being deleted.';
        await tester.pumpWidget(
          hiveTestApp(
            child: const HiveIconButton(
              icon: HiveIcons.copy,
              semanticLabel: 'Duplicate workflow',
              onPressed: null,
              disabledReason: reason,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel(reason), findsNothing);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('tooltip uses surface3, onSurface bodySmall and a pill', (
      tester,
    ) async {
      const reason = 'Unavailable while the workflow is being deleted.';
      for (final theme in <ThemeData>[HiveTheme.dark(), HiveTheme.light()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: Center(
                child: HiveIconButton(
                  icon: HiveIcons.copy,
                  semanticLabel: 'Duplicate workflow',
                  onPressed: null,
                  disabledReason: reason,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final colors = theme.extension<HiveColors>()!;
        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        final decoration = tooltip.decoration! as ShapeDecoration;
        expect(decoration.color, colors.surface3);
        expect(decoration.shape, isA<StadiumBorder>());
        final border = decoration.shape as StadiumBorder;
        expect(border.side.color, colors.borderSubtle);
        expect(tooltip.textStyle!.color, colors.onSurface);
      }
    });

    testWidgets('enabled button ignores disabledReason', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        const reason = 'Unavailable while the workflow is being deleted.';
        for (final loading in <bool>[false, true]) {
          await tester.pumpWidget(
            hiveTestApp(
              child: HiveIconButton(
                icon: HiveIcons.copy,
                semanticLabel: 'Duplicate workflow',
                onPressed: () {},
                loading: loading,
                disabledReason: reason,
              ),
            ),
          );

          expect(find.byType(Tooltip), findsNothing);
          expect(
            tester
                .getSemantics(find.bySemanticsLabel('Duplicate workflow'))
                .hint,
            isEmpty,
          );
        }
      } finally {
        handle.dispose();
      }
    });

    testWidgets('dangerHover accepts disabledReason', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveIconButton.dangerHover(
            icon: HiveIcons.close,
            semanticLabel: 'Close',
            onPressed: null,
            disabledReason: 'Unavailable',
          ),
        ),
      );

      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('tooltip waits zero when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: HiveIconButton(
              icon: HiveIcons.copy,
              semanticLabel: 'Duplicate workflow',
              onPressed: null,
              disabledReason: 'Unavailable',
            ),
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.waitDuration, Duration.zero);
    });
  });
}
