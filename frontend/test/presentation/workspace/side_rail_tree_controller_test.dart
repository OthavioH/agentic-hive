import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_tree_changes_providers.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_tree_changes_source.dart';
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
  int listCalls = 0;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async {
    listCalls++;
    final failure = listFailure;
    if (failure != null) return FailureResult<RunsListResponse>(failure);
    final filtered = status == null
        ? runs
        : runs.where((r) => r.status == status).toList();
    final start = offset ?? 0;
    final page = limit == null
        ? filtered.skip(start).toList()
        : filtered.skip(start).take(limit).toList();
    return Success<RunsListResponse>(
      RunsListResponse(items: page, total: filtered.length),
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

final class _FakeChangesSource implements WorkspaceTreeChangesSource {
  final StreamController<WorkspaceTreeChange> controller =
      StreamController<WorkspaceTreeChange>.broadcast();

  @override
  Stream<WorkspaceTreeChange> get changes => controller.stream;

  void emit(WorkspaceTreeChange change) => controller.add(change);
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
  late _FakeChangesSource changes;

  setUp(() {
    workspaceRepo = FakeWorkspaceRepository();
    selectionStore = _FakeSelectionStore();
    runsRepo = _FakeRunsRepo();
    pauseRepo = _FakePauseRepo();
    changes = _FakeChangesSource();
    addTearDown(changes.controller.close);
  });

  ProviderContainer createContainer() {
    return ProviderContainer.test(
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
        workspaceSelectionStoreProvider.overrideWithValue(selectionStore),
        runRepositoryProvider.overrideWithValue(runsRepo),
        pauseRepositoryProvider.overrideWithValue(pauseRepo),
        sideRailTreeClockProvider.overrideWithValue(() => fixedNow),
        workspaceTreeChangesSourceProvider.overrideWithValue(changes),
        sideRailTreeDebounceProvider.overrideWithValue(Duration.zero),
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

  group('live updates', () {
    final startedAt = DateTime.utc(2026, 11, 22, 11, 55);

    Future<ProviderContainer> loaded() async {
      final container = createContainer()
        ..listen(sideRailTreeControllerProvider, (_, _) {});
      await container.read(sideRailTreeControllerProvider.future);
      return container;
    }

    SideRailTreeState current(ProviderContainer container) =>
        container.read(sideRailTreeControllerProvider).requireValue;

    test('a run that pauses shows its new status and the pending-pause '
        'highlight without a manual refresh', () async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace(activeRunCount: 1)]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
      runsRepo.runs = <RunSummary>[
        _makeRun(
          id: 'run-1',
          workspaceId: 'ws-1',
          startedAt: startedAt,
          worktreePath: '/tmp/ws-1',
        ),
      ];
      final container = await loaded();
      expect(current(container).pendingPauseRunIds, isEmpty);

      runsRepo.runs = <RunSummary>[
        _makeRun(
          id: 'run-1',
          workspaceId: 'ws-1',
          status: RunStatus.paused,
          startedAt: startedAt,
          worktreePath: '/tmp/ws-1',
        ),
      ];
      pauseRepo.pauses = <Pause>[
        Pause(
          id: 'p-1',
          runId: 'run-1',
          nodeId: 'n',
          kind: PauseKind.humanApproval,
          workflowName: 'Build',
          nodeLabel: 'Approve',
          status: PauseStatus.pending,
          createdAt: startedAt,
        ),
      ];
      changes.emit(WorkspaceTreeChange.pause);
      await pumpEventQueue();

      final tree = current(container);
      expect(tree.pendingPauseRunIds, <String>{'run-1'});
      expect(tree.workspaces.single.pendingPauseCount, 1);
      expect(
        tree.workspaces.single.worktrees.single.activeRuns.single.status,
        RunStatus.paused,
      );
    });

    test('a run that finishes moves from active to recent and the '
        'workspace activity count drops', () async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace(activeRunCount: 1)]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
      runsRepo.runs = <RunSummary>[
        _makeRun(
          id: 'run-1',
          workspaceId: 'ws-1',
          startedAt: startedAt,
          worktreePath: '/tmp/ws-1',
        ),
      ];
      final container = await loaded();
      expect(current(container).workspaces.single.activeRunCount, 1);

      workspaceRepo.workspaces = <Workspace>[makeWorkspace()];
      runsRepo.runs = <RunSummary>[
        _makeRun(
          id: 'run-1',
          workspaceId: 'ws-1',
          status: RunStatus.succeeded,
          startedAt: startedAt,
          finishedAt: DateTime.utc(2026, 11, 22, 11, 58),
          worktreePath: '/tmp/ws-1',
        ),
      ];
      changes.emit(WorkspaceTreeChange.run);
      await pumpEventQueue();

      final node = current(container).workspaces.single;
      expect(node.activeRunCount, 0);
      expect(node.worktrees.single.activeRuns, isEmpty);
      expect(node.worktrees.single.recentRuns.single.id, 'run-1');
    });

    test('a created worktree appears and a removed one disappears', () async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace()]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
      final container = await loaded();
      expect(current(container).workspaces.single.worktrees, hasLength(1));

      workspaceRepo.worktreesByWorkspaceId['ws-1'] = <Worktree>[
        makeWorktree(),
        makeWorktree(
          id: 'feat',
          name: 'feat',
          path: '/data/worktrees/ws-1/feat',
          isPrimary: false,
          branch: 'feat',
        ),
      ];
      changes.emit(WorkspaceTreeChange.worktree);
      await pumpEventQueue();
      expect(
        current(container).workspaces.single.worktrees
            .map((w) => w.worktree.id),
        <String>['primary', 'feat'],
      );

      workspaceRepo.worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
      changes.emit(WorkspaceTreeChange.worktree);
      await pumpEventQueue();
      expect(current(container).workspaces.single.worktrees, hasLength(1));
    });

    test('a registered or renamed workspace shows up live', () async {
      workspaceRepo.workspaces = <Workspace>[makeWorkspace(name: 'One')];
      final container = await loaded();

      workspaceRepo.workspaces = <Workspace>[
        makeWorkspace(name: 'Renamed'),
        makeWorkspace(id: 'ws-2', name: 'Docs', isGit: false),
      ];
      changes.emit(WorkspaceTreeChange.workspace);
      await pumpEventQueue();

      final tree = current(container);
      expect(tree.workspaces.map((w) => w.workspace.name), <String>[
        'Renamed',
        'Docs',
      ]);
      expect(tree.currentWorkspaceId, 'ws-1');
    });

    test('a reconnect resyncs the tree', () async {
      workspaceRepo.workspaces = <Workspace>[makeWorkspace()];
      final container = await loaded();
      runsRepo.runs = <RunSummary>[
        _makeRun(id: 'late', workspaceId: 'ws-1', startedAt: startedAt),
      ];

      changes.emit(WorkspaceTreeChange.resync);
      await pumpEventQueue();

      expect(
        current(container).workspaces.single.worktrees.single.activeRuns,
        hasLength(1),
      );
    });

    test('keeps the expand choices across live updates', () async {
      workspaceRepo.workspaces = <Workspace>[makeWorkspace()];
      final container = await loaded();
      container
          .read(sideRailTreeControllerProvider.notifier)
          .toggleWorkspaceExpanded('ws-1');

      changes.emit(WorkspaceTreeChange.run);
      await pumpEventQueue();

      expect(current(container).workspaces.single.expanded, isFalse);
    });

    test('a burst of events triggers one reload, not one per event', () async {
      workspaceRepo.workspaces = <Workspace>[makeWorkspace()];
      final container = await loaded();
      final before = runsRepo.listCalls;

      changes
        ..emit(WorkspaceTreeChange.run)
        ..emit(WorkspaceTreeChange.run)
        ..emit(WorkspaceTreeChange.pause)
        ..emit(WorkspaceTreeChange.run);
      await pumpEventQueue();

      expect(runsRepo.listCalls - before, before);
      expect(current(container).workspaces, isNotEmpty);
    });

    test('an event during a reload schedules exactly one follow-up '
        'reload', () async {
      workspaceRepo.workspaces = <Workspace>[makeWorkspace()];
      final container = await loaded();
      final before = runsRepo.listCalls;
      final gate = Completer<void>();
      workspaceRepo.listWorkspacesGate = gate;

      changes.emit(WorkspaceTreeChange.run);
      await pumpEventQueue();
      changes
        ..emit(WorkspaceTreeChange.run)
        ..emit(WorkspaceTreeChange.pause);
      await pumpEventQueue();
      workspaceRepo.listWorkspacesGate = null;
      gate.complete();
      await pumpEventQueue();

      expect(runsRepo.listCalls - before, before * 2);
      expect(current(container).workspaces, isNotEmpty);
    });

    test('a failed live reload keeps the tree and reports the failure, then '
        'recovers on the next event', () async {
      workspaceRepo.workspaces = <Workspace>[makeWorkspace()];
      final container = await loaded();

      runsRepo.listFailure = const NetworkFailure('offline');
      changes.emit(WorkspaceTreeChange.run);
      await pumpEventQueue();
      var tree = current(container);
      expect(tree.workspaces, hasLength(1));
      expect(tree.refreshFailure, isA<NetworkFailure>());

      runsRepo.listFailure = null;
      changes.emit(WorkspaceTreeChange.run);
      await pumpEventQueue();
      tree = current(container);
      expect(tree.refreshFailure, isNull);
    });
  });

  group('removeWorktree', () {
    test('calls repository and refreshes the tree on success', () async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace()]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[
          makeWorktree(),
          makeWorktree(
            id: 'feat-a',
            name: 'feat-a',
            path: '/data/worktrees/ws-1/feat-a',
            isPrimary: false,
            branch: 'feat/a',
          ),
        ];
      final container = createContainer();
      final sub = container.listen(sideRailTreeControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final tree = await container.read(sideRailTreeControllerProvider.future);
      expect(tree.workspaces.single.worktrees, hasLength(2));

      final result = await container
          .read(sideRailTreeControllerProvider.notifier)
          .removeWorktree('ws-1', 'feat-a');

      expect(result.isSuccess, isTrue);
      expect(
        workspaceRepo.removeWorktreeCalls,
        <({String workspaceId, String worktreeId, bool force})>[
          (workspaceId: 'ws-1', worktreeId: 'feat-a', force: false),
        ],
      );
      final updated = await container.read(
        sideRailTreeControllerProvider.future,
      );
      expect(updated.workspaces.single.worktrees, hasLength(1));
    });
  });

  group('selectGlobal', () {
    test('selectGlobal sets isGlobalSelected=true and clears '
        'currentWorkspaceId', () async {
      workspaceRepo.workspaces = <Workspace>[makeWorkspace()];
      final container = createContainer();
      final sub = container.listen(sideRailTreeControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final initial = await container.read(
        sideRailTreeControllerProvider.future,
      );
      expect(initial.isGlobalSelected, isFalse);
      expect(initial.currentWorkspaceId, 'ws-1');

      container.read(sideRailTreeControllerProvider.notifier).selectGlobal();
      final after = await container.read(sideRailTreeControllerProvider.future);
      expect(after.isGlobalSelected, isTrue);
      expect(after.currentWorkspaceId, isNull);
    });
  });

  group('older active runs and missing worktrees', () {
    test('loads active runs even beyond 200 newer finished runs', () async {
      workspaceRepo
        ..workspaces = <Workspace>[makeWorkspace()]
        ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];

      // 210 newer finished runs, plus 1 older active run at the end.
      final oldTime = DateTime.utc(2026, 11, 17, 12);
      runsRepo.runs = <RunSummary>[
        for (var i = 0; i < 210; i++)
          _makeRun(
            id: 'done-$i',
            workspaceId: 'ws-1',
            status: RunStatus.succeeded,
            startedAt: DateTime.utc(2026, 11, 10).add(Duration(hours: i)),
            finishedAt: DateTime.utc(2026, 11, 10).add(Duration(hours: i + 1)),
          ),
        _makeRun(id: 'old-active', workspaceId: 'ws-1', startedAt: oldTime),
      ];

      final container = createContainer();
      final tree = await container.read(sideRailTreeControllerProvider.future);
      final primaryNode = tree.workspaces.single.worktrees.single;
      expect(primaryNode.activeRuns.map((r) => r.id), <String>['old-active']);
    });

    test(
      'places runs whose worktree no longer exists in a fallback group',
      () async {
        workspaceRepo
          ..workspaces = <Workspace>[makeWorkspace()]
          ..worktreesByWorkspaceId['ws-1'] = <Worktree>[makeWorktree()];
        runsRepo.runs = <RunSummary>[
          _makeRun(
            id: 'orphan-active',
            workspaceId: 'ws-1',
            startedAt: DateTime.utc(2026, 11, 22, 11, 55),
            worktreePath: '/data/worktrees/ws-1/deleted-wt',
          ),
          _makeRun(
            id: 'orphan-recent',
            workspaceId: 'ws-1',
            status: RunStatus.succeeded,
            startedAt: DateTime.utc(2026, 11, 22, 10),
            finishedAt: DateTime.utc(2026, 11, 22, 11),
            worktreePath: '/data/worktrees/ws-1/deleted-wt-2',
          ),
        ];

        final container = createContainer();
        final tree = await container.read(
          sideRailTreeControllerProvider.future,
        );
        final worktrees = tree.workspaces.single.worktrees;
        expect(worktrees, hasLength(2));
        expect(worktrees[0].isFallback, isFalse);
        expect(worktrees[1].isFallback, isTrue);
        expect(worktrees[1].activeRuns.map((r) => r.id), <String>[
          'orphan-active',
        ]);
        expect(worktrees[1].recentRuns.map((r) => r.id), <String>[
          'orphan-recent',
        ]);
      },
    );
  });
}
