import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/fallback_list_editor.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _buildHost({
  required List<FallbackEntry> entries,
  Map<String, HarnessStatus>? statuses,
  double textScale = 1.0,
  double? width,
}) {
  return UncontrolledProviderScope(
    container: ProviderContainer.test(
      overrides: [harnessStatusByTypeIdProvider.overrideWithValue(statuses)],
    ),
    child: MaterialApp(
      theme: HiveTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: NodeVisualScope(
          registry: createNodeVisualRegistry(),
          child: Scaffold(
            body: SizedBox(
              width: width ?? HiveSpacing.standard.space8 * 6,
              child: SingleChildScrollView(
                child: FallbackListEditor(
                  nodeType: NodeTypeId.claudeCode,
                  entries: entries,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'semantics labels, target sizes, focus order, and warning badges',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          entries: const <FallbackEntry>[
            FallbackEntry(harness: NodeTypeId.codex, effort: 'high'),
            FallbackEntry(harness: NodeTypeId.geminiCli, effort: 'low'),
          ],
          statuses: const <String, HarnessStatus>{
            NodeTypeId.codex: HarnessStatus.notInstalled,
            NodeTypeId.geminiCli: HarnessStatus.authError,
          },
        ),
      );
      await tester.pumpAndSettle();

      // Accessible names for icon buttons
      expect(find.bySemanticsLabel('Move fallback 1 up'), findsOneWidget);
      expect(find.bySemanticsLabel('Move fallback 1 down'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove fallback 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Move fallback 2 up'), findsOneWidget);
      expect(find.bySemanticsLabel('Move fallback 2 down'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove fallback 2'), findsOneWidget);

      // Warning badge text in semantics
      expect(find.bySemanticsLabel('Codex is not installed'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Gemini CLI is not signed in'),
        findsOneWidget,
      );

      // Minimum target size on icon buttons
      for (final key in const <Key>[
        Key('config_fallback_0_up'),
        Key('config_fallback_0_down'),
        Key('config_fallback_0_remove'),
        Key('config_fallback_1_up'),
        Key('config_fallback_1_down'),
        Key('config_fallback_1_remove'),
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(32));
        expect(size.height, greaterThanOrEqualTo(32));
      }

      // Focus order per row: harness -> model -> effort -> up -> down ->
      // remove -> Add
      final h0 = tester.getTopLeft(
        find.byKey(const Key('config_fallback_0_harness')),
      );
      final m0 = tester.getTopLeft(
        find.byKey(const Key('config_fallback_0_model')),
      );
      final e0 = tester.getTopLeft(
        find.byKey(const Key('config_fallback_0_effort')),
      );
      final up0 = tester.getTopLeft(
        find.byKey(const Key('config_fallback_0_up')),
      );
      final down0 = tester.getTopLeft(
        find.byKey(const Key('config_fallback_0_down')),
      );
      final rem0 = tester.getTopLeft(
        find.byKey(const Key('config_fallback_0_remove')),
      );
      final add = tester.getTopLeft(
        find.byKey(const Key('config_fallback_add')),
      );

      expect(h0.dy, lessThan(m0.dy));
      expect(m0.dy, lessThan(e0.dy));
      expect(e0.dy, lessThan(up0.dy));
      expect(up0.dx, lessThan(down0.dx));
      expect(down0.dx, lessThan(rem0.dx));
      expect(rem0.dy, lessThan(add.dy));
    },
  );

  testWidgets('reordering preserves keyboard focus on the moved button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHost(
        entries: const <FallbackEntry>[
          FallbackEntry(harness: NodeTypeId.codex),
          FallbackEntry(harness: NodeTypeId.geminiCli),
          FallbackEntry(harness: NodeTypeId.antigravity),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.byKey(const Key('config_fallback_0_down'));
    final focusNode = Focus.of(
      tester.element(
        find
            .descendant(of: buttonFinder, matching: find.byType(HiveIcon))
            .first,
      ),
    )..requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final primary = FocusManager.instance.primaryFocus;
    expect(primary, same(focusNode));
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('empty state renders compact HiveEmptyState', (tester) async {
    await tester.pumpWidget(_buildHost(entries: const <FallbackEntry>[]));
    await tester.pumpAndSettle();

    final emptyState = tester.widget<HiveEmptyState>(
      find.byType(HiveEmptyState),
    );
    expect(emptyState.compact, isTrue);
  });

  testWidgets(
    'populated list at text scale 2.0 has no overflow and meets guidelines',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildHost(
          width: 360,
          textScale: 2,
          entries: const <FallbackEntry>[
            FallbackEntry(
              harness: NodeTypeId.codex,
              model:
                  'gpt-5-turbo-preview-very-long-model-name-that-must-not-'
                  'overflow',
              effort: 'high',
            ),
          ],
          statuses: const <String, HarnessStatus>{
            NodeTypeId.codex: HarnessStatus.authError,
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );

  testWidgets(
    'Tab traverses focus order harness -> model -> effort -> up -> down -> '
    'remove -> Add',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          entries: const <FallbackEntry>[
            FallbackEntry(harness: NodeTypeId.claudeCode),
            FallbackEntry(harness: NodeTypeId.codex, effort: 'high'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      bool focusIsInside(Key key) {
        final primary = FocusManager.instance.primaryFocus;
        final ctx = primary?.context;
        if (ctx == null) return false;
        return find
            .ancestor(
              of: find.byElementPredicate((e) => e == ctx),
              matching: find.byKey(key),
            )
            .evaluate()
            .isNotEmpty;
      }

      // Focus row 1's harness select and Tab through row 1 -> Add.
      final harnessFinder = find.byKey(const Key('config_fallback_1_harness'));
      Focus.of(
        tester.element(
          find.descendant(of: harnessFinder, matching: find.byType(Text)).first,
        ),
      ).requestFocus();
      await tester.pumpAndSettle();
      expect(focusIsInside(const Key('config_fallback_1_harness')), isTrue);

      final expectedKeys = <Key>[
        const Key('config_fallback_1_model'),
        const Key('config_fallback_1_effort'),
        const Key('config_fallback_1_up'),
        // Row 1 is last, so down is disabled and skipped; remove is next.
        const Key('config_fallback_1_remove'),
        const Key('config_fallback_add'),
      ];
      for (final key in expectedKeys) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(focusIsInside(key), isTrue, reason: 'Expected focus on $key');
      }
    },
  );

  testWidgets(
    'moving row 2 up to index 0 with keyboard leaves focus on down button',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          entries: const <FallbackEntry>[
            FallbackEntry(harness: NodeTypeId.codex),
            FallbackEntry(harness: NodeTypeId.geminiCli),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final upButton = find.byKey(const Key('config_fallback_1_up'));
      Focus.of(
        tester.element(
          find.descendant(of: upButton, matching: find.byType(HiveIcon)).first,
        ),
      ).requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final downButton = find.byKey(const Key('config_fallback_1_down'));
      final downFocus = Focus.of(
        tester.element(
          find
              .descendant(of: downButton, matching: find.byType(HiveIcon))
              .first,
        ),
      );
      expect(downFocus.hasFocus, isTrue);
    },
  );
}
