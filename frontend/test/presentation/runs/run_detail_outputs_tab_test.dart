import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/run_detail_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../workspace/fake_workspace_repository.dart';
import 'fake_run_repository.dart';

void main() {
  testWidgets('Outputs tab shows the chat outputs panel', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final runs = FakeRunRepository(
      checkpoints: <Checkpoint>[
        Checkpoint(
          id: 'cp-1',
          runId: 'run-1',
          sequence: 1,
          completedNodeId: 'node-build',
          pendingNodeIds: const <String>[],
          attemptsByEdge: const <String, int>{},
          circuitBreakerCount: 0,
          nodeOutputs: const <String, JsonMap>{
            'node-build': <String, Object?>{
              'data': <String, Object?>{'summary': 'Build finished cleanly'},
            },
          },
          createdAt: DateTime.utc(2026, 11, 21, 4, 31),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(runs),
          workspaceRepositoryProvider.overrideWithValue(
            FakeWorkspaceRepository(),
          ),
        ],
        child: MaterialApp(
          theme: HiveTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: RunDetailPage(runId: 'run-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('run_chat_outputs_panel')), findsNothing);

    await tester.tap(find.text('Summaries'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('run_chat_outputs_panel')), findsOneWidget);
    expect(find.byKey(const Key('run_chat_output_cp-1')), findsOneWidget);
    expect(find.text('Build step'), findsWidgets);
    expect(find.text('Build finished cleanly'), findsOneWidget);
  });
}
