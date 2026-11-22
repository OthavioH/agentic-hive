import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/side_rail_tree_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_workspace_repository.dart';

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  String? savedId;

  @override
  Future<String?> load() async => savedId;

  @override
  Future<void> save(String? workspaceId) async {
    savedId = workspaceId;
  }
}

final class _FakeRunsRepo implements RunRepository {
  List<RunSummary> runs = <RunSummary>[];
  Failure? listFailure;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async {
    final failure = listFailure;
    if (failure != null) return FailureResult<RunsListResponse>(failure);
    return Success<RunsListResponse>(
      RunsListResponse(items: runs, total: runs.length),
    );
  }

  @override
  Future<Result<Run>> cancelRun(String id) => throw UnimplementedError();

  @override
  Future<Result<void>> deleteRun(String id) => throw UnimplementedError();

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> getRun(String id) => throw UnimplementedError();

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> resumeRun(String id) => throw UnimplementedError();

  @override
  Future<Result<Run>> startRun(StartRunRequest request) =>
      throw UnimplementedError();
}

final class _FakePauseRepo implements PauseRepository {
  List<Pause> pauses = <Pause>[];

  @override
  Future<Result<List<Pause>>> listPendingPauses() async =>
      Success<List<Pause>>(pauses);

  @override
  Future<Result<Pause>> answerPause(String id, AnswerPauseRequest request) =>
      throw UnimplementedError();

  @override
  Stream<PauseEvent> watchPauseEvents() => const Stream<PauseEvent>.empty();

  @override
  Stream<int> watchPendingPausesCount() => const Stream<int>.empty();
}

RunSummary _makeRun({
  required String id,
  required String workspaceId,
  required DateTime startedAt,
  String workflowName = 'Build',
  RunStatus status = RunStatus.running,
  DateTime? finishedAt,
  String? worktreePath,
  WorkspaceIsolationMode isolationMode = WorkspaceIsolationMode.direct,
}) => RunSummary(
  id: id,
  workflowName: workflowName,
  status: status,
  startedAt: startedAt,
  finishedAt: finishedAt,
  checkpointCount: 1,
  workspaceId: workspaceId,
  worktreePath: worktreePath,
  isolationMode: isolationMode,
);

void main() {
  final fixedNow = DateTime.utc(2026, 11, 22, 12);

  late FakeWorkspaceRepository workspaceRepo;
  late _FakeSelectionStore selectionStore;
  late _FakeRunsRepo runsRepo;
  late _FakePauseRepo pauseRepo;

  setUp(() {
    workspaceRepo = FakeWorkspaceRepository();
    selectionStore = _FakeSelectionStore();
    runsRepo = _FakeRunsRepo();
    pauseRepo = _FakePauseRepo();
  });

  ProviderContainer createContainer() {
    return ProviderContainer.test(
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
        workspaceSelectionStoreProvider.overrideWithValue(selectionStore),
        runRepositoryProvider.overrideWithValue(runsRepo),
        pauseRepositoryProvider.overrideWithValue(pauseRepo),
        sideRailTreeClockProvider.overrideWithValue(() => fixedNow),
      ],
    );
  }

  test('builds workspace -> worktrees (primary first) -> '
      'active & 24h runs with pause highlight', () async {
    final wsGit = makeWorkspace(
      id: 'ws-git',
      name: 'Hive App',
      rootPath: '/repos/hive',
      activeRunCount: 2,
    );
    final wsNonGit = makeWorkspace(
      id: 'ws-docs',
      name: 'Notes',
      rootPath: '/docs/notes',
      isGit: false,
    );
    workspaceRepo.workspaces = <Workspace>[wsGit, wsNonGit];
    workspaceRepo.worktreesByWorkspaceId['ws-git'] = <Worktree>[
      makeWorktree(path: '/repos/hive'),
      makeWorktree(
        id: 'feat-1',
        name: 'feat-1',
        path: '/data/worktrees/ws-git/feat-1',
        isPrimary: false,
        branch: 'feature/tree',
        hasUncommittedChanges: true,
      ),
    ];
    // Non-git workspace returns empty list from backend.
    workspaceRepo.worktreesByWorkspaceId['ws-docs'] = <Worktree>[];

    runsRepo.runs = <RunSummary>[
      _makeRun(
        id: 'run-active-primary',
        workspaceId: 'ws-git',
        workflowName: 'Deploy',
        startedAt: DateTime.utc(2026, 11, 22, 11, 55),
        worktreePath: '/repos/hive',
      ),
      _makeRun(
        id: 'run-paused-feat',
        workspaceId: 'ws-git',
        workflowName: 'Review',
        status: RunStatus.paused,
        startedAt: DateTime.utc(2026, 11, 22, 11, 50),
        worktreePath: '/data/worktrees/ws-git/feat-1',
        isolationMode: WorkspaceIsolationMode.worktree,
      ),
      _makeRun(
        id: 'run-recent',
        workspaceId: 'ws-git',
        workflowName: 'Test',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026, 11, 22, 10),
        finishedAt: DateTime.utc(2026, 11, 22, 11),
        worktreePath: '/repos/hive',
      ),
      _makeRun(
        id: 'run-old',
        workspaceId: 'ws-git',
        workflowName: 'Old Run',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026, 11, 21, 6),
        finishedAt: DateTime.utc(2026, 11, 21, 11),
        worktreePath: '/repos/hive',
      ),
      _makeRun(
        id: 'run-docs',
        workspaceId: 'ws-docs',
        workflowName: 'Summarize',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026, 11, 22, 11, 30),
        finishedAt: DateTime.utc(2026, 11, 22, 11, 40),
      ),
    ];

    pauseRepo.pauses = <Pause>[
      Pause(
        id: 'pause-1',
        runId: 'run-paused-feat',
        nodeId: 'node-approve',
        kind: PauseKind.humanApproval,
        workflowName: 'Review',
        nodeLabel: 'Approve',
        status: PauseStatus.pending,
        createdAt: DateTime.utc(2026, 11, 22, 11, 58),
      ),
    ];

    final container = createContainer();
    final tree = await container.read(sideRailTreeControllerProvider.future);

    expect(tree.workspaces, hasLength(2));
    expect(tree.currentWorkspaceId, 'ws-git');
    expect(tree.pendingPauseRunIds, <String>{'run-paused-feat'});

    final gitNode = tree.workspaces[0];
    expect(gitNode.pendingPauseCount, 1);
    expect(gitNode.worktrees, hasLength(2));
    expect(gitNode.worktrees[0].worktree.isPrimary, isTrue);
    expect(gitNode.worktrees[0].activeRuns.map((r) => r.id), <String>[
      'run-active-primary',
    ]);
    expect(gitNode.worktrees[0].recentRuns.map((r) => r.id), <String>[
      'run-recent',
    ]); // run-old (>24h) is excluded
    expect(gitNode.worktrees[1].activeRuns.map((r) => r.id), <String>[
      'run-paused-feat',
    ]);

    // Non-git workspace synthesizes a primary checkout node so its runs show.
    final docsNode = tree.workspaces[1];
    expect(docsNode.worktrees, hasLength(1));
    expect(docsNode.worktrees[0].worktree.isPrimary, isTrue);
    expect(docsNode.worktrees[0].recentRuns.map((r) => r.id), <String>[
      'run-docs',
    ]);
  });

  test('toggles workspace/worktree collapse, showAll, and selects current workspace', () async {
    final ws1 = makeWorkspace(name: 'One');
    final ws2 = makeWorkspace(id: 'ws-2', name: 'Two');
    workspaceRepo.workspaces = <Workspace>[ws1, ws2];
    workspaceRepo.worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
    workspaceRepo.worktreesByWorkspaceId['ws-2'] = <Worktree>[
      makeWorktree(path: '/tmp/ws-2'),
    ];
    runsRepo.runs = <RunSummary>[
      for (var i = 0; i < 5; i++)
        _makeRun(
          id: 'r-$i',
          workspaceId: 'ws-1',
          status: RunStatus.succeeded,
          startedAt: DateTime.utc(2026, 11, 22, 11 - i),
          finishedAt: DateTime.utc(2026, 11, 22, 11, 50 - i * 10),
        ),
    ];

    final container = createContainer();
    await container.read(sideRailTreeControllerProvider.future);
    final notifier = container.read(sideRailTreeControllerProvider.notifier)
      ..toggleWorkspaceExpanded('ws-1');
    var state = container.read(sideRailTreeControllerProvider).requireValue;
    expect(state.workspaces[0].expanded, isFalse);

    notifier.toggleWorktreeExpanded('ws-1', 'primary');
    state = container.read(sideRailTreeControllerProvider).requireValue;
    expect(state.workspaces[0].worktrees[0].expanded, isFalse);

    notifier.toggleShowAllRecent('ws-1', 'primary');
    state = container.read(sideRailTreeControllerProvider).requireValue;
    expect(state.workspaces[0].worktrees[0].showAllRecent, isTrue);

    await notifier.selectWorkspace('ws-2');
    state = await container.read(sideRailTreeControllerProvider.future);
    expect(state.currentWorkspaceId, 'ws-2');
    expect(selectionStore.savedId, 'ws-2');
  });
}
