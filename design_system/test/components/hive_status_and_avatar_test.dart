import 'dart:ui' show PictureRecorder;

import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  group('HiveStatusDot', () {
    testWidgets('exposes distinct shape and semanticLabel per status', (
      tester,
    ) async {
      final seenShapes = <Type>{};

      for (final status in HiveNodeStatus.values) {
        seenShapes.add(status.shape.runtimeType);
        await tester.pumpWidget(
          hiveTestApp(
            child: HiveStatusDot(
              status: status,
              semanticLabel: 'Status ${status.name}',
            ),
          ),
        );

        expect(find.bySemanticsLabel('Status ${status.name}'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }

      expect(seenShapes.length, HiveNodeStatus.values.length);
    });

    test('interrupted is a half-filled ring in warning', () {
      expect(HiveNodeStatus.interrupted.shape, isA<HiveHalfDiscShape>());
      expect(
        HiveNodeStatus.interrupted.color(HiveColors.dark),
        HiveColors.dark.warning,
      );
      expect(
        HiveNodeStatus.interrupted.color(HiveColors.light),
        HiveColors.light.warning,
      );
    });

    test('cancelled is a cross in statusIdle, distinct from idle', () {
      expect(HiveNodeStatus.cancelled.shape, isA<HiveCrossShape>());
      expect(
        HiveNodeStatus.cancelled.color(HiveColors.dark),
        HiveColors.dark.statusIdle,
      );
      expect(
        HiveNodeStatus.cancelled.color(HiveColors.light),
        HiveColors.light.statusIdle,
      );
      // Same color as idle, so the shape alone must tell them apart.
      expect(
        HiveNodeStatus.cancelled.shape.runtimeType,
        isNot(HiveNodeStatus.idle.shape.runtimeType),
      );
    });

    for (final status in <HiveNodeStatus>[
      HiveNodeStatus.interrupted,
      HiveNodeStatus.cancelled,
    ]) {
      testWidgets('${status.name} paints its shape in its color', (
        tester,
      ) async {
        await tester.pumpWidget(
          hiveTestApp(
            theme: HiveTheme.light(),
            child: HiveStatusDot(
              status: status,
              semanticLabel: status.name,
              size: 24,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel(status.name), findsOneWidget);
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(HiveStatusDot),
            matching: find.byType(CustomPaint),
          ),
        );
        final painter = paint.painter! as HiveStatusShapePainter;
        expect(painter.shape, same(status.shape));
        expect(painter.color, status.color(HiveColors.light));
        expect(tester.getSize(find.byType(HiveStatusDot)), const Size(24, 24));
      });
    }

    testWidgets('new shapes paint onto a canvas', (tester) async {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const rect = Rect.fromLTWH(0, 0, 16, 16);
      const HiveHalfDiscShape().paint(canvas, rect, HiveColors.dark.warning);
      const HiveCrossShape().paint(canvas, rect, HiveColors.dark.statusIdle);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });
  });

  group('HiveConnectionIndicator', () {
    testWidgets('announces label as live region for every connection state', (
      tester,
    ) async {
      for (final state in HiveConnectionState.values) {
        await tester.pumpWidget(
          hiveTestApp(
            child: HiveConnectionIndicator(
              state: state,
              label: 'Backend ${state.name}',
            ),
          ),
        );

        expect(find.text('Backend ${state.name}'), findsOneWidget);
        expect(find.bySemanticsLabel('Backend ${state.name}'), findsOneWidget);
      }
    });
  });

  group('NodeVisualRegistry & HiveAgentAvatar', () {
    test('resolves registered visual and falls back for unknown types', () {
      final registry = NodeVisualRegistry();
      const custom = NodeVisual(
        icon: HiveIcons.harnessCodex,
        labelKey: 'nodeTypeCodex',
      );
      registry.register('codex', custom);

      expect(registry.contains('codex'), isTrue);
      expect(registry.resolve('codex'), custom);
      expect(registry.resolve('unknown'), NodeVisual.fallback);
      expect(
        () => registry.register('codex', custom),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('renders visual from registry and combines status semantics', (
      tester,
    ) async {
      final registry = NodeVisualRegistry()
        ..register(
          'codex',
          const NodeVisual(
            icon: HiveIcons.harnessCodex,
            labelKey: 'nodeTypeCodex',
          ),
        );

      await tester.pumpWidget(
        hiveTestApp(
          registry: registry,
          child: Builder(
            builder: (context) {
              final visual = NodeVisualScope.of(context).resolve('codex');
              return HiveAgentAvatar(
                visual: visual,
                semanticLabel: 'Codex agent',
                status: HiveNodeStatus.running,
                statusLabel: 'Running',
              );
            },
          ),
        ),
      );

      expect(find.bySemanticsLabel('Codex agent, Running'), findsOneWidget);
      expect(find.byType(HiveStatusDot), findsOneWidget);
    });

    testWidgets('omits HiveStatusDot when status is null', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveAgentAvatar(
            visual: NodeVisual.fallback,
            semanticLabel: 'Fallback agent',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Fallback agent'), findsOneWidget);
      expect(find.byType(HiveStatusDot), findsNothing);
    });
  });
}
