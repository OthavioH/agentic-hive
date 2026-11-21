import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

/// A button that runs [onOpen] with a context below the app's navigator.
Widget _launcher(Future<void> Function(BuildContext context) onOpen) {
  return hiveTestApp(
    child: Builder(
      builder: (context) => HiveButton(
        label: 'Delete workflow',
        onPressed: () => onOpen(context),
      ),
    ),
  );
}

Future<bool?> _confirm(WidgetTester tester, {bool destructive = true}) async {
  bool? result;
  await tester.pumpWidget(
    _launcher((context) async {
      result = await HiveDialog.confirm(
        context: context,
        title: 'Delete "Release checklist"?',
        message: 'The workflow and its layout are removed for good.',
        confirmLabel: 'Delete',
        cancelLabel: 'Cancel',
        destructive: destructive,
      );
    }),
  );
  await tester.tap(find.text('Delete workflow'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('HiveDialog.confirm', () {
    testWidgets('shows title, message and both actions', (tester) async {
      await _confirm(tester);

      expect(find.text('Delete "Release checklist"?'), findsOneWidget);
      expect(
        find.text('The workflow and its layout are removed for good.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('completes true on confirm', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _launcher((context) async {
          result = await HiveDialog.confirm(
            context: context,
            title: 'Discard unsaved changes?',
            confirmLabel: 'Discard',
            cancelLabel: 'Keep editing',
            destructive: true,
          );
        }),
      );
      await tester.tap(find.text('Delete workflow'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Discard unsaved changes?'), findsNothing);
    });

    testWidgets('completes false on cancel, scrim tap and Escape', (
      tester,
    ) async {
      final results = <bool>[];
      await tester.pumpWidget(
        _launcher((context) async {
          results.add(
            await HiveDialog.confirm(
              context: context,
              title: 'Discard unsaved changes?',
              confirmLabel: 'Discard',
              cancelLabel: 'Keep editing',
            ),
          );
        }),
      );

      Future<void> open() async {
        await tester.tap(find.text('Delete workflow'));
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
      }

      await open();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      await open();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      await open();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(results, <bool>[false, false, false]);
      expect(find.text('Discard unsaved changes?'), findsNothing);
    });

    testWidgets('focuses the confirm action so Enter confirms', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _launcher((context) async {
          result = await HiveDialog.confirm(
            context: context,
            title: 'Discard unsaved changes?',
            confirmLabel: 'Discard',
            cancelLabel: 'Keep editing',
          );
        }),
      );
      await tester.tap(find.text('Delete workflow'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('destructive confirm uses the danger variant', (tester) async {
      await _confirm(tester);

      final confirm = tester.widget<HiveButton>(
        find.widgetWithText(HiveButton, 'Delete'),
      );
      expect(confirm.variant, HiveButtonVariant.danger);
      final cancel = tester.widget<HiveButton>(
        find.widgetWithText(HiveButton, 'Cancel'),
      );
      expect(cancel.variant, HiveButtonVariant.secondary);
    });

    testWidgets('non-destructive confirm uses the primary variant', (
      tester,
    ) async {
      await _confirm(tester, destructive: false);

      final confirm = tester.widget<HiveButton>(
        find.widgetWithText(HiveButton, 'Delete'),
      );
      expect(confirm.variant, HiveButtonVariant.primary);
    });
  });

  group('HiveDialog', () {
    testWidgets('draws a surface2 panel with radiusPanel and a hairline', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveDialog(
            title: 'Rename workflow',
            content: const HiveTextField(label: 'Workflow name'),
            actions: <Widget>[HiveButton(label: 'Save', onPressed: () {})],
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(HiveDialog),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, HiveColors.dark.surface2);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(HiveRadii.standard.radiusPanel),
      );
      expect(
        (decoration.border! as Border).top.color,
        HiveColors.dark.borderSubtle,
      );
      expect(find.byType(HiveTextField), findsOneWidget);
    });

    testWidgets('names its route for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveDialog(
            title: 'Rename workflow',
            actions: <Widget>[HiveButton(label: 'Save', onPressed: () {})],
          ),
        ),
      );

      final data = tester.getSemantics(
        find.bySemanticsLabel('Rename workflow').first,
      );
      expect(data.flagsCollection.scopesRoute, isTrue);
      expect(data.flagsCollection.namesRoute, isTrue);
      handle.dispose();
    });

    testWidgets('opens without a transition when animations are off', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _launcher((context) async {
            await HiveDialog.confirm(
              context: context,
              title: 'Discard unsaved changes?',
              confirmLabel: 'Discard',
              cancelLabel: 'Keep editing',
            );
          }),
        ),
      );
      await tester.tap(find.text('Delete workflow'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
