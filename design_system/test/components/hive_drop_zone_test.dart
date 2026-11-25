import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

const _caption = 'Drop images to attach';

void main() {
  group('HiveDropZone', () {
    testWidgets('idle has opacity 0, shows child, and adds no semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(
            child: const HiveDropZone(
              active: false,
              caption: _caption,
              child: Text('Drop target child'),
            ),
          ),
        );

        final opacity = tester.widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(HiveDropZone),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(opacity.opacity, 0);
        expect(find.text('Drop target child'), findsOneWidget);
        expect(find.bySemanticsLabel(_caption), findsNothing);
      } finally {
        handle.dispose();
      }
    });

    for (final entry in <String, ({ThemeData theme, HiveColors colors})>{
      'dark': (theme: HiveTheme.dark(), colors: HiveColors.dark),
      'light': (theme: HiveTheme.light(), colors: HiveColors.light),
    }.entries) {
      testWidgets(
        'active uses scrim, focusRing border and radiusPanel (${entry.key})',
        (tester) async {
          await tester.pumpWidget(
            hiveTestApp(
              theme: entry.value.theme,
              child: const HiveDropZone(
                active: true,
                caption: _caption,
                child: SizedBox(width: 200, height: 120),
              ),
            ),
          );

          final decorated = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(HiveDropZone),
                  matching: find.byType(DecoratedBox),
                )
                .last,
          );
          final decoration = decorated.decoration as BoxDecoration;
          expect(
            decoration.color,
            entry.value.colors.background.withValues(
              alpha: entry.value.colors.scrimOpacity,
            ),
          );
          expect(decoration.borderRadius, HiveRadii.standard.panel);
          final border = decoration.border! as Border;
          expect(border.top.color, entry.value.colors.focusRing);
          expect(border.top.width, HiveElevation.dark.focusRingWidth);
          expect(find.text(_caption), findsOneWidget);
        },
      );
    }

    testWidgets(
      'semantics announce live region when active and preserve child',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            hiveTestApp(
              child: const HiveDropZone(
                active: false,
                caption: _caption,
                child: Text('Child label'),
              ),
            ),
          );
          expect(find.bySemanticsLabel('Child label'), findsOneWidget);
          expect(find.bySemanticsLabel(_caption), findsNothing);

          await tester.pumpWidget(
            hiveTestApp(
              child: const HiveDropZone(
                active: true,
                caption: _caption,
                child: Text('Child label'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Child label'), findsOneWidget);
          expect(
            tester.getSemantics(find.bySemanticsLabel(_caption)),
            matchesSemantics(label: _caption, isLiveRegion: true),
          );
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets('pointer events pass through to child when active', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveDropZone(
            active: true,
            caption: _caption,
            child: HiveButton(label: 'Tap me', onPressed: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      expect(tapped, isTrue);
    });

    testWidgets('respects MediaQuery.disableAnimations', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: hiveTestApp(
            child: const HiveDropZone(
              active: true,
              caption: _caption,
              child: SizedBox(),
            ),
          ),
        ),
      );

      final reduced = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(reduced.duration, Duration.zero);

      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveDropZone(
            active: true,
            caption: _caption,
            child: SizedBox(),
          ),
        ),
      );

      final normal = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(normal.duration, HiveMotionTokens.standard.short);
    });
  });
}
