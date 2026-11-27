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

Future<void> _pump(
  WidgetTester tester, {
  required FakeRunRepository runs,
  required FakeWorkspaceRepository workspace,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(runs),
        workspaceRepositoryProvider.overrideWithValue(workspace),
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
}

void main() {
  testWidgets('shows worktree path and hive branch for worktree runs', (
    tester,
  ) async {
    await _pump(
      tester,
      runs: FakeRunRepository(
        isolationMode: WorkspaceIsolationMode.worktree,
        worktreePath: '/data/worktrees/run-1',
        worktreeBranch: 'hive/run-1',
      ),
      workspace: FakeWorkspaceRepository(),
    );
    await tester.tap(find.text('Run details'));
    await tester.pumpAndSettle();
    expect(find.text('Worktree'), findsOneWidget);
    expect(find.text('/data/worktrees/run-1'), findsOneWidget);
    expect(find.text('hive/run-1'), findsOneWidget);
  });

  testWidgets('direct runs show no worktree path or branch', (tester) async {
    await _pump(
      tester,
      runs: FakeRunRepository(),
      workspace: FakeWorkspaceRepository(),
    );
    await tester.tap(find.text('Run details'));
    await tester.pumpAndSettle();
    expect(find.text('Direct'), findsOneWidget);
    expect(find.byKey(const Key('run_detail_worktree_path')), findsNothing);
    expect(find.byKey(const Key('run_detail_worktree_branch')), findsNothing);
  });

  testWidgets('toggles between Checkpoints and Snapshots', (tester) async {
    await _pump(
      tester,
      runs: FakeRunRepository(),
      workspace: FakeWorkspaceRepository(snapshots: <Snapshot>[makeSnapshot()]),
    );
    await tester.tap(find.text('Checkpoints'));
    await tester.pumpAndSettle();
    expect(find.text('No checkpoints saved for this run.'), findsOneWidget);

    await tester.ensureVisible(find.text('Snapshots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Snapshots'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('snapshot_card_snap-1')), findsOneWidget);
    // Node ID resolves to the workflow node label.
    expect(
      find.descendant(
        of: find.byKey(const Key('snapshot_card_snap-1')),
        matching: find.text('Build step'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Checkpoints'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('snapshot_card_snap-1')), findsNothing);
  });

  testWidgets('restore is disabled in the Snapshots tab while running', (
    tester,
  ) async {
    await _pump(
      tester,
      runs: FakeRunRepository(status: RunStatus.running),
      workspace: FakeWorkspaceRepository(snapshots: <Snapshot>[makeSnapshot()]),
    );
    await tester.ensureVisible(find.text('Snapshots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Snapshots'));
    await tester.pumpAndSettle();
    final button = tester.widget<HiveButton>(
      find.byKey(const Key('snapshot_restore_snap-1')),
    );
    expect(button.onPressed, isNull);
  });
}
