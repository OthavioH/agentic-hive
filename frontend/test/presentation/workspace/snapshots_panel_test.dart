import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/snapshots_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../runs/fake_run_repository.dart';
import 'fake_workspace_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeWorkspaceRepository repository, {
  RunStatus status = RunStatus.failed,
}) async {
  tester.view.physicalSize = const Size(900, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(repository),
        runRepositoryProvider.overrideWithValue(FakeRunRepository()),
      ],
      child: MaterialApp(
        theme: HiveTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SnapshotsPanel(
            runId: 'run-1',
            workspacePath: '/work',
            runStatus: status,
            nodeLabels: const <String, String>{'node-build': 'Build step'},
          ),
        ),
      ),
    ),
  );
}

HiveButton _restoreButton(WidgetTester tester, String id) =>
    tester.widget<HiveButton>(find.byKey(Key('snapshot_restore_$id')));

void main() {
  testWidgets('shows a spinner while snapshots load', (tester) async {
    final repository = FakeWorkspaceRepository()..listGate = Completer<void>();
    await _pump(tester, repository);
    await tester.pump();
    expect(find.byType(HiveSpinner), findsOneWidget);
    repository.listGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HiveSpinner), findsNothing);
  });

  testWidgets('shows the empty state when no snapshots exist', (tester) async {
    await _pump(tester, FakeWorkspaceRepository());
    await tester.pumpAndSettle();
    expect(
      find.text('No snapshots were captured for this run yet.'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error state with retry', (tester) async {
    final repository = FakeWorkspaceRepository()
      ..listFailure = const NetworkFailure('down');
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Failed to load snapshots'), findsOneWidget);

    repository
      ..listFailure = null
      ..snapshots = <Snapshot>[makeSnapshot()];
    await tester.tap(find.byKey(const Key('snapshots_retry_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('snapshot_card_snap-1')), findsOneWidget);
  });

  testWidgets('lists snapshots with node, kind badge and +A ~M -D counts', (
    tester,
  ) async {
    final repository = FakeWorkspaceRepository(
      snapshots: <Snapshot>[
        makeSnapshot(),
        makeSnapshot(
          id: 'snap-2',
          nodeId: null,
          kind: SnapshotKind.safetyPreRestore,
          added: 0,
          modified: 0,
          deleted: 0,
        ),
      ],
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Build step'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Before node'), findsOneWidget);
    expect(find.text('Safety'), findsOneWidget);
    final stat = tester.widget<HiveDiffStat>(
      find.byKey(const Key('snapshot_stat_snap-1')),
    );
    expect((stat.added, stat.modified, stat.deleted), (2, 3, 1));
    expect(find.byKey(const Key('snapshots_restore_notice')), findsNothing);
    expect(_restoreButton(tester, 'snap-1').onPressed, isNotNull);
  });

  testWidgets('expands a snapshot to list changed files', (tester) async {
    final repository = FakeWorkspaceRepository(
      snapshots: <Snapshot>[makeSnapshot()],
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('snapshot_files_snap-1')), findsNothing);
    await tester.tap(find.byKey(const Key('snapshot_toggle_snap-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('snapshot_files_snap-1')), findsOneWidget);
    expect(find.text('lib/a.dart'), findsOneWidget);
    expect(find.text('README.md'), findsOneWidget);
    expect(find.text('old.txt'), findsOneWidget);

    await tester.tap(find.byKey(const Key('snapshot_toggle_snap-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('snapshot_files_snap-1')), findsNothing);
  });

  testWidgets('shows an inline message when the diff fails to load', (
    tester,
  ) async {
    final repository = FakeWorkspaceRepository(
      snapshots: <Snapshot>[makeSnapshot()],
    )..diffResult = const FailureResult<SnapshotDiff>(NetworkFailure('down'));
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('snapshot_toggle_snap-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('snapshot_diff_error_snap-1')), findsOneWidget);
  });

  testWidgets('restore opens a HiveDialog and Cancel does not restore', (
    tester,
  ) async {
    final repository = FakeWorkspaceRepository(
      snapshots: <Snapshot>[makeSnapshot()],
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('snapshot_restore_snap-1')));
    await tester.pumpAndSettle();
    expect(find.byType(HiveDialog), findsOneWidget);
    expect(find.text('Restore this snapshot?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('restore_dialog_cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(HiveDialog), findsNothing);
    expect(repository.restoreCalls, isEmpty);
  });

  testWidgets('confirming restore calls the backend and shows success', (
    tester,
  ) async {
    final repository = FakeWorkspaceRepository(
      snapshots: <Snapshot>[makeSnapshot()],
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('snapshot_restore_snap-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore_dialog_confirm')));
    await tester.pumpAndSettle();

    expect(repository.restoreCalls, <String>['snap-1']);
    expect(find.byType(HiveDialog), findsNothing);
    expect(find.byKey(const Key('snapshots_restore_success')), findsOneWidget);
  });

  testWidgets('shows a conflict banner when restore is rejected', (
    tester,
  ) async {
    final repository =
        FakeWorkspaceRepository(snapshots: <Snapshot>[makeSnapshot()])
          ..restoreResult = const FailureResult<RestoreSnapshotResponse>(
            BackendFailure('conflict', statusCode: 409),
          );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('snapshot_restore_snap-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore_dialog_confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('snapshots_restore_failure')), findsOneWidget);
    expect(
      find.text(
        'The run is active. Restore is only possible when it is not running.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('disables restore while the run is running', (tester) async {
    final repository = FakeWorkspaceRepository(
      snapshots: <Snapshot>[makeSnapshot()],
    );
    await _pump(tester, repository, status: RunStatus.running);
    await tester.pumpAndSettle();

    expect(_restoreButton(tester, 'snap-1').onPressed, isNull);
    expect(find.byKey(const Key('snapshots_restore_notice')), findsOneWidget);
    expect(
      find.text('Stop or pause the run before restoring a snapshot.'),
      findsOneWidget,
    );
  });

  testWidgets('disables restore when git is unavailable', (tester) async {
    final repository = FakeWorkspaceRepository(
      snapshots: <Snapshot>[makeSnapshot()],
      capabilities: const Success<WorkspaceCapabilities>(
        WorkspaceCapabilities(
          gitAvailable: false,
          isGitRepo: false,
          hasCommits: false,
        ),
      ),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(_restoreButton(tester, 'snap-1').onPressed, isNull);
    expect(find.textContaining('Restore needs git'), findsOneWidget);
    expect(repository.capabilityPaths, <String?>['/work']);
  });

  testWidgets('disables restore when the capability check fails', (
    tester,
  ) async {
    final repository = FakeWorkspaceRepository(
      snapshots: <Snapshot>[makeSnapshot()],
      capabilities: const FailureResult<WorkspaceCapabilities>(
        NetworkFailure('down'),
      ),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(_restoreButton(tester, 'snap-1').onPressed, isNull);
    expect(
      find.textContaining('Could not check whether restore'),
      findsOneWidget,
    );
  });
}
