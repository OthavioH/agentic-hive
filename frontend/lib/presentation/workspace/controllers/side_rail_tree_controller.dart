import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_tree_changes_source.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'side_rail_tree_controller.g.dart';

/// Clock provider returning the current UTC timestamp for 24h run filtering.
@riverpod
DateTime Function() sideRailTreeClock(Ref ref) =>
    () => DateTime.now().toUtc();

const int _liveReloadDebounceMs = 250;
const int _elapsedTickSeconds = 1;

/// Quiet period that groups a burst of live change events into one reload.
@riverpod
Duration sideRailTreeDebounce(Ref ref) =>
    const Duration(milliseconds: _liveReloadDebounceMs);

/// Current UTC time, emitted again every second so elapsed times in the tree
/// keep counting while runs are active.
@riverpod
Stream<DateTime> sideRailTreeNow(Ref ref) async* {
  final clock = ref.watch(sideRailTreeClockProvider);
  yield clock();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: _elapsedTickSeconds),
    (_) => clock(),
  );
}

/// One worktree branch (or primary checkout) inside a [SideRailWorkspaceNode].
@immutable
final class SideRailWorktreeNode {
  /// Creates a [SideRailWorktreeNode].
  const new({
    required this.worktree,
    required this.activeRuns,
    required this.recentRuns,
    this.expanded = true,
    this.showAllActive = false,
    this.showAllRecent = false,
    this.isFallback = false,
  });

  /// Underlying worktree metadata.
  final Worktree worktree;

  /// Active runs (`running`, `paused`, `cancelling`) in this worktree.
  final List<RunSummary> activeRuns;

  /// Runs in this worktree finished within the last 24 hours.
  final List<RunSummary> recentRuns;

  /// Whether this worktree branch is expanded in the tree.
  final bool expanded;

  /// Whether all [activeRuns] are shown instead of capping at 3.
  final bool showAllActive;

  /// Whether all [recentRuns] are shown instead of capping at 3.
  final bool showAllRecent;

  /// Whether this is the synthetic fallback group for runs whose worktree no
  /// longer exists on disk.
  final bool isFallback;

  /// Returns a copy with updated fields.
  SideRailWorktreeNode copyWith({
    Worktree? worktree,
    List<RunSummary>? activeRuns,
    List<RunSummary>? recentRuns,
    bool? expanded,
    bool? showAllActive,
    bool? showAllRecent,
    bool? isFallback,
  }) => SideRailWorktreeNode(
    worktree: worktree ?? this.worktree,
    activeRuns: activeRuns ?? this.activeRuns,
    recentRuns: recentRuns ?? this.recentRuns,
    expanded: expanded ?? this.expanded,
    showAllActive: showAllActive ?? this.showAllActive,
    showAllRecent: showAllRecent ?? this.showAllRecent,
    isFallback: isFallback ?? this.isFallback,
  );
}

/// One workspace node inside [SideRailTreeState].
@immutable
final class SideRailWorkspaceNode {
  /// Creates a [SideRailWorkspaceNode].
  const new({
    required this.workspace,
    required this.worktrees,
    required this.pendingPauseCount,
    this.expanded = true,
  });

  /// Registered workspace metadata.
  final Workspace workspace;

  /// Worktrees belonging to [workspace], primary checkout first.
  final List<SideRailWorktreeNode> worktrees;

  /// Number of pending pauses belonging to runs in [workspace].
  final int pendingPauseCount;

  /// Whether this workspace node is expanded in the tree.
  final bool expanded;

  /// Total active runs in [workspace].
  int get activeRunCount {
    var count = 0;
    for (final wt in worktrees) {
      count += wt.activeRuns.length;
    }
    return count > workspace.activeRunCount ? count : workspace.activeRunCount;
  }

  /// Returns a copy with updated fields.
  SideRailWorkspaceNode copyWith({
    Workspace? workspace,
    List<SideRailWorktreeNode>? worktrees,
    int? pendingPauseCount,
    bool? expanded,
  }) => SideRailWorkspaceNode(
    workspace: workspace ?? this.workspace,
    worktrees: worktrees ?? this.worktrees,
    pendingPauseCount: pendingPauseCount ?? this.pendingPauseCount,
    expanded: expanded ?? this.expanded,
  );
}

/// Immutable state for the side rail workspace/worktree/run tree.
@immutable
final class SideRailTreeState {
  /// Creates a [SideRailTreeState].
  const new({
    required this.workspaces,
    required this.currentWorkspaceId,
    required this.pendingPauseRunIds,
    this.isGlobalSelected = false,
    this.isRefreshing = false,
    this.refreshFailure,
  });

  /// Workspace nodes in display order.
  final List<SideRailWorkspaceNode> workspaces;

  /// Currently selected workspace ID, or null when none is selected.
  final String? currentWorkspaceId;

  /// Set of run IDs that currently have at least one pending pause.
  final Set<String> pendingPauseRunIds;

  /// Whether the fixed Global entry is selected.
  final bool isGlobalSelected;

  /// Whether a background refresh is currently running.
  final bool isRefreshing;

  /// Transient failure from the last [SideRailTreeController.refresh] call.
  final Failure? refreshFailure;

  /// Returns a copy with updated fields.
  SideRailTreeState copyWith({
    List<SideRailWorkspaceNode>? workspaces,
    String? Function()? currentWorkspaceId,
    Set<String>? pendingPauseRunIds,
    bool? isGlobalSelected,
    bool? isRefreshing,
    Failure? Function()? refreshFailure,
  }) => SideRailTreeState(
    workspaces: workspaces ?? this.workspaces,
    currentWorkspaceId: currentWorkspaceId != null
        ? currentWorkspaceId()
        : this.currentWorkspaceId,
    pendingPauseRunIds: pendingPauseRunIds ?? this.pendingPauseRunIds,
    isGlobalSelected: isGlobalSelected ?? this.isGlobalSelected,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    refreshFailure: refreshFailure != null
        ? refreshFailure()
        : this.refreshFailure,
  );
}

/// Manages the side rail tree: workspaces, worktrees, and active/recent runs.
@riverpod
class SideRailTreeController extends _$SideRailTreeController {
  /// Maximum runs displayed per group (active / last 24h) before "See all".
  static const int maxRunsPerGroup = 3;

  /// Window in hours for finished runs shown in the tree.
  static const int recentWindowHours = 24;

  /// Synthetic worktree ID for the fallback group holding runs whose worktree
  /// no longer exists.
  static const String missingWorktreesGroupId = '__missing_worktrees__';

  static const int _runsFetchLimit = 200;

  final Map<String, bool> _workspaceExpanded = <String, bool>{};
  final Map<String, bool> _worktreeExpanded = <String, bool>{};
  final Map<String, bool> _showAllActive = <String, bool>{};
  final Map<String, bool> _showAllRecent = <String, bool>{};

  Timer? _debounceTimer;
  bool _registryChanged = false;
  bool _reloading = false;
  bool _reloadAgain = false;

  @override
  Future<SideRailTreeState> build() async {
    _listenForChanges();
    final registryState = await ref.watch(
      workspaceRegistryControllerProvider.future,
    );
    return await _loadTree(registryState);
  }

  /// Reloads workspaces, worktrees, runs, and pending pauses.
  Future<void> refresh() async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData<SideRailTreeState>(
        current.copyWith(isRefreshing: true, refreshFailure: () => null),
      );
    }
    try {
      await ref.read(workspaceRegistryControllerProvider.notifier).refresh();
      if (!ref.mounted) return;
      final registryState = await ref.read(
        workspaceRegistryControllerProvider.future,
      );
      if (!ref.mounted) return;
      final loaded = await _loadTree(registryState);
      if (!ref.mounted) return;
      state = AsyncData<SideRailTreeState>(loaded);
    } on Failure catch (failure, stackTrace) {
      if (!ref.mounted) return;
      if (current != null) {
        state = AsyncData<SideRailTreeState>(
          current.copyWith(isRefreshing: false, refreshFailure: () => failure),
        );
      } else {
        state = AsyncError<SideRailTreeState>(failure, stackTrace);
      }
    }
  }

  void _listenForChanges() {
    final subscription = ref
        .read(watchWorkspaceTreeChangesProvider)()
        .listen(_onChange);
    ref.onDispose(() {
      unawaited(subscription.cancel());
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _reloadAgain = false;
    });
  }

  void _onChange(WorkspaceTreeChange change) {
    if (change == WorkspaceTreeChange.workspace ||
        change == WorkspaceTreeChange.resync) {
      _registryChanged = true;
    }
    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(
      ref.read(sideRailTreeDebounceProvider),
      () => unawaited(_reloadLive()),
    );
  }

  /// Reloads the tree after a live change, one reload at a time. A change that
  /// arrives during a reload schedules exactly one more.
  Future<void> _reloadLive() async {
    if (!ref.mounted) return;
    if (_reloading) {
      _reloadAgain = true;
      return;
    }
    _reloading = true;
    try {
      do {
        _reloadAgain = false;
        await _reloadOnce();
      } while (_reloadAgain && ref.mounted);
    } finally {
      _reloading = false;
    }
  }

  Future<void> _reloadOnce() async {
    final current = state.value;
    if (current == null) return;
    if (_registryChanged) {
      // The registry feeds other pages too; refreshing it rebuilds this tree.
      _registryChanged = false;
      await ref.read(workspaceRegistryControllerProvider.notifier).refresh();
      return;
    }
    try {
      final workspacesResult = await ref.read(listWorkspacesProvider)();
      if (!ref.mounted) return;
      final workspaces = switch (workspacesResult) {
        Success<List<Workspace>>(:final value) => value,
        FailureResult<List<Workspace>>(:final failure) =>
          Error.throwWithStackTrace(failure, StackTrace.current),
      };
      final registry = ref.read(workspaceRegistryControllerProvider).value;
      final loaded = await _loadTree(
        WorkspaceRegistryState(
          workspaces: workspaces,
          currentWorkspaceId: current.isGlobalSelected
              ? null
              : (registry?.currentWorkspaceId ?? current.currentWorkspaceId),
          isGlobalSelected:
              registry?.isGlobalSelected ?? current.isGlobalSelected,
        ),
      );
      if (!ref.mounted) return;
      state = AsyncData<SideRailTreeState>(loaded);
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = AsyncData<SideRailTreeState>(
        current.copyWith(isRefreshing: false, refreshFailure: () => failure),
      );
    }
  }

  /// Marks [workspaceId] as the current workspace.
  Future<void> selectWorkspace(String workspaceId) => ref
      .read(workspaceRegistryControllerProvider.notifier)
      .selectWorkspace(workspaceId);

  /// Selects the fixed Global entry so pages manage only global items.
  void selectGlobal() =>
      ref.read(workspaceRegistryControllerProvider.notifier).selectGlobal();

  /// Removes non-primary worktree [worktreeId] of [workspaceId] and refreshes
  /// the tree on success.
  Future<Result<RemoveWorktreeResponse>> removeWorktree(
    String workspaceId,
    String worktreeId, {
    bool force = false,
  }) async {
    final result = await ref.read(removeWorktreeProvider)(
      workspaceId,
      worktreeId,
      force: force,
    );
    if (!ref.mounted) return result;
    if (result is Success<RemoveWorktreeResponse>) {
      await refresh();
    }
    return result;
  }

  /// Toggles expand/collapse for workspace [workspaceId].
  void toggleWorkspaceExpanded(String workspaceId) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = !(_workspaceExpanded[workspaceId] ?? true);
    _workspaceExpanded[workspaceId] = next;
    state = AsyncData<SideRailTreeState>(
      current.copyWith(
        workspaces: <SideRailWorkspaceNode>[
          for (final ws in current.workspaces)
            if (ws.workspace.id == workspaceId)
              ws.copyWith(expanded: next)
            else
              ws,
        ],
      ),
    );
  }

  /// Toggles expand/collapse for [worktreeId] inside [workspaceId].
  void toggleWorktreeExpanded(String workspaceId, String worktreeId) {
    final current = state.asData?.value;
    if (current == null) return;
    final key = _worktreeKey(workspaceId, worktreeId);
    final next = !(_worktreeExpanded[key] ?? true);
    _worktreeExpanded[key] = next;
    _updateWorktree(current, workspaceId, worktreeId, (wt) {
      return wt.copyWith(expanded: next);
    });
  }

  /// Toggles showing all active runs for [worktreeId] inside [workspaceId].
  void toggleShowAllActive(String workspaceId, String worktreeId) {
    final current = state.asData?.value;
    if (current == null) return;
    final key = _worktreeKey(workspaceId, worktreeId);
    final next = !(_showAllActive[key] ?? false);
    _showAllActive[key] = next;
    _updateWorktree(current, workspaceId, worktreeId, (wt) {
      return wt.copyWith(showAllActive: next);
    });
  }

  /// Toggles showing all recent runs for [worktreeId] inside [workspaceId].
  void toggleShowAllRecent(String workspaceId, String worktreeId) {
    final current = state.asData?.value;
    if (current == null) return;
    final key = _worktreeKey(workspaceId, worktreeId);
    final next = !(_showAllRecent[key] ?? false);
    _showAllRecent[key] = next;
    _updateWorktree(current, workspaceId, worktreeId, (wt) {
      return wt.copyWith(showAllRecent: next);
    });
  }

  void _updateWorktree(
    SideRailTreeState current,
    String workspaceId,
    String worktreeId,
    SideRailWorktreeNode Function(SideRailWorktreeNode node) transform,
  ) {
    state = AsyncData<SideRailTreeState>(
      current.copyWith(
        workspaces: <SideRailWorkspaceNode>[
          for (final ws in current.workspaces)
            if (ws.workspace.id == workspaceId)
              ws.copyWith(
                worktrees: <SideRailWorktreeNode>[
                  for (final wt in ws.worktrees)
                    if (wt.worktree.id == worktreeId) transform(wt) else wt,
                ],
              )
            else
              ws,
        ],
      ),
    );
  }

  Future<SideRailTreeState> _loadTree(
    WorkspaceRegistryState registryState,
  ) async {
    final workspaces = registryState.workspaces;
    final listWorktrees = ref.read(listWorktreesProvider);
    final listPauses = ref.read(listPendingPausesUseCaseProvider);
    final now = ref.read(sideRailTreeClockProvider)();

    final worktreeFutures = <Future<Result<List<Worktree>>>>[
      for (final ws in workspaces) listWorktrees(ws.id),
    ];
    final runsFutures = <Future<Result<List<RunSummary>>>>[
      for (final ws in workspaces) _fetchTreeRuns(ws.id, now),
    ];
    final (worktreeResults, runsResults, pausesResult) = await (
      Future.wait<Result<List<Worktree>>>(worktreeFutures),
      Future.wait<Result<List<RunSummary>>>(runsFutures),
      listPauses(),
    ).wait;

    final runsByWorkspace = <List<RunSummary>>[
      for (final result in runsResults)
        switch (result) {
          Success<List<RunSummary>>(:final value) => value,
          FailureResult<List<RunSummary>>(:final failure) =>
            Error.throwWithStackTrace(failure, StackTrace.current),
        },
    ];

    final pendingPauseRunIds = <String>{
      if (pausesResult case Success<List<Pause>>(:final value))
        for (final pause in value)
          if (pause.status == PauseStatus.pending) pause.runId,
    };

    final nodes = <SideRailWorkspaceNode>[];
    for (var i = 0; i < workspaces.length; i++) {
      final ws = workspaces[i];
      final rawWorktrees = switch (worktreeResults[i]) {
        Success<List<Worktree>>(:final value) => value,
        FailureResult<List<Worktree>>() => const <Worktree>[],
      };

      final effectiveWorktrees = rawWorktrees.isNotEmpty
          ? _orderPrimaryFirst(rawWorktrees)
          : <Worktree>[
              Worktree(
                id: primaryWorktreeId,
                name: primaryWorktreeId,
                path: ws.rootPath,
                isPrimary: true,
                hasUncommittedChanges: false,
              ),
            ];

      final wsRuns = runsByWorkspace[i];
      var wsPendingPauseCount = 0;
      for (final run in wsRuns) {
        if (pendingPauseRunIds.contains(run.id)) {
          wsPendingPauseCount++;
        }
      }

      final worktreeNodes = <SideRailWorktreeNode>[
        for (final wt in effectiveWorktrees)
          _buildWorktreeNode(ws.id, wt, wsRuns, now),
      ];
      final orphanRuns = wsRuns
          .where(
            (run) => !effectiveWorktrees.any((wt) => _matchesWorktree(run, wt)),
          )
          .toList();
      if (orphanRuns.isNotEmpty) {
        final fallbackNode = _buildFallbackWorktreeNode(ws.id, orphanRuns, now);
        if (fallbackNode != null) {
          worktreeNodes.add(fallbackNode);
        }
      }

      nodes.add(
        SideRailWorkspaceNode(
          workspace: ws,
          worktrees: worktreeNodes,
          pendingPauseCount: wsPendingPauseCount,
          expanded: _workspaceExpanded[ws.id] ?? true,
        ),
      );
    }

    return SideRailTreeState(
      workspaces: nodes,
      currentWorkspaceId: registryState.currentWorkspaceId,
      pendingPauseRunIds: pendingPauseRunIds,
      isGlobalSelected: registryState.isGlobalSelected,
    );
  }

  Future<Result<List<RunSummary>>> _fetchTreeRuns(
    String workspaceId,
    DateTime now,
  ) async {
    final listRuns = ref.read(listRunsProvider);
    final byId = <String, RunSummary>{};

    // Fetch all active runs per active status so older active runs are never
    // clipped by recent finished runs.
    for (final status in RunStatus.values.where((s) => s.isActive)) {
      var offset = 0;
      while (true) {
        final result = await listRuns(
          status: status,
          workspaceId: workspaceId,
          limit: _runsFetchLimit,
          offset: offset,
        );
        switch (result) {
          case FailureResult<RunsListResponse>(:final failure):
            return FailureResult<List<RunSummary>>(failure);
          case Success<RunsListResponse>(:final value):
            for (final run in value.items) {
              byId[run.id] = run;
            }
            offset += value.items.length;
            if (value.items.isEmpty || offset >= value.total) {
              break;
            }
            continue;
        }
        break;
      }
    }

    // Fetch recent runs (last 24h) via server-filtered paging.
    var offset = 0;
    while (true) {
      final result = await listRuns(
        workspaceId: workspaceId,
        limit: _runsFetchLimit,
        offset: offset,
      );
      switch (result) {
        case FailureResult<RunsListResponse>(:final failure):
          return FailureResult<List<RunSummary>>(failure);
        case Success<RunsListResponse>(:final value):
          var sawRecent = false;
          for (final run in value.items) {
            byId[run.id] = run;
            if (run.status.isActive || _isWithinRecentWindow(run, now)) {
              sawRecent = true;
            }
          }
          offset += value.items.length;
          if (value.items.isEmpty || offset >= value.total || !sawRecent) {
            break;
          }
          continue;
      }
      break;
    }

    return Success<List<RunSummary>>(byId.values.toList());
  }

  SideRailWorktreeNode _buildWorktreeNode(
    String workspaceId,
    Worktree worktree,
    List<RunSummary> workspaceRuns,
    DateTime now,
  ) {
    final matching = workspaceRuns
        .where((run) => _matchesWorktree(run, worktree))
        .toList();
    return _groupRunsIntoWorktreeNode(
      workspaceId: workspaceId,
      worktree: worktree,
      matchingRuns: matching,
      now: now,
    );
  }

  SideRailWorktreeNode? _buildFallbackWorktreeNode(
    String workspaceId,
    List<RunSummary> orphanRuns,
    DateTime now,
  ) {
    final node = _groupRunsIntoWorktreeNode(
      workspaceId: workspaceId,
      worktree: const Worktree(
        id: missingWorktreesGroupId,
        name: '',
        path: '',
        isPrimary: false,
        hasUncommittedChanges: false,
      ),
      matchingRuns: orphanRuns,
      now: now,
      isFallback: true,
    );
    if (node.activeRuns.isEmpty && node.recentRuns.isEmpty) return null;
    return node;
  }

  SideRailWorktreeNode _groupRunsIntoWorktreeNode({
    required String workspaceId,
    required Worktree worktree,
    required List<RunSummary> matchingRuns,
    required DateTime now,
    bool isFallback = false,
  }) {
    final active = <RunSummary>[];
    final recent = <RunSummary>[];
    for (final run in matchingRuns) {
      if (run.status.isActive) {
        active.add(run);
      } else if (_isWithinRecentWindow(run, now)) {
        recent.add(run);
      }
    }

    active.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    recent.sort(
      (a, b) =>
          (b.finishedAt ?? b.startedAt).compareTo(a.finishedAt ?? a.startedAt),
    );

    final key = _worktreeKey(workspaceId, worktree.id);
    return SideRailWorktreeNode(
      worktree: worktree,
      activeRuns: active,
      recentRuns: recent,
      expanded: _worktreeExpanded[key] ?? true,
      showAllActive: _showAllActive[key] ?? false,
      showAllRecent: _showAllRecent[key] ?? false,
      isFallback: isFallback,
    );
  }

  static bool _isWithinRecentWindow(RunSummary run, DateTime now) {
    final referenceTime = run.finishedAt ?? run.startedAt;
    final age = now.difference(referenceTime);
    return !age.isNegative && age.inMinutes <= recentWindowHours * 60;
  }

  static List<Worktree> _orderPrimaryFirst(List<Worktree> worktrees) {
    final primary = <Worktree>[];
    final others = <Worktree>[];
    for (final wt in worktrees) {
      if (wt.isPrimary) {
        primary.add(wt);
      } else {
        others.add(wt);
      }
    }
    return <Worktree>[...primary, ...others];
  }

  static bool _matchesWorktree(RunSummary run, Worktree worktree) {
    final runPath = run.worktreePath;
    if (runPath == null || runPath.isEmpty) {
      return worktree.isPrimary;
    }
    return p.equals(p.normalize(runPath), p.normalize(worktree.path));
  }

  static String _worktreeKey(String workspaceId, String worktreeId) =>
      '$workspaceId::$worktreeId';
}
