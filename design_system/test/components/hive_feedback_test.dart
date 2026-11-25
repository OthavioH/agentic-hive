import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

/// A button that opens the confirm dialog and records the choice.
class _DialogLauncher extends StatelessWidget {
  const new({required this.onChoice, this.tone = HiveConfirmTone.standard});

  final ValueChanged<HiveConfirmChoice> onChoice;
  final HiveConfirmTone tone;

  @override
  Widget build(BuildContext context) {
    return HiveButton(
      label: 'Open',
      onPressed: () async {
        final choice = await showHiveConfirmDialog(
          context,
          title: 'Agent changed on disk',
          message: 'code-reviewer.md was edited outside the app.',
          confirmLabel: 'Overwrite',
          cancelLabel: 'Cancel',
          secondaryLabel: 'Reload from disk',
          tone: tone,
          icon: HiveIcons.alert,
        );
        onChoice(choice);
      },
    );
  }
}

void main() {
  group('HiveConfirmDialog', () {
    for (final entry in <String, HiveConfirmChoice>{
      'Overwrite': HiveConfirmChoice.confirm,
      'Reload from disk': HiveConfirmChoice.secondary,
      'Cancel': HiveConfirmChoice.cancel,
    }.entries) {
      testWidgets('"${entry.key}" completes with ${entry.value.name}', (
        tester,
      ) async {
        HiveConfirmChoice? choice;
        await tester.pumpWidget(
          hiveTestApp(child: _DialogLauncher(onChoice: (c) => choice = c)),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Agent changed on disk'), findsOneWidget);

        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();

        expect(choice, entry.value);
        expect(find.byType(HiveConfirmDialog), findsNothing);
      });
    }

    testWidgets('Escape cancels', (tester) async {
      HiveConfirmChoice? choice;
      await tester.pumpWidget(
        hiveTestApp(child: _DialogLauncher(onChoice: (c) => choice = c)),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(choice, HiveConfirmChoice.cancel);
    });

    testWidgets('destructive tone uses the danger button and focuses cancel', (
      tester,
    ) async {
      HiveConfirmChoice? choice;
      await tester.pumpWidget(
        hiveTestApp(
          child: _DialogLauncher(
            tone: HiveConfirmTone.destructive,
            onChoice: (c) => choice = c,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final confirm = tester.widget<HiveButton>(
        find.widgetWithText(HiveButton, 'Overwrite'),
      );
      expect(confirm.variant, HiveButtonVariant.danger);

      // Enter activates the focused (safe) button.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(choice, HiveConfirmChoice.cancel);
    });

    testWidgets('standard tone focuses confirm', (tester) async {
      HiveConfirmChoice? choice;
      await tester.pumpWidget(
        hiveTestApp(child: _DialogLauncher(onChoice: (c) => choice = c)),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(choice, HiveConfirmChoice.confirm);
    });

    testWidgets('uses the panel radius and names its route', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: Center(
            child: HiveConfirmDialog(
              title: 'Delete agent?',
              message: 'code-reviewer.md will be removed from disk.',
              confirmLabel: 'Delete',
              cancelLabel: 'Cancel',
              tone: HiveConfirmTone.destructive,
              onConfirm: () {},
              onCancel: () {},
            ),
          ),
        ),
      );

      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(HiveConfirmDialog),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.borderRadius, HiveRadii.standard.panel);
      expect(find.bySemanticsLabel('Delete agent?'), findsWidgets);
    });
  });

  group('HiveBanner', () {
    testWidgets('shows title, message, detail and actions', (tester) async {
      var reloaded = 0;
      var dismissed = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveBanner(
            tone: HiveFeedbackTone.danger,
            title: 'This agent could not be read',
            message: 'Fix the YAML frontmatter or delete the file.',
            detail: const Text('line 3: mapping values are not allowed'),
            actions: <Widget>[
              HiveButton(
                label: 'Reload',
                size: HiveButtonSize.small,
                variant: HiveButtonVariant.secondary,
                onPressed: () => reloaded++,
              ),
            ],
            onDismiss: () => dismissed++,
            dismissSemanticLabel: 'Dismiss',
          ),
        ),
      );

      expect(find.text('This agent could not be read'), findsOneWidget);
      expect(
        find.text('Fix the YAML frontmatter or delete the file.'),
        findsOneWidget,
      );
      expect(find.text('line 3: mapping values are not allowed'), findsOne);

      await tester.tap(find.text('Reload'));
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pump();
      expect(reloaded, 1);
      expect(dismissed, 1);
    });

    for (final tone in HiveFeedbackTone.values) {
      testWidgets('${tone.name} tone draws its border and icon badge', (
        tester,
      ) async {
        await tester.pumpWidget(
          hiveTestApp(
            child: HiveBanner(tone: tone, title: 'Agent saved'),
          ),
        );

        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(HiveBanner),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = box.decoration! as BoxDecoration;
        expect(
          (decoration.border! as Border).top.color,
          tone.color(HiveColors.dark),
        );
        expect(decoration.borderRadius, HiveRadii.standard.card);
        final badge = tester.widget<HiveToneBadge>(find.byType(HiveToneBadge));
        expect(badge.tone, tone);
        expect(badge.diameter, HiveSpacing.standard.space4);
        expect(box.padding, EdgeInsets.all(HiveSpacing.standard.space2));
        expect(find.byType(HiveIconButton), findsNothing);
      });
    }

    for (final tone in HiveFeedbackTone.values) {
      testWidgets('compact ${tone.name} uses space3 badge and space1 padding', (
        tester,
      ) async {
        await tester.pumpWidget(
          hiveTestApp(
            child: HiveBanner(
              tone: tone,
              density: HiveBannerDensity.compact,
              title: 'MCP server missing',
              message: 'Install the Hive MCP server.',
            ),
          ),
        );

        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(HiveBanner),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(box.padding, EdgeInsets.all(HiveSpacing.standard.space1));
        final decoration = box.decoration! as BoxDecoration;
        expect(
          (decoration.border! as Border).top.color,
          tone.color(HiveColors.dark),
        );
        expect(decoration.borderRadius, HiveRadii.standard.card);

        final badge = tester.widget<HiveToneBadge>(find.byType(HiveToneBadge));
        expect(badge.tone, tone);
        expect(badge.diameter, HiveSpacing.standard.space3);

        final constrained = tester.widget<ConstrainedBox>(
          find
              .ancestor(
                of: find.text('MCP server missing'),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(constrained.constraints.minHeight, HiveSpacing.standard.space3);

        final messageText = tester.widget<Text>(
          find.text('Install the Hive MCP server.'),
        );
        expect(
          messageText.style?.fontSize,
          HiveTypography.standard.bodySmall.fontSize,
        );
      });
    }

    testWidgets(
      'compact with message, action and dismiss does not overflow at 320px',
      (tester) async {
        await tester.pumpWidget(
          hiveTestApp(
            child: SizedBox(
              width: 320,
              child: HiveBanner(
                tone: HiveFeedbackTone.danger,
                density: HiveBannerDensity.compact,
                title: 'Could not install skill',
                message: 'Permission denied writing to ~/.claude/skills.',
                actions: <Widget>[
                  HiveButton(
                    label: 'Retry',
                    size: HiveButtonSize.small,
                    variant: HiveButtonVariant.secondary,
                    onPressed: () {},
                  ),
                ],
                onDismiss: () {},
                dismissSemanticLabel: 'Dismiss',
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('compact announces liveRegion when enabled', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(
            child: const HiveBanner(
              tone: HiveFeedbackTone.warning,
              density: HiveBannerDensity.compact,
              liveRegion: true,
              title: 'MCP server not installed',
            ),
          ),
        );

        final semantics = tester.getSemantics(find.byType(HiveBanner));
        expect(semantics.flagsCollection.isLiveRegion, isTrue);
      } finally {
        handle.dispose();
      }
    });
  });
}
