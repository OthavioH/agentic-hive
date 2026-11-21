import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/snapshots_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../runs/fake_run_repository.dart';
import 'fake_workspace_repository.dart';

void main() {
  late FakeWorkspaceRepository repository;
  late FakeRunRepository runRepository;
  late ProviderContainer container;
  final provider = snapshotsControllerProvider('run-1', '/work');

  setUp(() {
    repository = FakeWorkspaceRepository(snapshots: <Snapshot>[makeSnapshot()]);
    runRepository = FakeRunRepository();
    container = ProviderContainer.test(
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(repository),
        runRepositoryProvider.overrideWithValue(runRepository),
      ],
    )..listen(provider, (_, _) {});
  });

  test('loads snapshots and checks capabilities for the workspace', () async {
    final state = await container.read(provider.future);
    expect(state.snapshots.single.id, 'snap-1');
    expect(state.capabilities.valueOrNull?.gitAvailable, isTrue);
    expect(repository.capabilityPaths, <String?>['/work']);
  });

  test('surfaces a snapshot list failure as an error state', () async {
    repository.listFailure = const NetworkFailure('down');
    final failing = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(repository),
        runRepositoryProvider.overrideWithValue(runRepository),
      ],
    )..listen(provider, (_, _) {});
    await expectLater(failing.read(provider.future), throwsA(isA<Failure>()));
    expect(failing.read(provider).hasError, isTrue);
  });

  test('toggleExpanded loads the diff once and collapses again', () async {
    await container.read(provider.future);
    final notifier = container.read(provider.notifier);

    await notifier.toggleExpanded('snap-1');
    var state = container.read(provider).requireValue;
    expect(state.expandedSnapshotIds, <String>{'snap-1'});
    expect((state.diffs['snap-1']! as SnapshotDiffLoaded).files, hasLength(3));

    await notifier.toggleExpanded('snap-1');
    state = container.read(provider).requireValue;
    expect(state.expandedSnapshotIds, isEmpty);

    await notifier.toggleExpanded('snap-1');
    expect(repository.diffCalls, <String>['snap-1']);
  });

  test('toggleExpanded records a diff failure', () async {
    repository.diffResult = const FailureResult<SnapshotDiff>(
      NotFoundFailure('gone'),
    );
    await container.read(provider.future);
    await container.read(provider.notifier).toggleExpanded('snap-1');
    final state = container.read(provider).requireValue;
    expect(state.diffs['snap-1'], isA<SnapshotDiffFailed>());
  });

  test('restore succeeds, reloads snapshots and refreshes the run', () async {
    await container.read(provider.future);
    await container.read(runDetailControllerProvider('run-1').future);
    final callsBefore = runRepository.getRunCalls;
    repository.snapshots = <Snapshot>[
      makeSnapshot(),
      makeSnapshot(id: 'snap-safety', kind: SnapshotKind.safetyPreRestore),
    ];

    final ok = await container.read(provider.notifier).restore('snap-1');

    expect(ok, isTrue);
    expect(repository.restoreCalls, <String>['snap-1']);
    final state = container.read(provider).requireValue;
    expect(state.snapshots, hasLength(2));
    expect(state.restoringSnapshotId, isNull);
    expect(state.restoreFailure, isNull);
    expect(runRepository.getRunCalls, greaterThan(callsBefore));
  });

  test('restore failure is kept in state and can be dismissed', () async {
    repository.restoreResult = const FailureResult<RestoreSnapshotResponse>(
      BackendFailure('conflict', statusCode: 409),
    );
    await container.read(provider.future);
    final notifier = container.read(provider.notifier);

    final ok = await notifier.restore('snap-1');

    expect(ok, isFalse);
    var state = container.read(provider).requireValue;
    expect(state.restoreFailure, isA<BackendFailure>());
    expect(state.restoringSnapshotId, isNull);

    notifier.dismissRestoreFailure();
    state = container.read(provider).requireValue;
    expect(state.restoreFailure, isNull);
  });
}
