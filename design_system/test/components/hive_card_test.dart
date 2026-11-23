import 'dart:ui';

import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  group('HiveCard', () {
    testWidgets('busy card ignores tap, Enter and Space even with onPressed', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        hiveTestApp(
          child: SizedBox(
            width: 480,
            child: HiveCard(
              busy: true,
              semanticLabel: 'Open Release Flow',
              onPressed: () => tapped++,
              child: const Text('Release Flow'),
            ),
          ),
        ),
      );

      final card = find.byType(HiveCard);
      expect(
        find.descendant(of: card, matching: find.byType(HiveInteraction)),
        findsNothing,
      );

      await tester.tap(card);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(tapped, 0);
    });

    testWidgets('busy card announces statusLabel as a live-region value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(
            child: const SizedBox(
              width: 480,
              child: HiveCard(
                busy: true,
                semanticLabel: 'Open Release Flow',
                statusLabel: 'Deleting…',
                child: Text('Release Flow'),
              ),
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(HiveCard)),
          isSemantics(
            label: 'Open Release Flow',
            value: 'Deleting…',
            isLiveRegion: true,
          ),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets("changing statusLabel updates the same node's value", (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        Widget buildCard(String status) => hiveTestApp(
          child: SizedBox(
            width: 480,
            child: HiveCard(
              busy: true,
              semanticLabel: 'Open Release Flow',
              statusLabel: status,
              child: const Text('Release Flow'),
            ),
          ),
        );

        await tester.pumpWidget(buildCard('Deleting…'));
        final firstNode = tester.getSemantics(find.byType(HiveCard));
        final nodeId = firstNode.id;

        await tester.pumpWidget(buildCard('Deleting… (removing runs)'));
        final secondNode = tester.getSemantics(find.byType(HiveCard));

        expect(secondNode.id, nodeId);
        expect(
          secondNode,
          isSemantics(
            label: 'Open Release Flow',
            value: 'Deleting… (removing runs)',
            isLiveRegion: true,
          ),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('busy card keeps child semantics reachable', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(
            child: const SizedBox(
              width: 480,
              child: HiveCard(
                busy: true,
                semanticLabel: 'Open Release Flow',
                statusLabel: 'Deleting…',
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text('Release Flow')),
                    HiveIconButton(
                      icon: HiveIcons.copy,
                      semanticLabel: 'Duplicate workflow',
                      onPressed: null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Duplicate workflow'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('busy card draws like a static card', (tester) async {
      final theme = HiveTheme.dark();
      await tester.pumpWidget(
        hiveTestApp(
          theme: theme,
          child: SizedBox(
            width: 480,
            child: HiveCard(
              busy: true,
              semanticLabel: 'Open Release Flow',
              onPressed: () {},
              child: const Text('Release Flow'),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(HiveCard)));
      await tester.pumpAndSettle();

      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(HiveCard),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      final colors = theme.extension<HiveColors>()!;
      expect(decoration.color, HiveCardSurface.surface1.color(colors));
    });

    testWidgets('busy card meets the labeled tap target guideline', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(
            child: const SizedBox(
              width: 480,
              child: HiveCard(
                busy: true,
                semanticLabel: 'Open Release Flow',
                statusLabel: 'Deleting…',
                child: Text('Release Flow'),
              ),
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('busy without semanticLabel asserts', (tester) async {
      expect(
        () => HiveCard(busy: true, child: const SizedBox()),
        throwsAssertionError,
      );
    });

    testWidgets('statusLabel without busy asserts', (tester) async {
      expect(
        () => HiveCard(
          statusLabel: 'x',
          semanticLabel: 'y',
          child: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'interactive card fires onPressed and is announced as a button',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          var tapped = 0;
          await tester.pumpWidget(
            hiveTestApp(
              child: SizedBox(
                width: 480,
                child: HiveCard(
                  semanticLabel: 'Open Release Flow',
                  onPressed: () => tapped++,
                  child: const Text('Release Flow'),
                ),
              ),
            ),
          );

          await tester.tap(find.byType(HiveCard));
          await tester.pump();

          expect(tapped, 1);
          expect(
            tester.getSemantics(find.byType(HiveCard)),
            isSemantics(label: 'Open Release Flow', isButton: true),
          );
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets('static labelled card exposes its label', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(
            child: const SizedBox(
              width: 480,
              child: HiveCard(
                semanticLabel: 'Release Flow summary',
                child: Text('Release Flow'),
              ),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp('Release Flow summary')),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });
  });
}
