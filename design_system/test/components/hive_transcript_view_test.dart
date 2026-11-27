import 'dart:ui' show Tristate;

import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

String _showAll(int lines) => 'Show all ($lines lines)';

const HiveTranscriptLabels _labels = HiveTranscriptLabels(
  semanticLabel: 'Transcript',
  jumpToBottom: 'Jump to bottom',
  thinking: 'Thinking',
  toolResult: 'Tool result',
  error: 'Error',
  stderr: 'Error',
  showLess: 'Show less',
  showAll: _showAll,
  emptyLabel: 'No transcript entries yet.',
);

Widget _view(
  HiveTranscriptController controller, {
  ThemeData? theme,
  double width = 560,
  double height = 400,
}) {
  return hiveTestApp(
    theme: theme,
    child: SizedBox(
      width: width,
      height: height,
      child: HiveTranscriptView(controller: controller, labels: _labels),
    ),
  );
}

ScrollPosition _position(WidgetTester tester) {
  return tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(HiveTranscriptView),
          matching: find.byType(Scrollable),
        ),
      )
      .position;
}

void _fill(HiveTranscriptController controller, int count) {
  controller.upsertAll(<HiveTranscriptBlock>[
    for (var i = 0; i < count; i++)
      HiveTranscriptPlainText(id: 'p-$i', text: 'entry $i'),
  ]);
}

void main() {
  group('HiveTranscriptController', () {
    test('upserts by id in place and appends new ids', () {
      final controller = HiveTranscriptController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller
        ..addListener(() => notifications++)
        ..upsertAll(const <HiveTranscriptBlock>[
          HiveTranscriptMessage(id: 'm1', markdown: 'First'),
          HiveTranscriptMessage(id: 'm2', markdown: 'Second'),
        ]);
      expect(notifications, 1);
      expect(controller.length, 2);

      controller.upsert(const HiveTranscriptMessage(id: 'm1', markdown: 'One'));
      expect(notifications, 2);
      expect(controller.length, 2);
      expect((controller.blocks[0] as HiveTranscriptMessage).markdown, 'One');
      expect(
        (controller.blocks[1] as HiveTranscriptMessage).markdown,
        'Second',
      );

      controller.clear();
      expect(notifications, 3);
      expect(controller.isEmpty, isTrue);
    });
  });

  group('HiveTranscriptView', () {
    testWidgets('renders every block kind and uses mono for tool/plain text', (
      tester,
    ) async {
      final controller = HiveTranscriptController(
        initialBlocks: const <HiveTranscriptBlock>[
          HiveTranscriptMessage(id: 'msg', markdown: 'Hello **world**'),
          HiveTranscriptThinking(id: 'th', text: 'Considering options'),
          HiveTranscriptToolCall(
            id: 'tc',
            name: 'read_file',
            input: 'path: lib/main.dart\nline: 1',
          ),
          HiveTranscriptToolResult(id: 'tr', text: 'void main() {}'),
          HiveTranscriptError(id: 'err', message: 'Process timed out'),
          HiveTranscriptFinalResult(
            id: 'fin',
            statusLabel: 'Succeeded',
            tone: HiveFeedbackTone.success,
            metrics: <HiveTranscriptMetric>[
              HiveTranscriptMetric(label: 'Duration', value: '12s'),
            ],
          ),
          HiveTranscriptPlainText(id: 'pt', text: 'stdout line'),
        ],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(controller, height: 800));

      expect(find.byType(HiveMarkdownView), findsOneWidget);
      expect(find.text('Thinking'), findsOneWidget);
      expect(find.text('read_file'), findsOneWidget);
      expect(find.text('path: lib/main.dart'), findsOneWidget);
      expect(find.text('Tool result'), findsOneWidget);
      expect(find.byType(HiveBanner), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Process timed out'), findsOneWidget);
      expect(find.text('Succeeded'), findsOneWidget);
      expect(find.text('Duration: 12s'), findsOneWidget);
      expect(find.text('stdout line'), findsOneWidget);

      // Expand tool call and tool result to verify mono typography.
      await tester.tap(find.text('read_file'));
      await tester.tap(find.text('Tool result'));
      await tester.pumpAndSettle();

      final toolInputText = tester.widget<Text>(
        find.text('path: lib/main.dart\nline: 1'),
      );
      expect(toolInputText.style?.fontFamily, endsWith(HiveFontFamilies.mono));
      final toolResultText = tester.widget<Text>(find.text('void main() {}'));
      expect(toolResultText.style?.fontFamily, endsWith(HiveFontFamilies.mono));
      final plainText = tester.widget<Text>(find.text('stdout line'));
      expect(plainText.style?.fontFamily, endsWith(HiveFontFamilies.mono));
    });

    testWidgets(
      'collapsible blocks start collapsed, toggle via tap/Enter/Space, '
      'and expose expanded semantics',
      (tester) async {
        final controller = HiveTranscriptController(
          initialBlocks: const <HiveTranscriptBlock>[
            HiveTranscriptThinking(id: 'th', text: 'Hidden thinking body'),
            HiveTranscriptToolCall(
              id: 'tc',
              name: 'run_tests',
              input: 'first preview line\nsecond body line',
            ),
            HiveTranscriptToolResult(id: 'tr', text: 'Hidden tool output'),
          ],
        );
        addTearDown(controller.dispose);
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_view(controller));

          expect(find.text('Hidden thinking body'), findsNothing);
          expect(
            find.text('first preview line\nsecond body line'),
            findsNothing,
          );
          expect(find.text('Hidden tool output'), findsNothing);

          final thinkingNode = find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Thinking',
          );
          expect(
            tester.getSemantics(thinkingNode).flagsCollection.isExpanded,
            Tristate.isFalse,
          );

          // Tap expands.
          await tester.tap(find.text('Thinking'));
          await tester.pumpAndSettle();
          expect(find.text('Hidden thinking body'), findsOneWidget);
          expect(
            tester.getSemantics(thinkingNode).flagsCollection.isExpanded,
            Tristate.isTrue,
          );

          // Keyboard Enter and Space toggle.
          Focus.of(tester.element(find.text('Tool result'))).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.text('Hidden tool output'), findsOneWidget);

          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(find.text('Hidden tool output'), findsNothing);
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'upsert with same id replaces in place and keeps expanded state',
      (tester) async {
        final controller = HiveTranscriptController(
          initialBlocks: const <HiveTranscriptBlock>[
            HiveTranscriptMessage(id: 'm1', markdown: 'Before'),
            HiveTranscriptToolResult(id: 'tr1', text: 'Initial output'),
            HiveTranscriptMessage(id: 'm2', markdown: 'After'),
          ],
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(_view(controller));

        await tester.tap(find.text('Tool result'));
        await tester.pumpAndSettle();
        expect(find.text('Initial output'), findsOneWidget);

        controller.upsert(
          const HiveTranscriptToolResult(id: 'tr1', text: 'Updated output'),
        );
        await tester.pumpAndSettle();

        expect(controller.length, 3);
        expect(controller.blocks[1].id, 'tr1');
        expect(find.text('Initial output'), findsNothing);
        expect(find.text('Updated output'), findsOneWidget);
      },
    );

    testWidgets('cuts bodies over 200 lines and toggles Show all / Show less', (
      tester,
    ) async {
      final lines = <String>[for (var i = 1; i <= 250; i++) 'line $i']
          .join('\n');
      final controller = HiveTranscriptController(
        initialBlocks: <HiveTranscriptBlock>[
          HiveTranscriptToolResult(id: 'big', text: lines),
        ],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(controller, height: 600));

      await tester.tap(find.text('Tool result'));
      await tester.pumpAndSettle();

      expect(find.textContaining('line 201'), findsNothing);
      expect(find.text('Show all (250 lines)'), findsOneWidget);

      await tester.ensureVisible(find.text('Show all (250 lines)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all (250 lines)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('line 201'), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);

      await tester.ensureVisible(find.text('Show less'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();

      expect(find.textContaining('line 201'), findsNothing);
      expect(find.text('Show all (250 lines)'), findsOneWidget);
    });

    testWidgets('cuts error blocks over 200 lines and toggles Show all', (
      tester,
    ) async {
      final lines = <String>[for (var i = 1; i <= 250; i++) 'err line $i']
          .join('\n');
      final controller = HiveTranscriptController(
        initialBlocks: <HiveTranscriptBlock>[
          HiveTranscriptError(id: 'big-err', message: lines),
        ],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(controller, height: 600));

      expect(find.textContaining('err line 201'), findsNothing);
      expect(find.text('Show all (250 lines)'), findsOneWidget);

      await tester.ensureVisible(find.text('Show all (250 lines)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all (250 lines)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('err line 201'), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets(
      'does not count a single trailing newline as an extra line for cut',
      (tester) async {
        final joined = <String>[for (var i = 1; i <= 200; i++) 'line $i']
            .join('\n');
        final lines = '$joined\n';
        final controller = HiveTranscriptController(
          initialBlocks: <HiveTranscriptBlock>[
            HiveTranscriptMessage(id: 'exact-200', markdown: lines),
          ],
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(_view(controller, height: 600));

        expect(find.textContaining('Show all'), findsNothing);
      },
    );

    testWidgets('builds items lazily for 500 blocks', (tester) async {
      final controller = HiveTranscriptController();
      addTearDown(controller.dispose);
      _fill(controller, 500);
      await tester.pumpWidget(_view(controller, height: 400));

      expect(find.text('entry 499', skipOffstage: false), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('entry 499'), findsOneWidget);
      expect(find.text('entry 0', skipOffstage: false), findsNothing);
    });

    testWidgets('follows new blocks while at the bottom', (tester) async {
      final controller = HiveTranscriptController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(controller, height: 200));
      _fill(controller, 60);
      await tester.pumpAndSettle();

      final state = tester.state<HiveTranscriptViewState>(
        find.byType(HiveTranscriptView),
      );
      final position = _position(tester);
      expect(state.isFollowing, isTrue);
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, position.maxScrollExtent);
      expect(find.text('entry 59'), findsOneWidget);

      controller.upsert(
        const HiveTranscriptPlainText(id: 'new', text: 'newest entry'),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(find.text('newest entry'), findsOneWidget);
      expect(find.text(_labels.jumpToBottom), findsNothing);
    });

    testWidgets('scrolling up pauses following and Jump to bottom resumes', (
      tester,
    ) async {
      final controller = HiveTranscriptController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(controller, height: 200));
      _fill(controller, 60);
      await tester.pumpAndSettle();

      await tester.drag(find.text('entry 59'), const Offset(0, 300));
      await tester.pumpAndSettle();
      final state = tester.state<HiveTranscriptViewState>(
        find.byType(HiveTranscriptView),
      );
      final position = _position(tester);
      final paused = position.pixels;
      expect(state.isFollowing, isFalse);
      expect(paused, lessThan(position.maxScrollExtent));
      expect(find.text(_labels.jumpToBottom), findsOneWidget);

      controller.upsert(
        const HiveTranscriptPlainText(id: 'new', text: 'newest entry'),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, paused);

      await tester.tap(find.text(_labels.jumpToBottom));
      await tester.pumpAndSettle();
      expect(state.isFollowing, isTrue);
      expect(position.pixels, position.maxScrollExtent);
      expect(find.text('newest entry'), findsOneWidget);
      expect(find.text(_labels.jumpToBottom), findsNothing);
    });

    testWidgets('scrolling back to the bottom resumes following', (
      tester,
    ) async {
      final controller = HiveTranscriptController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(controller, height: 200));
      _fill(controller, 60);
      await tester.pumpAndSettle();

      await tester.drag(find.text('entry 59'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text(_labels.jumpToBottom), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text(_labels.jumpToBottom), findsNothing);
    });

    testWidgets(
      'expanding a block while following pauses following and keeps offset',
      (tester) async {
        final longResult = <String>[
          for (var i = 1; i <= 60; i++) 'result line $i',
        ].join('\n');
        final controller = HiveTranscriptController(
          initialBlocks: <HiveTranscriptBlock>[
            for (var i = 0; i < 30; i++)
              HiveTranscriptPlainText(id: 'p-$i', text: 'entry $i'),
            HiveTranscriptToolResult(id: 'tr-tail', text: longResult),
          ],
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(_view(controller, height: 300));
        await tester.pumpAndSettle();

        final state = tester.state<HiveTranscriptViewState>(
          find.byType(HiveTranscriptView),
        );
        expect(state.isFollowing, isTrue);

        await tester.tap(find.text('Tool result'));
        await tester.pumpAndSettle();

        expect(state.isFollowing, isFalse);
        expect(find.text(_labels.jumpToBottom), findsOneWidget);
        final offsetAfterExpand = _position(tester).pixels;

        controller.upsert(
          const HiveTranscriptPlainText(id: 'new', text: 'newest entry'),
        );
        await tester.pumpAndSettle();
        expect(_position(tester).pixels, offsetAfterExpand);
      },
    );

    testWidgets('swapping controller resets expanded and show-all state', (
      tester,
    ) async {
      final longText = <String>[for (var i = 1; i <= 220; i++) 'line $i']
          .join('\n');
      final controller1 = HiveTranscriptController(
        initialBlocks: <HiveTranscriptBlock>[
          HiveTranscriptMessage(id: 'msg', markdown: longText),
          const HiveTranscriptToolResult(id: 'tr', text: 'first body'),
        ],
      );
      final controller2 = HiveTranscriptController(
        initialBlocks: <HiveTranscriptBlock>[
          HiveTranscriptMessage(id: 'msg', markdown: longText),
          const HiveTranscriptToolResult(id: 'tr', text: 'second body'),
        ],
      );
      addTearDown(controller1.dispose);
      addTearDown(controller2.dispose);

      await tester.pumpWidget(_view(controller1, height: 600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tool result'));
      await tester.pumpAndSettle();
      expect(find.text('first body'), findsOneWidget);

      await tester.ensureVisible(find.text('Show all (220 lines)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all (220 lines)'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);

      await tester.pumpWidget(_view(controller2, height: 600));
      await tester.pumpAndSettle();

      expect(find.text('second body'), findsNothing);
      expect(find.text('Show all (220 lines)'), findsOneWidget);
    });

    testWidgets('tool call exposes input preview in semantics value', (
      tester,
    ) async {
      final controller = HiveTranscriptController(
        initialBlocks: const <HiveTranscriptBlock>[
          HiveTranscriptToolCall(
            id: 'tc',
            name: 'read_file',
            input: 'path: lib/main.dart\nline: 1',
          ),
        ],
      );
      addTearDown(controller.dispose);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_view(controller));
        final toolNode = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'read_file',
        );
        expect(tester.getSemantics(toolNode).value, 'path: lib/main.dart');
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'long tool name shows Tooltip and unbroken body wraps cleanly',
      (tester) async {
        const longName =
            'very_long_tool_name_that_ellipsizes_in_a_narrow_transcript_pane';
        final longUnbroken = 'x' * 240;
        final controller = HiveTranscriptController(
          initialBlocks: <HiveTranscriptBlock>[
            HiveTranscriptToolCall(
              id: 'tc',
              name: longName,
              input: longUnbroken,
            ),
          ],
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(_view(controller, width: 260, height: 300));

        final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip));
        expect(tooltips.any((t) => t.message == longName), isTrue);

        await tester.tap(find.text(longName));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('final result renders only supplied metric chips', (
      tester,
    ) async {
      final controller = HiveTranscriptController(
        initialBlocks: const <HiveTranscriptBlock>[
          HiveTranscriptFinalResult(
            id: 'fin',
            statusLabel: 'Completed',
            tone: HiveFeedbackTone.success,
            metrics: <HiveTranscriptMetric>[
              HiveTranscriptMetric(label: 'Cost', value: r'$0.04'),
            ],
          ),
        ],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(controller));

      expect(find.byType(HiveReadOnlyChip), findsOneWidget);
      expect(find.text(r'Cost: $0.04'), findsOneWidget);
    });

    testWidgets('stderr plain text uses stderr-marker and danger color', (
      tester,
    ) async {
      final controller = HiveTranscriptController(
        initialBlocks: const <HiveTranscriptBlock>[
          HiveTranscriptPlainText(
            id: 'err',
            text: 'fatal: auth expired',
            stream: HiveLogStream.stderr,
          ),
        ],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_view(controller));

      expect(
        find.byKey(const ValueKey<String>('stderr-marker')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Error: fatal: auth expired'),
        findsOneWidget,
      );
      final text = tester.widget<Text>(find.text('fatal: auth expired'));
      expect(text.style?.color, HiveColors.dark.danger);
    });

    for (final entry in <String, ThemeData>{
      'dark': HiveTheme.dark(),
      'light': HiveTheme.light(),
    }.entries) {
      testWidgets('meets accessibility guidelines (${entry.key})', (
        tester,
      ) async {
        final controller = HiveTranscriptController(
          initialBlocks: const <HiveTranscriptBlock>[
            HiveTranscriptMessage(id: 'm1', markdown: 'Checked files.'),
            HiveTranscriptThinking(id: 'th', text: 'Planning next edit'),
            HiveTranscriptToolCall(
              id: 'tc',
              name: 'edit_file',
              input: 'lib/app.dart',
            ),
            HiveTranscriptToolResult(id: 'tr', text: 'Updated 1 file'),
            HiveTranscriptError(id: 'err', message: 'Lint warning'),
            HiveTranscriptFinalResult(
              id: 'fin',
              statusLabel: 'Succeeded',
              tone: HiveFeedbackTone.success,
              metrics: <HiveTranscriptMetric>[
                HiveTranscriptMetric(label: 'Tokens', value: '1,240'),
              ],
            ),
            HiveTranscriptPlainText(id: 'pt', text: 'Done'),
          ],
        );
        addTearDown(controller.dispose);
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _view(controller, theme: entry.value, height: 800),
          );
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          handle.dispose();
        }
      });
    }
  });
}
