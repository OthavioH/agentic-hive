import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/fallback_list_editor.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _buildHost({
  required List<FallbackEntry> entries,
  Map<String, HarnessStatus>? statuses,
}) {
  return UncontrolledProviderScope(
    container: ProviderContainer.test(
      overrides: [harnessStatusByTypeIdProvider.overrideWithValue(statuses)],
    ),
    child: MaterialApp(
      theme: HiveTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NodeVisualScope(
        registry: createNodeVisualRegistry(),
        child: Scaffold(
          body: SizedBox(
            width: HiveSpacing.standard.space8 * 6,
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
}
