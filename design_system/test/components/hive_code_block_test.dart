import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

const String _payload = '''
{
  "runId": "run_01HZX4",
  "node": "review_pull_request",
  "status": "interrupted",
  "checkpoint": {
    "sequence": 42,
    "reason": "backend restarted while the harness was running"
  }
}''';

void main() {
  group('HiveCodeBlock', () {
    testWidgets('renders multiline JSON as selectable mono text', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveCodeBlock(code: _payload)),
      );

      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.data, _payload);
      expect(text.style?.fontFamily, contains(HiveFontFamilies.mono));
      expect(text.style?.color, HiveColors.dark.onSurface);
    });

    testWidgets('uses surface1, hairline border and radiusCard', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveCodeBlock(code: '{}')),
      );

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(HiveCodeBlock),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, HiveColors.dark.surface1);
      expect(decoration.borderRadius, HiveRadii.standard.card);
      expect(decoration.border?.top.color, HiveColors.dark.borderSubtle);
    });

    testWidgets('shows the title header only when given', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveCodeBlock(code: '{}')),
      );
      expect(find.byType(HiveIconButton), findsNothing);

      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveCodeBlock(code: '{}', title: 'payload'),
        ),
      );
      expect(find.text('payload'), findsOneWidget);
      expect(find.byType(HiveIconButton), findsNothing);
    });

    testWidgets('empty code shows the empty label', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveCodeBlock(code: '', emptyLabel: 'No payload'),
        ),
      );

      expect(find.text('No payload'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('empty code without a label renders an empty block', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveCodeBlock(code: '')),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('maxHeight caps the body and scrolls long payloads', (
      tester,
    ) async {
      final long = List<String>.generate(
        200,
        (i) => '  "line$i": "${'x' * 160}",',
      ).join('\n');
      await tester.pumpWidget(
        hiveTestApp(
          child: Center(
            child: SizedBox(
              width: 400,
              child: HiveCodeBlock(code: long, title: 'state', maxHeight: 160),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final viewports = find.descendant(
        of: find.byType(HiveCodeBlock),
        matching: find.byType(SingleChildScrollView),
      );
      expect(viewports, findsNWidgets(2));
      final vertical = tester.widget<SingleChildScrollView>(viewports.first);
      final horizontal = tester.widget<SingleChildScrollView>(viewports.last);
      expect(vertical.scrollDirection, Axis.vertical);
      expect(horizontal.scrollDirection, Axis.horizontal);
      expect(tester.getSize(viewports.first).height, 160);

      await tester.drag(viewports.first, const Offset(0, -300));
      await tester.pump();
      expect(vertical.controller!.offset, greaterThan(0));
      // Wide lines overflow horizontally instead of wrapping.
      final horizontalPosition = horizontal.controller!.position;
      expect(horizontalPosition.maxScrollExtent, greaterThan(0));
      horizontalPosition.jumpTo(horizontalPosition.maxScrollExtent);
      await tester.pump();
      expect(horizontal.controller!.offset, greaterThan(0));
    });

    testWidgets('copy button writes the code to the clipboard', (tester) async {
      final handle = tester.ensureSemantics();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var copiedCount = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveCodeBlock(
            code: _payload,
            title: 'payload',
            copyLabel: 'Copy payload',
            onCopied: () => copiedCount++,
          ),
        ),
      );

      expect(find.bySemanticsLabel('Copy payload'), findsOneWidget);
      await tester.tap(find.byType(HiveIconButton));
      await tester.pump();

      expect(copied, _payload);
      expect(copiedCount, 1);
      handle.dispose();
    });
  });
}
