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

    test('cancelling is a stop ring in warning', () {
      expect(HiveNodeStatus.cancelling.shape, isA<HiveStopRingShape>());
      expect(HiveNodeStatus.cancelling.shape.isAnimated, isTrue);
      for (final colors in <HiveColors>[HiveColors.dark, HiveColors.light]) {
        expect(HiveNodeStatus.cancelling.color(colors), colors.warning);
      }
    });

    test('cancellationUncertain is an alert triangle in danger', () {
      expect(
        HiveNodeStatus.cancellationUncertain.shape,
        isA<HiveAlertTriangleShape>(),
      );
      expect(HiveNodeStatus.cancellationUncertain.shape.isAnimated, isFalse);
      for (final colors in <HiveColors>[HiveColors.dark, HiveColors.light]) {
        expect(
          HiveNodeStatus.cancellationUncertain.color(colors),
          colors.danger,
        );
      }
    });

    test('only cancelling animates', () {
      expect(
        HiveNodeStatus.values.where((s) => s.shape.isAnimated),
        <HiveNodeStatus>[HiveNodeStatus.cancelling],
      );
    });

    test('every status color reaches 3:1 as UI on every surface', () {
      for (final colors in <HiveColors>[HiveColors.dark, HiveColors.light]) {
        for (final status in HiveNodeStatus.values) {
          for (final surface in colors.surfaces.entries) {
            expect(
              HiveContrast.ratio(status.color(colors), surface.value),
              greaterThanOrEqualTo(HiveContrastLevel.ui.minimumRatio),
              reason: '${status.name} on ${surface.key}',
            );
          }
        }
      }
    });

    testWidgets('cancelling loops its transition while animations run', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveStatusDot(
            status: HiveNodeStatus.cancelling,
            semanticLabel: 'Cancelling',
          ),
        ),
      );

      final painter = _painterOf(tester);
      expect(painter.animation, isNotNull);
      final start = painter.animation!.value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(painter.animation!.value, isNot(start));
      expect(tester.hasRunningAnimations, isTrue);

      // Switching to a still status stops the loop.
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveStatusDot(
            status: HiveNodeStatus.cancelled,
            semanticLabel: 'Cancelled',
          ),
        ),
      );
      expect(_painterOf(tester).animation, isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('cancelling is still when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: hiveTestApp(
            child: const HiveStatusDot(
              status: HiveNodeStatus.cancelling,
              semanticLabel: 'Cancelling',
            ),
          ),
        ),
      );

      expect(_painterOf(tester).animation, isNull);
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('Cancelling'), findsOneWidget);
    });

    for (final status in <HiveNodeStatus>[
      HiveNodeStatus.interrupted,
      HiveNodeStatus.cancelled,
      HiveNodeStatus.cancelling,
      HiveNodeStatus.cancellationUncertain,
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
      const HiveStopRingShape()
        ..paint(canvas, rect, HiveColors.dark.warning)
        ..paintFrame(canvas, rect, HiveColors.dark.warning, 0.5);
      const HiveAlertTriangleShape().paint(
        canvas,
        rect,
        HiveColors.dark.danger,
      );
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

HiveStatusShapePainter _painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(HiveStatusDot),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as HiveStatusShapePainter;
}
