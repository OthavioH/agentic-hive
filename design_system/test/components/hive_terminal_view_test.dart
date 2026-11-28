import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

const _semanticLabel = 'Claude Code terminal';

/// Lets xterm2's double-tap detector time out after a tap.
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
  if (tester.testTextInput.hasAnyClients) {
    tester.testTextInput.enterText('a');
  } else {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
  }
  await tester.pump();
}

({List<String> writes, List<String> reads}) _mockClipboard(
  WidgetTester tester,
) {
  final writes = <String>[];
  final reads = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<Object?, Object?>?;
        writes.add(args?['text'] as String? ?? '');
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        reads.add(call.arguments as String? ?? '');
        return <String, Object?>{'text': 'pasted'};
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  return (writes: writes, reads: reads);
}

double _scrollPixels(WidgetTester tester) {
  final scrollables = tester.stateList<ScrollableState>(
    find.descendant(
      of: find.byType(HiveTerminalView),
      matching: find.byType(Scrollable),
    ),
  );
  return scrollables
      .firstWhere((s) => s.widget.axisDirection == AxisDirection.down)
      .position
      .pixels;
}

Future<void> _sendTerminalShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  final isMac = defaultTargetPlatform == TargetPlatform.macOS;
  if (isMac) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  } else {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }
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

      expect(controller.plainText, contains('ok\uFFFD!'));
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

    test('supports windowsPty mode', () {
      final controller = HiveTerminalController(windowsPty: true)
        ..appendText('hi');
      addTearDown(controller.dispose);

      expect(controller.plainText, contains('hi'));
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

    testWidgets(
      'interactive mode uses IME path and supports composition on desktop',
      (tester) async {
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

        expect(tester.testTextInput.hasAnyClients, isTrue);

        await _typeA(tester);
        expect(input.expand((b) => b).toList(), <int>[0x61]);
        input.clear();

        // Composing (e.g. dead key '´' on pt-BR/ABNT2) must not emit bytes yet.
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'a´',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 1, end: 2),
          ),
        );
        await tester.pump();
        expect(input, isEmpty);

        // Committing composed character 'á' emits its UTF-8 bytes.
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'aá',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        await tester.pump();

        // Committing CJK composition '漢' emits its UTF-8 bytes.
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'aá漢',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        await tester.pump();

        expect(input.expand((b) => b).toList(), <int>[
          ...utf8.encode('á'),
          ...utf8.encode('漢'),
        ]);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'watch and ended modes send no input or terminal query replies',
      (tester) async {
        for (final mode in const <HiveTerminalMode>[
          HiveTerminalMode.watch,
          HiveTerminalMode.ended,
        ]) {
          final controller = HiveTerminalController();
          addTearDown(controller.dispose);
          final input = <Uint8List>[];
          await tester.pumpWidget(
            _view(controller, mode: mode, onInput: input.add),
          );
          await tester.tap(find.byType(HiveTerminalView));
          await tester.pump(_doubleTapTimeout);
          await _typeA(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          controller.appendText('\x1b[c\x1b]11;?\x07');
          await tester.pump();

          expect(input, isEmpty, reason: 'mode=$mode');
        }

        // In interactive mode, the same queries produce terminal replies.
        final interactiveController = HiveTerminalController();
        addTearDown(interactiveController.dispose);
        final interactiveInput = <Uint8List>[];
        await tester.pumpWidget(
          _view(
            interactiveController,
            mode: HiveTerminalMode.interactive,
            onInput: interactiveInput.add,
          ),
        );
        interactiveController.appendText('\x1b[c\x1b]11;?\x07');
        await tester.pump();

        expect(interactiveInput, isNotEmpty);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'terminal output never writes the system clipboard in any mode',
      (tester) async {
        const clipboardSequences =
            '\x1b]52;c;aGk=\x07'
            '\x1b]1337;Copy=:aGk=\x07'
            '\x1b]1337;CopyToClipboard=\x07hi\x1b]1337;EndCopy\x07'
            '\x1b]5522;type=write;aGk=\x07';

        final clipboard = _mockClipboard(tester);

        for (final mode in HiveTerminalMode.values) {
          final controller = HiveTerminalController();
          addTearDown(controller.dispose);
          final focusNode = FocusNode();
          addTearDown(focusNode.dispose);

          await tester.pumpWidget(
            _view(controller, mode: mode, focusNode: focusNode),
          );
          focusNode.requestFocus();
          await tester.pump();

          controller.appendText(clipboardSequences);
          await tester.pump();

          expect(clipboard.writes, isEmpty, reason: 'live mode=$mode');

          // Replay case: feed before pumping the view.
          final replayed = HiveTerminalController()
            ..appendText(clipboardSequences);
          addTearDown(replayed.dispose);
          await tester.pumpWidget(
            _view(replayed, mode: mode, focusNode: focusNode),
          );
          await tester.pump();

          expect(clipboard.writes, isEmpty, reason: 'replay mode=$mode');
        }
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'OSC 52 clipboard query gets no reply and does not read clipboard',
      (tester) async {
        final clipboard = _mockClipboard(tester);
        final controller = HiveTerminalController();
        addTearDown(controller.dispose);
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        final input = <Uint8List>[];

        await tester.pumpWidget(
          _view(
            controller,
            mode: HiveTerminalMode.interactive,
            onInput: input.add,
            focusNode: focusNode,
          ),
        );
        focusNode.requestFocus();
        await tester.pump();

        controller.appendText('\x1b]52;c;?\x07');
        await tester.pump();

        expect(input, isEmpty);
        expect(clipboard.reads, isEmpty);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'CSI 21 t title report is dropped while other query replies still arrive',
      (tester) async {
        final controller = HiveTerminalController();
        addTearDown(controller.dispose);
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        final input = <Uint8List>[];

        await tester.pumpWidget(
          _view(
            controller,
            mode: HiveTerminalMode.interactive,
            onInput: input.add,
            focusNode: focusNode,
          ),
        );
        focusNode.requestFocus();
        await tester.pump();

        controller.appendText('\x1b]2;injected\x07\x1b[21t');
        await tester.pump();
        expect(input, isEmpty);

        controller.appendText('\x1b[c\x1b]11;?\x07');
        await tester.pump();
        expect(input, isNotEmpty);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'wheel scrolls the buffer in watch and ended even with mouse reporting',
      (tester) async {
        for (final mode in const <HiveTerminalMode>[
          HiveTerminalMode.watch,
          HiveTerminalMode.ended,
        ]) {
          final controller = HiveTerminalController()
            ..appendText(
              '${List<String>.generate(200, (i) => 'line $i').join('\r\n')}'
              '\x1b[?1000h\x1b[?1006h',
            );
          addTearDown(controller.dispose);
          final input = <Uint8List>[];

          await tester.pumpWidget(
            _view(controller, mode: mode, onInput: input.add),
          );
          await tester.pump();

          final before = _scrollPixels(tester);
          final center = tester.getCenter(find.byType(HiveTerminalView));
          final pointer = TestPointer(1, PointerDeviceKind.mouse);
          await tester.sendEventToBinding(pointer.hover(center));
          await tester.sendEventToBinding(
            pointer.scroll(const Offset(0, -120)),
          );
          await tester.pump();

          expect(
            _scrollPixels(tester),
            isNot(equals(before)),
            reason: 'mode=$mode',
          );
          expect(input, isEmpty, reason: 'mode=$mode');
        }
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'interactive with mouse reporting: drag selects, tap and wheel report',
      (tester) async {
        final clipboard = _mockClipboard(tester);
        final controller = HiveTerminalController()
          ..appendText('hello world terminal\r\n\x1b[?1000h\x1b[?1006h');
        addTearDown(controller.dispose);
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        final input = <Uint8List>[];

        await tester.pumpWidget(
          _view(
            controller,
            mode: HiveTerminalMode.interactive,
            onInput: input.add,
            focusNode: focusNode,
          ),
        );
        focusNode.requestFocus();
        await tester.pump();

        final well = tester.getRect(
          find.byKey(const ValueKey<String>('hive-terminal-well')),
        );
        final start = Offset(well.left + 12, well.top + 16);
        final drag = await tester.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await drag.moveBy(const Offset(120, 0));
        await tester.pump(const Duration(milliseconds: 50));
        await drag.up();
        await tester.pump(_doubleTapTimeout);

        await _sendTerminalShortcut(tester, LogicalKeyboardKey.keyC);
        expect(clipboard.writes, isNotEmpty);
        expect(clipboard.writes.last, isNotEmpty);

        input.clear();
        await tester.tapAt(Offset(well.left + 40, well.top + 16));
        await tester.pump(_doubleTapTimeout);
        final tapBytes = utf8.decode(
          input.expand((b) => b).toList(),
          allowMalformed: true,
        );
        expect(tapBytes, contains('\x1b[<'));

        input.clear();
        final pointer = TestPointer(2, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(well.center));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
        await tester.pump();
        final wheelBytes = utf8.decode(
          input.expand((b) => b).toList(),
          allowMalformed: true,
        );
        expect(wheelBytes, contains('\x1b[<'));
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets('copy works in every mode', (tester) async {
      final clipboard = _mockClipboard(tester);
      for (final mode in HiveTerminalMode.values) {
        clipboard.writes.clear();
        final controller = HiveTerminalController()
          ..appendText('copyable text\r\n');
        addTearDown(controller.dispose);
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          _view(controller, mode: mode, focusNode: focusNode),
        );
        focusNode.requestFocus();
        await tester.pump();

        await _sendTerminalShortcut(tester, LogicalKeyboardKey.keyA);
        await _sendTerminalShortcut(tester, LogicalKeyboardKey.keyC);

        expect(clipboard.writes, isNotEmpty, reason: 'mode=$mode');
        expect(
          clipboard.writes.last,
          contains('copyable text'),
          reason: 'mode=$mode',
        );
      }
    }, variant: TargetPlatformVariant.desktop());

    testWidgets(
      'paste sends bytes in interactive mode and nothing in watch mode',
      (tester) async {
        _mockClipboard(tester);
        final interactiveController = HiveTerminalController();
        addTearDown(interactiveController.dispose);
        final interactiveFocus = FocusNode();
        addTearDown(interactiveFocus.dispose);
        final interactiveInput = <Uint8List>[];

        await tester.pumpWidget(
          _view(
            interactiveController,
            mode: HiveTerminalMode.interactive,
            onInput: interactiveInput.add,
            focusNode: interactiveFocus,
          ),
        );
        interactiveFocus.requestFocus();
        await tester.pump();

        await _sendTerminalShortcut(tester, LogicalKeyboardKey.keyV);
        expect(
          utf8.decode(interactiveInput.expand((b) => b).toList()),
          contains('pasted'),
        );

        final watchController = HiveTerminalController();
        addTearDown(watchController.dispose);
        final watchFocus = FocusNode();
        addTearDown(watchFocus.dispose);
        final watchInput = <Uint8List>[];

        await tester.pumpWidget(
          _view(
            watchController,
            mode: HiveTerminalMode.watch,
            onInput: watchInput.add,
            focusNode: watchFocus,
          ),
        );
        watchFocus.requestFocus();
        await tester.pump();

        await _sendTerminalShortcut(tester, LogicalKeyboardKey.keyV);
        expect(watchInput, isEmpty);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'dispose is idempotent, safe before detach, and cancels sync timer',
      (tester) async {
        final first = HiveTerminalController();
        await tester.pumpWidget(_view(first, mode: HiveTerminalMode.watch));
        await tester.pump();

        // Start synchronized-update timer (\x1b[?2026h), then dispose twice.
        first
          ..appendText('\x1b[?2026h')
          ..dispose()
          ..dispose();

        final second = HiveTerminalController();
        addTearDown(second.dispose);
        await tester.pumpWidget(_view(second, mode: HiveTerminalMode.watch));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.desktop(),
    );

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
    }, variant: TargetPlatformVariant.desktop());

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
