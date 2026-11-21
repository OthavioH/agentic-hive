import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

const _semanticLabel = 'Claude Code terminal';

/// Lets xterm's double-tap detector time out after a tap.
const _doubleTapTimeout = Duration(milliseconds: 400);

Widget _view(
  HiveTerminalController controller, {
  required HiveTerminalMode mode,
  String modeLabel = 'Watching',
  ValueChanged<Uint8List>? onInput,
  void Function(int columns, int rows)? onResize,
  Size size = const Size(640, 320),
  ThemeData? theme,
  Widget? trailing,
  FocusNode? focusNode,
}) {
  return hiveTestApp(
    theme: theme,
    child: Center(
      child: SizedBox.fromSize(
        size: size,
        child: HiveTerminalView(
          controller: controller,
          mode: mode,
          modeLabel: modeLabel,
          semanticLabel: _semanticLabel,
          onInput: onInput,
          onResize: onResize,
          trailing: trailing,
          focusNode: focusNode,
        ),
      ),
    ),
  );
}

BoxBorder? _wellBorder(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey<String>('hive-terminal-well')),
  );
  return (box.decoration as BoxDecoration).border;
}

Future<void> _typeA(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
  await tester.pump();
}

void main() {
  group('HiveTerminalController', () {
    test('joins a UTF-8 character split across two byte chunks', () {
      final controller = HiveTerminalController();
      addTearDown(controller.dispose);
      final bytes = utf8.encode('Résumé ✓');
      controller
        ..appendBytes(bytes.sublist(0, 2))
        ..appendBytes(bytes.sublist(2, 9))
        ..appendBytes(bytes.sublist(9));

      expect(controller.plainText, contains('Résumé ✓'));
    });

    test('parses ANSI escape sequences instead of printing them', () {
      final controller = HiveTerminalController();
      addTearDown(controller.dispose);
      controller.appendBytes(
        utf8.encode('\x1b[1;32mPASS\x1b[0m test/engine\r\n\x1b[2K'),
      );

      expect(controller.plainText, contains('PASS test/engine'));
      expect(controller.plainText, isNot(contains('[1;32m')));
    });

    test('replaces malformed bytes instead of throwing', () {
      final controller = HiveTerminalController();
      addTearDown(controller.dispose);
      controller.appendBytes(<int>[0x6F, 0x6B, 0xFF, 0x21]);

      expect(controller.plainText, contains('ok�!'));
    });

    test('keeps at most scrollbackLines lines', () {
      final controller = HiveTerminalController(scrollbackLines: 40);
      addTearDown(controller.dispose);
      controller.appendText(
        List<String>.generate(200, (i) => 'line $i').join('\r\n'),
      );

      expect(controller.lineCount, lessThanOrEqualTo(40));
      expect(controller.plainText, contains('line 199'));
      expect(controller.plainText, isNot(contains('line 0\n')));
    });
  });

  group('HiveTerminalView', () {
    testWidgets('shows the mode label and a semantics label', (tester) async {
      final controller = HiveTerminalController();
      addTearDown(controller.dispose);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_view(controller, mode: HiveTerminalMode.watch));

      expect(find.text('Watching'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^$_semanticLabel, Watching')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('reports the size in cells after layout and on resize', (
      tester,
    ) async {
      final controller = HiveTerminalController();
      addTearDown(controller.dispose);
      final sizes = <(int, int)>[];
      void onResize(int c, int r) => sizes.add((c, r));

      await tester.pumpWidget(
        _view(controller, mode: HiveTerminalMode.watch, onResize: onResize),
      );
      await tester.pump();
      expect(sizes, hasLength(1));
      final (columns, rows) = sizes.single;
      expect(columns, greaterThan(10));
      expect(rows, greaterThan(3));
      expect((controller.columns, controller.rows), (columns, rows));

      await tester.pumpWidget(
        _view(
          controller,
          mode: HiveTerminalMode.watch,
          onResize: onResize,
          size: const Size(960, 480),
        ),
      );
      await tester.pump();
      expect(sizes, hasLength(2));
      expect(sizes.last.$1, greaterThan(columns));
      expect(sizes.last.$2, greaterThan(rows));
    });

    testWidgets('watch mode sends no input', (tester) async {
      final controller = HiveTerminalController();
      addTearDown(controller.dispose);
      final input = <Uint8List>[];
      await tester.pumpWidget(
        _view(controller, mode: HiveTerminalMode.watch, onInput: input.add),
      );
      await tester.tap(find.byType(HiveTerminalView));
      await tester.pump(_doubleTapTimeout);
      await _typeA(tester);

      expect(input, isEmpty);
    });

    testWidgets('interactive mode sends typed keys as bytes', (tester) async {
      final controller = HiveTerminalController();
      addTearDown(controller.dispose);
      final input = <Uint8List>[];
      await tester.pumpWidget(
        _view(
          controller,
          mode: HiveTerminalMode.interactive,
          modeLabel: 'You have control',
          onInput: input.add,
        ),
      );
      await tester.tap(find.byType(HiveTerminalView));
      await tester.pump(_doubleTapTimeout);
      await _typeA(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(input.expand((b) => b).toList(), <int>[0x61, 0x0D]);
    });

    testWidgets('interactive mode shows a focus ring while focused', (
      tester,
    ) async {
      final controller = HiveTerminalController();
      addTearDown(controller.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _view(
          controller,
          mode: HiveTerminalMode.interactive,
          focusNode: focusNode,
        ),
      );
      const colors = HiveColors.dark;
      expect(
        _wellBorder(tester),
        Border.all(
          color: colors.borderSubtle,
          width: HiveElevation.dark.hairline,
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(
        _wellBorder(tester),
        Border.all(
          color: colors.focusRing,
          width: HiveElevation.dark.focusRingWidth,
        ),
      );
    });

    testWidgets('ended mode sends no input and stops reporting resizes', (
      tester,
    ) async {
      final controller = HiveTerminalController();
      addTearDown(controller.dispose);
      final input = <Uint8List>[];
      final sizes = <(int, int)>[];
      void onResize(int c, int r) => sizes.add((c, r));

      await tester.pumpWidget(
        _view(
          controller,
          mode: HiveTerminalMode.ended,
          modeLabel: 'Session ended',
          onInput: input.add,
          onResize: onResize,
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(HiveTerminalView));
      await tester.pump(_doubleTapTimeout);
      await _typeA(tester);

      expect(find.text('Session ended'), findsOneWidget);
      expect(input, isEmpty);
      expect(sizes, isEmpty);
    });

    testWidgets('a mode change takes effect without a new controller', (
      tester,
    ) async {
      final controller = HiveTerminalController();
      addTearDown(controller.dispose);
      final input = <Uint8List>[];
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _view(
          controller,
          mode: HiveTerminalMode.watch,
          onInput: input.add,
          focusNode: focusNode,
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      await _typeA(tester);
      expect(input, isEmpty);

      await tester.pumpWidget(
        _view(
          controller,
          mode: HiveTerminalMode.interactive,
          onInput: input.add,
          focusNode: focusNode,
        ),
      );
      await _typeA(tester);
      expect(input.expand((b) => b).toList(), <int>[0x61]);
    });

    testWidgets('renders the trailing action and the light theme', (
      tester,
    ) async {
      final controller = HiveTerminalController()
        ..appendText('\x1b[31mError:\x1b[0m not signed in\r\n');
      addTearDown(controller.dispose);
      var tapped = false;
      await tester.pumpWidget(
        _view(
          controller,
          mode: HiveTerminalMode.watch,
          theme: HiveTheme.light(),
          trailing: HiveButton(
            label: 'Take over',
            icon: HiveIcons.keyboard,
            size: HiveButtonSize.small,
            variant: HiveButtonVariant.secondary,
            onPressed: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.text('Take over'));
      await tester.pump();

      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
