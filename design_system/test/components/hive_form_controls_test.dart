import 'dart:ui' show Tristate;

import 'package:design_system/design_system.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

const _outputs = <HiveSelectOption<String>>[
  HiveSelectOption<String>(value: 'onSuccess', label: 'On success'),
  HiveSelectOption<String>(value: 'onFailure', label: 'On failure'),
  HiveSelectOption<String>(value: 'custom', label: 'Custom label'),
];

ShapeDecoration _wellDecoration(WidgetTester tester, Finder field) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(of: field, matching: find.byType(AnimatedContainer)).first,
  );
  return container.decoration! as ShapeDecoration;
}

void main() {
  group('HiveTextField', () {
    testWidgets('reports edits and exposes its label to semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final edits = <String>[];
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveTextField(
            label: 'Workflow name',
            hint: 'Release checklist',
            onChanged: edits.add,
          ),
        ),
      );

      expect(find.text('Workflow name'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Workflow name')), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Nightly triage');
      expect(edits.last, 'Nightly triage');
      handle.dispose();
    });

    testWidgets('tapping the well focuses the input and shows the ring', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveTextField(label: 'Description', focusNode: focusNode),
        ),
      );
      expect(find.byType(HiveFocusRing), findsOneWidget);
      expect(
        tester.widget<HiveFocusRing>(find.byType(HiveFocusRing)).focused,
        isFalse,
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
      expect(
        tester.widget<HiveFocusRing>(find.byType(HiveFocusRing)).focused,
        isTrue,
      );
    });

    testWidgets('error text replaces helper text and turns the hairline '
        'danger', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveTextField(
            label: 'Workflow name',
            helperText: 'Shown in the workflow list.',
            errorText: 'Name is required.',
          ),
        ),
      );

      expect(find.text('Name is required.'), findsOneWidget);
      expect(find.text('Shown in the workflow list.'), findsNothing);
      final shape =
          _wellDecoration(tester, find.byType(HiveTextField)).shape
              as OutlinedBorder;
      expect(shape.side.color, HiveColors.dark.danger);
    });

    testWidgets('single-line is a pill and multi-line uses radiusCard', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const Column(
            children: <Widget>[
              HiveTextField(label: 'Name'),
              HiveTextField(label: 'Description', multiline: true),
            ],
          ),
        ),
      );

      final fields = find.byType(HiveTextField);
      expect(_wellDecoration(tester, fields.at(0)).shape, isA<StadiumBorder>());
      final multi =
          _wellDecoration(tester, fields.at(1)).shape as RoundedRectangleBorder;
      expect(
        multi.borderRadius,
        BorderRadius.circular(HiveRadii.standard.radiusCard),
      );
    });

    testWidgets('works without a Scaffold or Material ancestor', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: HiveTheme.light(),
          home: const Center(child: HiveTextField(label: 'Workflow name')),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('disabled field rejects focus', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveTextField(
            label: 'Name',
            enabled: false,
            focusNode: focusNode,
          ),
        ),
      );

      await tester.tap(find.byType(HiveTextField), warnIfMissed: false);
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('labelled field meets the labeled tap target guideline', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(
            child: const SizedBox(
              width: 600,
              child: HiveTextField(
                label: 'Search workflows',
                hint: 'Filter by name or description...',
              ),
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'semanticLabel-only field with leading icon meets the guideline',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            hiveTestApp(
              child: const SizedBox(
                width: 600,
                child: HiveTextField(
                  semanticLabel: 'Search agents',
                  hint: 'Filter agents...',
                  leadingIcon: HiveIcons.search,
                ),
              ),
            ),
          );

          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets('multi-line field meets the guideline', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(
            child: const SizedBox(
              width: 600,
              child: HiveTextField(label: 'Notes', maxLines: 4),
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the well adds no tappable semantics node of its own', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(
            child: const SizedBox(
              width: 600,
              child: HiveTextField(label: 'Search workflows'),
            ),
          ),
        );

        final root = tester.getSemantics(find.byType(HiveTextField));
        final tapNodes = <SemanticsNode>[];
        void visit(SemanticsNode node) {
          if (node.getSemanticsData().hasAction(SemanticsAction.tap)) {
            tapNodes.add(node);
          }
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(root);
        expect(tapNodes, hasLength(1));
        expect(
          tapNodes.single,
          isSemantics(isTextField: true, label: 'Search workflows'),
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('HiveSelect', () {
    testWidgets('select meets the labeled tap target guideline', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          hiveTestApp(
            child: SizedBox(
              width: 600,
              child: HiveSelect<String>(
                label: 'Source output',
                options: _outputs,
                value: 'onSuccess',
                onChanged: (_) {},
              ),
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('shows the chosen option and picks a new one from the menu', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        hiveTestApp(
          child: SizedBox(
            width: 320,
            child: HiveSelect<String>(
              label: 'Source output',
              options: _outputs,
              value: 'onSuccess',
              onChanged: (value) => picked = value,
            ),
          ),
        ),
      );

      expect(find.text('On success'), findsOneWidget);
      expect(find.text('On failure'), findsNothing);

      await tester.tap(find.text('On success'));
      await tester.pumpAndSettle();

      expect(find.text('On failure'), findsOneWidget);
      await tester.tap(find.text('On failure'));
      await tester.pumpAndSettle();

      expect(picked, 'onFailure');
      expect(find.text('Custom label'), findsNothing);
    });

    testWidgets('shows the hint when no option matches the value', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveSelect<String>(
            label: 'Source output',
            hint: 'Choose an output',
            options: _outputs,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Choose an output'), findsOneWidget);
    });

    testWidgets('opens with the keyboard and announces label and value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      String? picked;
      await tester.pumpWidget(
        hiveTestApp(
          child: SizedBox(
            width: 320,
            child: HiveSelect<String>(
              label: 'Source output',
              options: _outputs,
              value: 'onSuccess',
              autofocus: true,
              onChanged: (value) => picked = value,
            ),
          ),
        ),
      );
      await tester.pump();

      final semantics = tester.getSemantics(
        find.bySemanticsLabel('Source output'),
      );
      expect(semantics.value, 'On success');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('On failure'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(picked, 'onFailure');
      handle.dispose();
    });

    testWidgets('Escape closes the menu without picking', (tester) async {
      String? picked;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveSelect<String>(
            label: 'Source output',
            options: _outputs,
            value: 'onSuccess',
            onChanged: (value) => picked = value,
          ),
        ),
      );

      await tester.tap(find.text('On success'));
      await tester.pumpAndSettle();
      expect(find.text('On failure'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('On failure'), findsNothing);
      expect(picked, isNull);
    });

    testWidgets('disabled select does not open', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveSelect<String>(
            label: 'Source output',
            options: _outputs,
            value: 'onSuccess',
            onChanged: null,
          ),
        ),
      );

      await tester.tap(find.text('On success'));
      await tester.pumpAndSettle();

      expect(find.text('On failure'), findsNothing);
    });
  });

  group('HiveSwitch', () {
    testWidgets('toggles on tap and on the visible label', (tester) async {
      var value = false;
      await tester.pumpWidget(
        hiveTestApp(
          child: StatefulBuilder(
            builder: (context, setState) => HiveSwitch(
              label: 'Entry node',
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(HiveSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);

      await tester.tap(find.text('Entry node'));
      await tester.pumpAndSettle();
      expect(value, isFalse);
    });

    testWidgets('toggles with Space when focused', (tester) async {
      bool? next;
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveSwitch(
            semanticLabel: 'Entry node',
            value: true,
            autofocus: true,
            onChanged: (value) => next = value,
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(next, isFalse);
    });

    testWidgets('is announced as a toggle with its state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveSwitch(
            label: 'Entry node',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      final node = find.bySemanticsLabel('Entry node');
      expect(
        tester.getSemantics(node),
        matchesSemantics(
          label: 'Entry node',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled switch is announced as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveSwitch(
            label: 'Entry node',
            value: false,
            onChanged: null,
          ),
        ),
      );

      await tester.tap(find.byType(HiveSwitch));
      await tester.pump();

      final data = tester.getSemantics(find.bySemanticsLabel('Entry node'));
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.flagsCollection.isToggled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('thumb moves without animation when animations are off', (
      tester,
    ) async {
      Widget build({required bool value}) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: hiveTestApp(
          child: HiveSwitch(
            semanticLabel: 'Entry node',
            value: value,
            onChanged: (_) {},
          ),
        ),
      );

      await tester.pumpWidget(build(value: false));
      await tester.pumpWidget(build(value: true));

      final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.duration, Duration.zero);
      expect(align.alignment, AlignmentDirectional.centerEnd);
    });

    testWidgets('helperText aligns with label left edge', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: SizedBox(
            width: 480,
            child: HiveSwitch(
              label: 'Auto-install skill',
              helperText: 'Installs for newly detected harnesses.',
              value: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final labelLeft = tester.getTopLeft(find.text('Auto-install skill')).dx;
      final helperLeft = tester
          .getTopLeft(find.text('Installs for newly detected harnesses.'))
          .dx;
      expect(helperLeft, labelLeft);
    });

    testWidgets(
      'tapping helperText does not toggle, tapping label still does',
      (tester) async {
        var value = false;
        await tester.pumpWidget(
          hiveTestApp(
            child: StatefulBuilder(
              builder: (context, setState) => HiveSwitch(
                label: 'Auto-install skill',
                helperText: 'Installs for newly detected harnesses.',
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Installs for newly detected harnesses.'));
        await tester.pumpAndSettle();
        expect(value, isFalse);

        await tester.tap(find.text('Auto-install skill'));
        await tester.pumpAndSettle();
        expect(value, isTrue);
      },
    );

    testWidgets('disabled switch dims helperText', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveSwitch(
            label: 'Auto-install skill',
            helperText: 'Installs for newly detected harnesses.',
            value: false,
            onChanged: null,
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Installs for newly detected harnesses.'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, HiveColors.dark.disabledOpacity);
    });

    testWidgets('helperText without label throws assertion error', (
      tester,
    ) async {
      expect(
        () => HiveSwitch(
          semanticLabel: 'Auto-install skill',
          helperText: 'Installs for newly detected harnesses.',
          value: false,
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'semantics keeps toggle on label and helper as its own text node',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            hiveTestApp(
              child: HiveSwitch(
                label: 'Auto-install skill',
                helperText: 'Installs for newly detected harnesses.',
                value: true,
                onChanged: (_) {},
              ),
            ),
          );

          expect(
            tester.getSemantics(find.bySemanticsLabel('Auto-install skill')),
            matchesSemantics(
              label: 'Auto-install skill',
              hasToggledState: true,
              isToggled: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
            ),
          );

          final helperNode = tester.getSemantics(
            find.bySemanticsLabel('Installs for newly detected harnesses.'),
          );
          expect(helperNode.label, 'Installs for newly detected harnesses.');
          expect(helperNode.flagsCollection.isToggled, Tristate.none);
          expect(
            helperNode.getSemanticsData().hasAction(SemanticsAction.tap),
            isFalse,
          );
        } finally {
          handle.dispose();
        }
      },
    );
  });

  group('Form control contrast (WCAG AA)', () {
    for (final entry in <String, HiveColors>{
      'dark': HiveColors.dark,
      'light': HiveColors.light,
    }.entries) {
      final colors = entry.value;
      // Helper and error text sit below the `surface3` well, on the form's
      // own surface: the background or a panel (surface1, surface2).
      for (final surface in colors.surfaces.entries.where(
        (s) => s.key != 'surface3',
      )) {
        test('${entry.key}: error text (danger) on ${surface.key}', () {
          expect(
            HiveContrast.ratio(colors.danger, surface.value),
            greaterThanOrEqualTo(HiveContrastLevel.text.minimumRatio),
          );
        });
      }
      test('${entry.key}: field text and hint on the surface3 well', () {
        expect(
          HiveContrast.ratio(colors.onSurface, colors.surface3),
          greaterThanOrEqualTo(HiveContrastLevel.text.minimumRatio),
        );
        expect(
          HiveContrast.ratio(colors.onSurfaceMuted, colors.surface3),
          greaterThanOrEqualTo(HiveContrastLevel.text.minimumRatio),
        );
      });
      test('${entry.key}: switch thumb against its track', () {
        expect(
          HiveContrast.ratio(colors.onAccent, colors.accent),
          greaterThanOrEqualTo(HiveContrastLevel.ui.minimumRatio),
        );
        expect(
          HiveContrast.ratio(colors.onSurfaceMuted, colors.surface3),
          greaterThanOrEqualTo(HiveContrastLevel.ui.minimumRatio),
        );
      });
      test('${entry.key}: danger button label', () {
        expect(
          HiveContrast.ratio(colors.onDanger, colors.danger),
          greaterThanOrEqualTo(HiveContrastLevel.text.minimumRatio),
        );
      });
    }
  });
}
