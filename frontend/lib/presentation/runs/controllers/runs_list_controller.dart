import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'runs_list_controller.g.dart';

/// View state for the Runs list page.
@immutable
final class RunsListState {
  /// Creates a [RunsListState].
  const new({
    required this.runs,
    required this.total,
    required this.workflows,
    this.isGlobalSelected = false,
    this.statusFilter,
    this.workflowFilter,
    this.expandedRunIds = const <String>{},
    this.busyRunId,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.actionFailure,
  });

  /// Loaded run summaries matching the active filters.
  final List<RunSummary> runs;

  /// Total number of matching runs reported by the backend.
  final int total;

  /// Available workflows for the workflow filter dropdown.
  final List<WorkflowSummary> workflows;

  /// Whether Global (or no workspace) is selected; runs always belong to a
  /// workspace, so no runs are shown.
  final bool isGlobalSelected;

  /// Active status filter, or `null` for all statuses.
  final RunStatus? statusFilter;

  /// Active workflow ID filter, or `null` for all workflows.
  final String? workflowFilter;

  /// Parent run IDs currently expanded in the runs list (R2).
  final Set<String> expandedRunIds;

  /// ID of the run currently undergoing deletion.
  final String? busyRunId;

  /// Whether a background refresh is in progress while keeping existing data.
  final bool isRefreshing;

  /// Whether the next page of runs is currently being loaded.
  final bool isLoadingMore;

  /// Transient failure from a list action such as delete or load more.
  final Failure? actionFailure;

  /// Whether any status or workflow filter is active.
  bool get hasActiveFilters => statusFilter != null || workflowFilter != null;

  /// Whether more runs are available to fetch from the backend.
  bool get hasMore => runs.length < total;

  /// Runs shown at top level: not children, or children whose parent is not
  /// loaded (R1).
  List<RunSummary> get topLevelRuns {
    final ids = <String>{for (final r in runs) r.id};
    return <RunSummary>[
      for (final r in runs)
        if (r.parentRunId == null || !ids.contains(r.parentRunId)) r,
    ];
  }

  /// Loaded child runs of [parentId], oldest first (R3).
  List<RunSummary> childrenOf(String parentId) {
    final children = <RunSummary>[
      for (final r in runs)
        if (r.parentRunId == parentId) r,
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return children;
  }

  /// Returns a copy with updated fields.
  RunsListState copyWith({
    List<RunSummary>? runs,
    int? total,
    List<WorkflowSummary>? workflows,
    bool? isGlobalSelected,
    RunStatus? Function()? statusFilter,
    String? Function()? workflowFilter,
    Set<String>? expandedRunIds,
    String? Function()? busyRunId,
    bool? isRefreshing,
    bool? isLoadingMore,
    Failure? Function()? actionFailure,
  }) {
    return RunsListState(
      runs: runs ?? this.runs,
      total: total ?? this.total,
      workflows: workflows ?? this.workflows,
      isGlobalSelected: isGlobalSelected ?? this.isGlobalSelected,
      statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
      workflowFilter: workflowFilter != null
          ? workflowFilter()
          : this.workflowFilter,
      expandedRunIds: expandedRunIds ?? this.expandedRunIds,
      busyRunId: busyRunId != null ? busyRunId() : this.busyRunId,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      actionFailure: actionFailure != null
          ? actionFailure()
          : this.actionFailure,
    );
  }
}

/// Manages the runs list, status/workflow filters, pagination, and deletion.
@riverpod
class RunsListController extends _$RunsListController {
  /// Default number of runs fetched per page.
  static const int pageSize = 50;

  int _requestToken = 0;

  ({String? workspaceId, bool isGlobal}) get _workspaceSelection {
    final registry = ref
        .read(workspaceRegistryControllerProvider)
        .asData
        ?.value;
    if (registry == null) return (workspaceId: null, isGlobal: true);
    return (
      workspaceId: registry.currentWorkspaceId,
      isGlobal:
          registry.isGlobalSelected || registry.currentWorkspaceId == null,
    );
  }

  @override
  Future<RunsListState> build() async {
    final selection = await ref.watch(
      workspaceRegistryControllerProvider.selectAsync(
        (s) => (
          workspaceId: s.currentWorkspaceId,
          isGlobal: s.isGlobalSelected || s.currentWorkspaceId == null,
        ),
      ),
    );
    return await _load(
      statusFilter: null,
      workflowFilter: null,
      workspaceId: selection.workspaceId,
      isGlobal: selection.isGlobal,
    );
  }

  /// Reloads runs and workflows preserving the current filters and existing
  /// data while refreshing.
  Future<void> refresh() async {
    final token = ++_requestToken;
    final current = state.asData?.value;
    final statusFilter = current?.statusFilter;
    final workflowFilter = current?.workflowFilter;
    if (current != null) {
      state = AsyncData(
        current.copyWith(isRefreshing: true, actionFailure: () => null),
      );
    } else {
      state = const AsyncLoading<RunsListState>();
    }
    try {
      final selection = _workspaceSelection;
      final loaded = await _load(
        statusFilter: statusFilter,
        workflowFilter: workflowFilter,
        workspaceId: selection.workspaceId,
        isGlobal: selection.isGlobal,
      );
      if (!ref.mounted || token != _requestToken) return;
      state = AsyncData(
        loaded.copyWith(expandedRunIds: current?.expandedRunIds),
      );
    } on Failure catch (failure, stackTrace) {
      if (!ref.mounted || token != _requestToken) return;
      if (current != null) {
        state = AsyncData(
          current.copyWith(isRefreshing: false, actionFailure: () => failure),
        );
      } else {
        state = AsyncError(failure, stackTrace);
      }
    }
  }

  /// Loads the next page of runs when [RunsListState.hasMore] is true.
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.isRefreshing) {
      return;
    }

    final selection = _workspaceSelection;
    if (selection.isGlobal || selection.workspaceId == null) return;

    final token = _requestToken;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, actionFailure: () => null),
    );

    final result = await ref
        .read(listRunsProvider)
        .call(
          workspaceId: selection.workspaceId,
          status: current.statusFilter,
          workflowId: current.workflowFilter,
          limit: pageSize,
          offset: current.runs.length,
        );
    if (!ref.mounted || token != _requestToken) return;

    final latest = state.asData?.value ?? current;
    switch (result) {
      case Success<RunsListResponse>(:final value):
        state = AsyncData(
          latest.copyWith(
            runs: <RunSummary>[...latest.runs, ...value.items],
            total: value.total,
            isLoadingMore: false,
            actionFailure: () => null,
          ),
        );
      case FailureResult<RunsListResponse>(:final failure):
        state = AsyncData(
          latest.copyWith(isLoadingMore: false, actionFailure: () => failure),
        );
    }
  }

  /// Sets [status] as the active status filter (`null` for all) and reloads.
  Future<void> setStatusFilter(RunStatus? status) async {
    final current = state.asData?.value;
    if (current == null || current.statusFilter == status) return;
    await _reloadWithFilters(
      current,
      statusFilter: status,
      workflowFilter: current.workflowFilter,
    );
  }

  /// Sets [workflowId] as the active workflow filter (`null` for all) and
  /// reloads.
  Future<void> setWorkflowFilter(String? workflowId) async {
    final current = state.asData?.value;
    if (current == null || current.workflowFilter == workflowId) return;
    await _reloadWithFilters(
      current,
      statusFilter: current.statusFilter,
      workflowFilter: workflowId,
    );
  }

  /// Clears all active status and workflow filters and reloads.
  Future<void> clearFilters() async {
    final current = state.asData?.value;
    if (current == null || !current.hasActiveFilters) return;
    await _reloadWithFilters(current, statusFilter: null, workflowFilter: null);
  }

  /// Toggles whether child runs of [runId] are expanded in the list (R2).
  void toggleExpanded(String runId) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = Set<String>.from(current.expandedRunIds);
    if (!next.add(runId)) {
      next.remove(runId);
    }
    state = AsyncData(current.copyWith(expandedRunIds: next));
  }

  /// Deletes a non-active run by [id] and removes it (and any loaded
  /// children) from the list on success.
  Future<Result<void>> deleteRun(String id) async {
    _setBusy(id);
    final result = await ref.read(deleteRunProvider).call(id);
    if (!ref.mounted) return result;

    switch (result) {
      case Success<void>():
        final current = state.asData?.value;
        if (current != null) {
          final remaining = current.runs
              .where((run) => run.id != id && run.parentRunId != id)
              .toList();
          final removedCount = current.runs.length - remaining.length;
          final nextTotal = current.total - removedCount;
          final nextExpanded = Set<String>.from(current.expandedRunIds)
            ..remove(id);
          state = AsyncData(
            current.copyWith(
              runs: remaining,
              total: nextTotal < 0 ? 0 : nextTotal,
              expandedRunIds: nextExpanded,
              busyRunId: () => null,
              actionFailure: () => null,
            ),
          );
        }
        return const Success<void>(null);
      case FailureResult<void>(:final failure):
        _setBusy(null, actionFailure: failure);
        return FailureResult<void>(failure);
    }
  }

  Future<void> _reloadWithFilters(
    RunsListState current, {
    required RunStatus? statusFilter,
    required String? workflowFilter,
  }) async {
    final selection = _workspaceSelection;
    if (selection.isGlobal || selection.workspaceId == null) return;
    final token = ++_requestToken;
    final runsResult = await ref
        .read(listRunsProvider)
        .call(
          workspaceId: selection.workspaceId,
          status: statusFilter,
          workflowId: workflowFilter,
          limit: pageSize,
          offset: 0,
        );
    if (!ref.mounted || token != _requestToken) return;

    switch (runsResult) {
      case Success<RunsListResponse>(:final value):
        state = AsyncData(
          current.copyWith(
            runs: value.items,
            total: value.total,
            statusFilter: () => statusFilter,
            workflowFilter: () => workflowFilter,
            isLoadingMore: false,
            actionFailure: () => null,
          ),
        );
      case FailureResult<RunsListResponse>(:final failure):
        _setBusy(null, actionFailure: failure);
    }
  }

  Future<RunsListState> _load({
    required RunStatus? statusFilter,
    required String? workflowFilter,
    required String? workspaceId,
    required bool isGlobal,
  }) async {
    if (isGlobal || workspaceId == null) {
      return RunsListState(
        runs: const <RunSummary>[],
        total: 0,
        workflows: const <WorkflowSummary>[],
        isGlobalSelected: true,
        statusFilter: statusFilter,
        workflowFilter: workflowFilter,
      );
    }

    final runsFuture = ref
        .read(listRunsProvider)
        .call(
          workspaceId: workspaceId,
          status: statusFilter,
          workflowId: workflowFilter,
          limit: pageSize,
          offset: 0,
        );
    final workflowsFuture = ref
        .read(listWorkflowsProvider)
        .call(scope: DefinitionScope.ofWorkspaceId(workspaceId));

    final runsResult = await runsFuture;
    final workflowsResult = await workflowsFuture;

    final workflows = workflowsResult.valueOrNull ?? const <WorkflowSummary>[];
    return switch (runsResult) {
      Success<RunsListResponse>(:final value) => RunsListState(
        runs: value.items,
        total: value.total,
        workflows: workflows,
        statusFilter: statusFilter,
        workflowFilter: workflowFilter,
      ),
      FailureResult<RunsListResponse>(:final failure) =>
        Error.throwWithStackTrace(failure, StackTrace.current),
    };
  }

  void _setBusy(String? id, {Failure? actionFailure}) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(busyRunId: () => id, actionFailure: () => actionFailure),
    );
  }
}
