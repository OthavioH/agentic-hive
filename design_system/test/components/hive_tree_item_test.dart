import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  group('HiveTreeItem', () {
    testWidgets(
      'renders label, subtitle, leading and trailing, and activates on tap',
      (tester) async {
        var pressed = 0;
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          hiveTestApp(
            child: SizedBox(
              width: 280,
              child: HiveTreeItem(
                label: 'agentic-hive',
                subtitle: 'feature/workspaces',
                leading: const HiveStatusDot(
                  status: HiveNodeStatus.running,
                  semanticLabel: 'Running',
                ),
                trailing: const HiveBadge(label: 'primary'),
                onPressed: () => pressed++,
              ),
            ),
          ),
        );

        expect(find.text('agentic-hive'), findsOneWidget);
        expect(find.text('feature/workspaces'), findsOneWidget);
        expect(find.byType(HiveStatusDot), findsOneWidget);
        expect(find.text('primary'), findsOneWidget);
        expect(find.bySemanticsLabel('agentic-hive'), findsOneWidget);

        await tester.tap(find.text('agentic-hive'));
        await tester.pump();
        expect(pressed, 1);

        handle.dispose();
      },
    );

    testWidgets('activates with keyboard Enter and Space', (tester) async {
      var pressed = 0;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        hiveTestApp(
          child: SizedBox(
            width: 280,
            child: HiveTreeItem(
              label: 'Run #42',
              focusNode: focusNode,
              onPressed: () => pressed++,
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(pressed, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(pressed, 2);
    });

    testWidgets(
      'shows chevron when expanded is non-null and toggles independently',
      (tester) async {
        var pressed = 0;
        var toggled = 0;
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          hiveTestApp(
            child: SizedBox(
              width: 280,
              child: HiveTreeItem(
                label: 'agentic-hive',
                expanded: false,
                onToggleExpand: () => toggled++,
                onPressed: () => pressed++,
              ),
            ),
          ),
        );

        final rotation = tester.widget<AnimatedRotation>(
          find.byType(AnimatedRotation),
        );
        expect(rotation.turns, -0.25);
        expect(find.bySemanticsLabel('Expand agentic-hive'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Expand agentic-hive'));
        await tester.pump();
        expect(toggled, 1);
        expect(pressed, 0);

        await tester.pumpWidget(
          hiveTestApp(
            child: SizedBox(
              width: 280,
              child: HiveTreeItem(
                label: 'agentic-hive',
                expanded: true,
                onToggleExpand: () => toggled++,
                onPressed: () => pressed++,
              ),
            ),
          ),
        );

        final expandedRotation = tester.widget<AnimatedRotation>(
          find.byType(AnimatedRotation),
        );
        expect(expandedRotation.turns, 0);
        expect(find.bySemanticsLabel('Collapse agentic-hive'), findsOneWidget);

        handle.dispose();
      },
    );

    testWidgets('hides chevron when expanded is null', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: SizedBox(
            width: 280,
            child: HiveTreeItem(label: 'Run #1', onPressed: () {}),
          ),
        ),
      );

      expect(find.byType(AnimatedRotation), findsNothing);
    });

    testWidgets('respects MediaQuery.disableAnimations for chevron rotation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: hiveTestApp(
            child: SizedBox(
              width: 280,
              child: HiveTreeItem(
                label: 'agentic-hive',
                expanded: false,
                onToggleExpand: () {},
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final rotation = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(rotation.duration, Duration.zero);
    });

    testWidgets('indents content by indentLevel * space2', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                HiveTreeItem(label: 'Level 0', onPressed: () {}),
                HiveTreeItem(
                  label: 'Level 1',
                  indentLevel: 1,
                  onPressed: () {},
                ),
                HiveTreeItem(
                  label: 'Level 2',
                  indentLevel: 2,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final x0 = tester.getTopLeft(find.text('Level 0')).dx;
      final x1 = tester.getTopLeft(find.text('Level 1')).dx;
      final x2 = tester.getTopLeft(find.text('Level 2')).dx;
      final step = HiveSpacing.standard.space2;

      expect(x1 - x0, step);
      expect(x2 - x1, step);
    });

    for (final entry in <String, ThemeData>{
      'dark': HiveTheme.dark(),
      'light': HiveTheme.light(),
    }.entries) {
      final themeName = entry.key;
      final theme = entry.value;
      final colors = theme.extension<HiveColors>()!;

      testWidgets('paints selected state in $themeName theme', (tester) async {
        await tester.pumpWidget(
          hiveTestApp(
            theme: theme,
            child: SizedBox(
              width: 280,
              child: HiveTreeItem(
                label: 'Selected item',
                selected: true,
                onPressed: () {},
              ),
            ),
          ),
        );

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decoration = container.decoration! as ShapeDecoration;
        expect(decoration.color, colors.surface3);
      });

      testWidgets(
        'paints highlighted (pending pause) state in $themeName theme',
        (tester) async {
          await tester.pumpWidget(
            hiveTestApp(
              theme: theme,
              child: SizedBox(
                width: 280,
                child: HiveTreeItem(
                  label: 'Paused run',
                  highlighted: true,
                  onPressed: () {},
                ),
              ),
            ),
          );

          final container = tester.widget<AnimatedContainer>(
            find.byType(AnimatedContainer),
          );
          final decoration = container.decoration! as ShapeDecoration;
          final shape = decoration.shape as StadiumBorder;
          expect(shape.side.color, colors.warning);
          expect(shape.side.width, theme.extension<HiveElevation>()!.hairline);

          final label = tester.widget<Text>(find.text('Paused run'));
          expect(label.style?.color, colors.onSurface);
        },
      );
    }

    testWidgets(
      'applies disabled opacity when onPressed and onToggleExpand are null',
      (tester) async {
        await tester.pumpWidget(
          hiveTestApp(
            child: const SizedBox(
              width: 280,
              child: HiveTreeItem(label: 'Disabled item', onPressed: null),
            ),
          ),
        );

        final opacity = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacity.opacity, HiveColors.dark.disabledOpacity);
      },
    );
  });
}
