import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

const _title = 'Stop backend and quit?';
const _message =
    '2 runs are in progress. Stopping the backend cancels them and closes '
    'Agentic Hive.';

/// A trigger that opens a confirmation dialog and records its result.
class _Opener extends StatelessWidget {
  const new({required this.onResult, this.barrierDismissible = true});

  final ValueChanged<bool?> onResult;
  final bool barrierDismissible;

  @override
  Widget build(BuildContext context) {
    return HiveButton(
      label: 'Open',
      onPressed: () async {
        final result = await showHiveDialog<bool>(
          context: context,
          barrierLabel: 'Dismiss',
          barrierDismissible: barrierDismissible,
          builder: (context) => HiveDialog(
            title: _title,
            message: _message,
            icon: HiveIcons.alert,
            actions: <Widget>[
              HiveButton(
                label: 'Cancel',
                variant: HiveButtonVariant.ghost,
                autofocus: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              HiveButton(
                label: 'Stop backend',
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );
        onResult(result);
      },
    );
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

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

    testWidgets('destructive confirm focuses Cancel so Enter cancels', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _launcher((context) async {
          result = await HiveDialog.confirm(
            context: context,
            title: 'Delete "Release checklist"?',
            confirmLabel: 'Delete',
            cancelLabel: 'Cancel',
            destructive: true,
          );
        }),
      );
      await tester.tap(find.text('Delete workflow'));
      await tester.pumpAndSettle();

      final cancel = tester.widget<HiveButton>(
        find.widgetWithText(HiveButton, 'Cancel'),
      );
      final confirm = tester.widget<HiveButton>(
        find.widgetWithText(HiveButton, 'Delete'),
      );
      expect(cancel.autofocus, isTrue);
      expect(confirm.autofocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Delete "Release checklist"?'), findsNothing);
    });

    testWidgets('destructive confirm: Tab reaches Confirm and Enter confirms', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _launcher((context) async {
          result = await HiveDialog.confirm(
            context: context,
            title: 'Delete "Release checklist"?',
            confirmLabel: 'Delete',
            cancelLabel: 'Cancel',
            destructive: true,
          );
        }),
      );
      await tester.tap(find.text('Delete workflow'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Delete "Release checklist"?'), findsNothing);
    });
  });

  group('HiveDialog', () {
    testWidgets('shows title, message, icon and actions', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveDialog(
            title: _title,
            message: _message,
            icon: HiveIcons.alert,
            actions: <Widget>[
              HiveButton(label: 'Cancel', onPressed: () {}),
              HiveButton(label: 'Stop backend', onPressed: () {}),
            ],
          ),
        ),
      );

      expect(find.text(_title), findsOneWidget);
      expect(find.text(_message), findsOneWidget);
      expect(find.byType(HiveIcon), findsOneWidget);
      expect(find.byType(HiveButton), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses surface2, radiusPanel and a hairline border', (
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

      final panel = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(HiveDialog),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = panel.decoration as BoxDecoration;
      expect(decoration.color, HiveColors.dark.surface2);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(HiveRadii.standard.radiusPanel),
      );
      final border = decoration.border! as Border;
      expect(border.top.color, HiveColors.dark.borderSubtle);
      expect(border.top.width, HiveElevation.dark.hairline);
      expect(find.byType(HiveTextField), findsOneWidget);
    });

    testWidgets('names the route with its title for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(hiveTestApp(child: _Opener(onResult: (_) {})));
      await _open(tester);

      expect(find.bySemanticsLabel(_title), findsWidgets);
      final node = tester.getSemantics(
        find
            .descendant(
              of: find.byType(HiveDialog),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.label, _title);
      expect(node.flagsCollection.scopesRoute, isTrue);
      expect(node.flagsCollection.namesRoute, isTrue);
      handle.dispose();
    });

    testWidgets('returns the confirming action result', (tester) async {
      bool? result;
      await tester.pumpWidget(
        hiveTestApp(child: _Opener(onResult: (value) => result = value)),
      );
      await _open(tester);

      await tester.tap(find.text('Stop backend'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(HiveDialog), findsNothing);
    });

    testWidgets('focuses the autofocus action so Enter picks it', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        hiveTestApp(child: _Opener(onResult: (value) => result = value)),
      );
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.byType(HiveDialog), findsNothing);
    });

    testWidgets('Tab moves focus between actions', (tester) async {
      bool? result;
      await tester.pumpWidget(
        hiveTestApp(child: _Opener(onResult: (value) => result = value)),
      );
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('Escape dismisses with a null result', (tester) async {
      var completed = false;
      bool? result = false;
      await tester.pumpWidget(
        hiveTestApp(
          child: _Opener(
            onResult: (value) {
              completed = true;
              result = value;
            },
          ),
        ),
      );
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);
      expect(find.byType(HiveDialog), findsNothing);
    });

    testWidgets('a non-dismissible dialog ignores scrim clicks', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: _Opener(onResult: (_) {}, barrierDismissible: false),
        ),
      );
      await _open(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byType(HiveDialog), findsOneWidget);
    });

    testWidgets('appears without animation when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: hiveTestApp(child: _Opener(onResult: (_) {})),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(HiveDialog), findsOneWidget);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(HiveDialog),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
    });

    testWidgets('long content scrolls instead of overflowing', (tester) async {
      tester.view
        ..physicalSize = const Size(800, 400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        hiveTestApp(
          child: HiveDialog(
            title: _title,
            message: List<String>.filled(40, _message).join(' '),
            actions: <Widget>[HiveButton(label: 'Cancel', onPressed: () {})],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets(
      'dropCaption wraps only the panel in HiveDropZone when provided',
      (tester) async {
        await tester.pumpWidget(
          hiveTestApp(
            child: HiveDialog(
              title: _title,
              actions: <Widget>[HiveButton(label: 'Cancel', onPressed: () {})],
            ),
          ),
        );
        expect(find.byType(HiveDropZone), findsNothing);

        await tester.pumpWidget(
          hiveTestApp(
            child: HiveDialog(
              title: _title,
              dropCaption: 'Drop images to attach',
              dropActive: true,
              actions: <Widget>[HiveButton(label: 'Cancel', onPressed: () {})],
            ),
          ),
        );

        final panelSemantics = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.namesRoute == true,
        );
        final dropZoneFinder = find.descendant(
          of: panelSemantics,
          matching: find.byType(HiveDropZone),
        );
        expect(dropZoneFinder, findsOneWidget);
        expect(tester.widget<HiveDropZone>(dropZoneFinder).active, isTrue);
      },
    );
  });
}
