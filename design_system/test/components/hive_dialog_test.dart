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

void main() {
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
          child: const HiveDialog(title: _title, actions: <Widget>[]),
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
  });
}
