import 'package:design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

/// Pumps an app whose button shows a toast, and returns its handle getter.
Future<HiveToastHandle? Function()> _pumpLauncher(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  HiveToastHandle? handle;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: hiveTestApp(
        child: Builder(
          builder: (context) => HiveButton(
            label: 'Copy path',
            onPressed: () =>
                handle = HiveToast.show(context, message: 'Path copied'),
          ),
        ),
      ),
    ),
  );
  return () => handle;
}

Future<void> _tapLauncher(WidgetTester tester) async {
  await tester.tap(find.text('Copy path'));
  await tester.pump();
}

/// Lets the entrance finish, the display time run out, then the exit.
Future<void> _runOut(WidgetTester tester) async {
  await tester.pump(HiveMotionTokens.standard.medium);
  await tester.pump(HiveToast.displayDuration);
  await _playExit(tester);
}

/// Plays the exit motion. An animation only completes on a frame strictly
/// after its duration, so pump one extra millisecond, then rebuild.
Future<void> _playExit(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(HiveMotionTokens.standard.short);
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

void main() {
  group('HiveToast', () {
    testWidgets('announces its message through a live region', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveToast(message: 'Path copied')),
      );

      expect(find.text('Path copied'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(HiveToast));
      expect(semantics.label, 'Path copied');
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('shows the tone icon unless an icon is given', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const Column(
            children: <Widget>[
              HiveToast(message: 'Plain'),
              HiveToast(message: 'Saved', tone: HiveToastTone.success),
              HiveToast(
                message: 'Copied',
                tone: HiveToastTone.info,
                icon: HiveIcons.copy,
              ),
            ],
          ),
        ),
      );

      HiveIconData? iconOf(String message) {
        final icons = find.descendant(
          of: find.ancestor(
            of: find.text(message),
            matching: find.byType(HiveToast),
          ),
          matching: find.byType(HiveIcon),
        );
        if (icons.evaluate().isEmpty) return null;
        return tester.widget<HiveIcon>(icons).icon;
      }

      expect(iconOf('Plain'), isNull);
      expect(iconOf('Saved'), HiveIcons.check);
      expect(iconOf('Copied'), HiveIcons.copy);
    });

    testWidgets('uses the tone color pair from the theme', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveToast(
            message: 'Run failed',
            tone: HiveToastTone.danger,
          ),
        ),
      );

      const colors = HiveColors.dark;
      final text = tester.widget<Text>(find.text('Run failed'));
      expect(text.style?.color, colors.onDanger);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(HiveToast),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, colors.danger);
    });
  });

  group('HiveToast.show', () {
    testWidgets('appears, then leaves after the display duration', (
      tester,
    ) async {
      final handle = await _pumpLauncher(tester);

      await _tapLauncher(tester);
      expect(find.text('Path copied'), findsOneWidget);
      expect(handle()!.isVisible, isTrue);

      await tester.pump(HiveMotionTokens.standard.medium);
      await tester.pump(
        HiveToast.displayDuration - const Duration(milliseconds: 1),
      );
      expect(find.text('Path copied'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await _playExit(tester);
      expect(find.text('Path copied'), findsNothing);
      expect(handle()!.isVisible, isFalse);
    });

    testWidgets('does not block taps on the content behind it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: Builder(
            builder: (context) => HiveButton(
              label: 'Copy path',
              onPressed: () {
                taps++;
                HiveToast.show(context, message: 'Path copied');
              },
            ),
          ),
        ),
      );

      await _tapLauncher(tester);
      await tester.pump(HiveMotionTokens.standard.medium);
      await _tapLauncher(tester);

      expect(taps, 2);
      await _runOut(tester);
    });

    testWidgets('a new toast replaces the visible one', (tester) async {
      var count = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: Builder(
            builder: (context) => HiveButton(
              label: 'Copy path',
              onPressed: () =>
                  HiveToast.show(context, message: 'Copied ${++count}'),
            ),
          ),
        ),
      );

      await _tapLauncher(tester);
      await _tapLauncher(tester);

      expect(find.text('Copied 1'), findsNothing);
      expect(find.text('Copied 2'), findsOneWidget);
      expect(find.byType(HiveToast), findsOneWidget);
      await _runOut(tester);
    });

    testWidgets('dismiss removes it early', (tester) async {
      final handle = await _pumpLauncher(tester);

      await _tapLauncher(tester);
      await tester.pump(HiveMotionTokens.standard.medium);
      handle()!.dismiss();
      await _playExit(tester);

      expect(find.byType(HiveToast), findsNothing);
      expect(handle()!.isVisible, isFalse);
      // A second dismiss does nothing.
      handle()!.dismiss();
    });

    testWidgets('stays while the pointer hovers over it', (tester) async {
      await _pumpLauncher(tester);
      await _tapLauncher(tester);
      await tester.pump(HiveMotionTokens.standard.medium);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(HiveToast)));
      await tester.pump(HiveToast.displayDuration * 2);
      expect(find.byType(HiveToast), findsOneWidget);

      await mouse.moveTo(Offset.zero);
      await tester.pump(HiveToast.displayDuration);
      await _playExit(tester);
      expect(find.byType(HiveToast), findsNothing);
    });

    testWidgets('shows at full opacity at once when animations are off', (
      tester,
    ) async {
      await _pumpLauncher(tester, disableAnimations: true);

      await _tapLauncher(tester);
      await tester.pump();

      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(HiveToast),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);

      await tester.pump(HiveToast.displayDuration);
      await tester.pump();
      expect(find.byType(HiveToast), findsNothing);
    });
  });
}
