import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
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
    this.statusFilter,
    this.workflowFilter,
    this.busyRunId,
    this.actionFailure,
  });

  /// Loaded run summaries matching the active filters.
  final List<RunSummary> runs;

  /// Total number of matching runs reported by the backend.
  final int total;

  /// Available workflows for the workflow filter dropdown.
  final List<WorkflowSummary> workflows;

  /// Active status filter, or `null` for all statuses.
  final RunStatus? statusFilter;

  /// Active workflow ID filter, or `null` for all workflows.
  final String? workflowFilter;

  /// ID of the run currently undergoing deletion.
  final String? busyRunId;

  /// Transient failure from a list action such as delete.
  final Failure? actionFailure;

  /// Whether any status or workflow filter is active.
  bool get hasActiveFilters => statusFilter != null || workflowFilter != null;

  /// Returns a copy with updated fields.
  RunsListState copyWith({
    List<RunSummary>? runs,
    int? total,
    List<WorkflowSummary>? workflows,
    RunStatus? Function()? statusFilter,
    String? Function()? workflowFilter,
    String? Function()? busyRunId,
    Failure? Function()? actionFailure,
  }) {
    return RunsListState(
      runs: runs ?? this.runs,
      total: total ?? this.total,
      workflows: workflows ?? this.workflows,
      statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
      workflowFilter: workflowFilter != null
          ? workflowFilter()
          : this.workflowFilter,
      busyRunId: busyRunId != null ? busyRunId() : this.busyRunId,
      actionFailure: actionFailure != null
          ? actionFailure()
          : this.actionFailure,
    );
  }
}

/// Manages the runs list, status/workflow filters, and deletion.
@riverpod
class RunsListController extends _$RunsListController {
  @override
  Future<RunsListState> build() {
    return _load(statusFilter: null, workflowFilter: null);
  }

  /// Reloads runs and workflows preserving the current filters.
  Future<void> refresh() async {
    final current = state.asData?.value;
    final statusFilter = current?.statusFilter;
    final workflowFilter = current?.workflowFilter;
    state = const AsyncLoading<RunsListState>();
    try {
      final loaded = await _load(
        statusFilter: statusFilter,
        workflowFilter: workflowFilter,
      );
      if (!ref.mounted) return;
      state = AsyncData(loaded);
    } on Failure catch (failure, stackTrace) {
      if (!ref.mounted) return;
      state = AsyncError(failure, stackTrace);
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

  /// Deletes a non-active run by [id] and removes it from the list on success.
  Future<Result<void>> deleteRun(String id) async {
    _setBusy(id);
    final result = await ref.read(deleteRunProvider).call(id);
    if (!ref.mounted) return result;

    switch (result) {
      case Success<void>():
        final current = state.asData?.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              runs: current.runs.where((run) => run.id != id).toList(),
              total: current.total > 0 ? current.total - 1 : 0,
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
    final runsResult = await ref
        .read(listRunsProvider)
        .call(status: statusFilter, workflowId: workflowFilter);
    if (!ref.mounted) return;

    switch (runsResult) {
      case Success<RunsListResponse>(:final value):
        state = AsyncData(
          current.copyWith(
            runs: value.items,
            total: value.total,
            statusFilter: () => statusFilter,
            workflowFilter: () => workflowFilter,
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
  }) async {
    final runsFuture = ref
        .read(listRunsProvider)
        .call(status: statusFilter, workflowId: workflowFilter);
    final workflowsFuture = ref.read(listWorkflowsProvider).call();

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
