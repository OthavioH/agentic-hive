import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

const _semanticLabel = 'Harness output';
const _jumpLabel = 'Jump to bottom';
const _stderrLabel = 'Error';

Widget _viewer(HiveLogStreamController controller, {ThemeData? theme}) {
  return hiveTestApp(
    theme: theme,
    child: SizedBox(
      width: 480,
      height: 200,
      child: HiveLogStreamViewer(
        controller: controller,
        semanticLabel: _semanticLabel,
        jumpToBottomLabel: _jumpLabel,
        stderrSemanticLabel: _stderrLabel,
        emptyLabel: 'No output yet',
      ),
    ),
  );
}

ScrollPosition _position(WidgetTester tester) {
  return tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(HiveLogStreamViewer),
          matching: find.byType(Scrollable),
        ),
      )
      .position;
}

void _fill(HiveLogStreamController controller, int count) {
  controller.appendLines(<HiveLogLine>[
    for (var i = 0; i < count; i++) HiveLogLine('line $i'),
  ]);
}

void main() {
  group('HiveLogStreamController', () {
    test('joins chunks that end mid-line on the same stream', () {
      final controller = HiveLogStreamController()
        ..append('Installing depend')
        ..append('encies\nResolving ')
        ..append('packages\r\n');

      expect(controller.lines, const <HiveLogLine>[
        HiveLogLine('Installing dependencies'),
        HiveLogLine('Resolving packages'),
      ]);
    });

    test('a chunk from the other stream closes the open line', () {
      final controller = HiveLogStreamController()
        ..append('partial')
        ..append('boom\n', stream: HiveLogStream.stderr)
        ..append('next\n');

      expect(controller.lines, const <HiveLogLine>[
        HiveLogLine('partial'),
        HiveLogLine('boom', stream: HiveLogStream.stderr),
        HiveLogLine('next'),
      ]);
    });

    test('keeps blank lines and ignores empty chunks', () {
      final controller = HiveLogStreamController()
        ..append('')
        ..append('a\n\nb\n');

      expect(controller.lines.map((l) => l.text), <String>['a', '', 'b']);
    });

    test('drops the oldest lines beyond maxLines', () {
      final controller = HiveLogStreamController(maxLines: 3);
      _fill(controller, 5);

      expect(controller.lines.map((l) => l.text), <String>[
        'line 2',
        'line 3',
        'line 4',
      ]);
    });

    test('notifies listeners and clears', () {
      var notified = 0;
      final controller = HiveLogStreamController()
        ..addListener(() => notified++)
        ..append('one\n')
        ..clear();

      expect(notified, 2);
      expect(controller.isEmpty, isTrue);
    });
  });

  group('HiveLogStreamViewer', () {
    testWidgets('shows the empty label without lines', (tester) async {
      final controller = HiveLogStreamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_viewer(controller));

      expect(find.text('No output yet'), findsOneWidget);
      expect(find.text(_jumpLabel), findsNothing);
    });

    testWidgets('uses Geist Mono on surface1', (tester) async {
      final controller = HiveLogStreamController()..append('ready\n');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_viewer(controller));

      final text = tester.widget<Text>(find.text('ready'));
      expect(text.style?.fontFamily, endsWith(HiveFontFamilies.mono));
      expect(text.style?.color, HiveColors.dark.onSurface);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(HiveLogStreamViewer),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, HiveColors.dark.surface1);
    });

    for (final entry in <String, (ThemeData, HiveColors)>{
      'dark': (HiveTheme.dark(), HiveColors.dark),
      'light': (HiveTheme.light(), HiveColors.light),
    }.entries) {
      testWidgets('stderr is danger text with a marker (${entry.key})', (
        tester,
      ) async {
        final (theme, colors) = entry.value;
        final controller = HiveLogStreamController()
          ..append('fine\n')
          ..append('fatal: not signed in\n', stream: HiveLogStream.stderr);
        addTearDown(controller.dispose);
        await tester.pumpWidget(_viewer(controller, theme: theme));

        final text = tester.widget<Text>(find.text('fatal: not signed in'));
        expect(text.style?.color, colors.danger);
        expect(
          find.byKey(const ValueKey<String>('stderr-marker')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('$_stderrLabel: fatal: not signed in'),
          findsOneWidget,
        );
        // Danger is used as text, so it must reach 4.5:1 on its surface.
        expect(
          HiveContrast.ratio(colors.danger, colors.surface1),
          greaterThanOrEqualTo(HiveContrastLevel.text.minimumRatio),
        );
        expect(
          HiveContrast.ratio(colors.onSurface, colors.surface1),
          greaterThanOrEqualTo(HiveContrastLevel.text.minimumRatio),
        );
      });
    }

    testWidgets('labels the log region for screen readers', (tester) async {
      final controller = HiveLogStreamController()..append('ready\n');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_viewer(controller));

      expect(find.bySemanticsLabel(_semanticLabel), findsOneWidget);
    });

    testWidgets('follows new lines while at the bottom', (tester) async {
      final controller = HiveLogStreamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_viewer(controller));
      _fill(controller, 100);
      await tester.pumpAndSettle();

      final position = _position(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, position.maxScrollExtent);
      expect(find.text('line 99'), findsOneWidget);

      controller.append('newest\n');
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(find.text('newest'), findsOneWidget);
      expect(find.text(_jumpLabel), findsNothing);
    });

    testWidgets('scrolling up pauses following and shows Jump to bottom', (
      tester,
    ) async {
      final controller = HiveLogStreamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_viewer(controller));
      _fill(controller, 100);
      await tester.pumpAndSettle();

      await tester.drag(find.text('line 99'), const Offset(0, 300));
      await tester.pumpAndSettle();
      final position = _position(tester);
      final paused = position.pixels;
      expect(paused, lessThan(position.maxScrollExtent));
      expect(find.text(_jumpLabel), findsOneWidget);

      controller.append('newest\n');
      await tester.pumpAndSettle();
      expect(position.pixels, paused);

      await tester.tap(find.text(_jumpLabel));
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(find.text('newest'), findsOneWidget);
      expect(find.text(_jumpLabel), findsNothing);

      controller.append('after jump\n');
      await tester.pumpAndSettle();
      expect(find.text('after jump'), findsOneWidget);
    });

    testWidgets('scrolling back to the bottom resumes following', (
      tester,
    ) async {
      final controller = HiveLogStreamController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_viewer(controller));
      _fill(controller, 100);
      await tester.pumpAndSettle();

      await tester.drag(find.text('line 99'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text(_jumpLabel), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text(_jumpLabel), findsNothing);
    });
  });
}
