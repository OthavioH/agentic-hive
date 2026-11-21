import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workflows_list_controller.g.dart';

/// View state for the Workflows list page.
@immutable
final class WorkflowsListState {
  /// Creates a [WorkflowsListState].
  const new({
    required this.workflows,
    this.searchQuery = '',
    this.busyWorkflowId,
    this.actionFailure,
  });

  /// All loaded workflow summaries.
  final List<WorkflowSummary> workflows;

  /// Current search filter text.
  final String searchQuery;

  /// ID of the workflow currently undergoing duplicate or delete.
  final String? busyWorkflowId;

  /// Transient failure from a list action (create, duplicate, delete).
  final Failure? actionFailure;

  /// Workflows matching [searchQuery].
  List<WorkflowSummary> get filteredWorkflows {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return workflows;
    return workflows.where((workflow) {
      final nameMatches = workflow.name.toLowerCase().contains(query);
      final descriptionMatches =
          workflow.description?.toLowerCase().contains(query) ?? false;
      return nameMatches || descriptionMatches;
    }).toList();
  }

  /// Returns a copy with updated fields.
  WorkflowsListState copyWith({
    List<WorkflowSummary>? workflows,
    String? searchQuery,
    String? Function()? busyWorkflowId,
    Failure? Function()? actionFailure,
  }) {
    return WorkflowsListState(
      workflows: workflows ?? this.workflows,
      searchQuery: searchQuery ?? this.searchQuery,
      busyWorkflowId: busyWorkflowId != null
          ? busyWorkflowId()
          : this.busyWorkflowId,
      actionFailure: actionFailure != null
          ? actionFailure()
          : this.actionFailure,
    );
  }
}

/// Manages the saved workflows list, search filter, and CRUD actions.
@riverpod
class WorkflowsListController extends _$WorkflowsListController {
  @override
  Future<WorkflowsListState> build() async {
    final result = await ref.read(listWorkflowsProvider).call();
    return switch (result) {
      Success<List<WorkflowSummary>>(:final value) => WorkflowsListState(
        workflows: value,
      ),
      FailureResult<List<WorkflowSummary>>(:final failure) =>
        Error.throwWithStackTrace(failure, StackTrace.current),
    };
  }

  /// Reloads the workflow list from the backend.
  Future<void> refresh() async {
    final currentQuery = state.asData?.value.searchQuery ?? '';
    state = const AsyncLoading<WorkflowsListState>();
    final result = await ref.read(listWorkflowsProvider).call();
    if (!ref.mounted) return;
    state = switch (result) {
      Success<List<WorkflowSummary>>(:final value) => AsyncData(
        WorkflowsListState(workflows: value, searchQuery: currentQuery),
      ),
      FailureResult<List<WorkflowSummary>>(:final failure) => AsyncError(
        failure,
        StackTrace.current,
      ),
    };
  }

  /// Updates the search filter query.
  void setSearchQuery(String query) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(searchQuery: query));
  }

  /// Creates a new workflow and refreshes the list on success.
  Future<Result<Workflow>> createWorkflow({
    required String name,
    String? description,
  }) async {
    final trimmedName = name.trim();
    final trimmedDescription = description?.trim();
    final result = await ref
        .read(createWorkflowProvider)
        .call(
          CreateWorkflowRequest(
            name: trimmedName,
            description:
                trimmedDescription == null || trimmedDescription.isEmpty
                ? null
                : trimmedDescription,
          ),
        );
    if (!ref.mounted) return result.map((response) => response.workflow);

    switch (result) {
      case Success<WorkflowResponse>(:final value):
        await _reloadSilently();
        return Success<Workflow>(value.workflow);
      case FailureResult<WorkflowResponse>(:final failure):
        _setActionFailure(failure);
        return FailureResult<Workflow>(failure);
    }
  }

  /// Duplicates an existing workflow and refreshes the list on success.
  Future<Result<Workflow>> duplicateWorkflow(String id) async {
    _setBusy(id);
    final result = await ref.read(duplicateWorkflowProvider).call(id);
    if (!ref.mounted) return result.map((response) => response.workflow);

    switch (result) {
      case Success<WorkflowResponse>(:final value):
        await _reloadSilently();
        return Success<Workflow>(value.workflow);
      case FailureResult<WorkflowResponse>(:final failure):
        _setBusy(null, actionFailure: failure);
        return FailureResult<Workflow>(failure);
    }
  }

  /// Deletes a workflow and updates the list on success.
  Future<Result<void>> deleteWorkflow(String id) async {
    _setBusy(id);
    final result = await ref.read(deleteWorkflowProvider).call(id);
    if (!ref.mounted) return result;

    switch (result) {
      case Success<void>():
        final current = state.asData?.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              workflows: current.workflows
                  .where((workflow) => workflow.id != id)
                  .toList(),
              busyWorkflowId: () => null,
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

  Future<void> _reloadSilently() async {
    final result = await ref.read(listWorkflowsProvider).call();
    if (!ref.mounted) return;
    final current = state.asData?.value;
    switch (result) {
      case Success<List<WorkflowSummary>>(:final value):
        state = AsyncData(
          WorkflowsListState(
            workflows: value,
            searchQuery: current?.searchQuery ?? '',
          ),
        );
      case FailureResult<List<WorkflowSummary>>(:final failure):
        _setBusy(null, actionFailure: failure);
    }
  }

  void _setBusy(String? id, {Failure? actionFailure}) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        busyWorkflowId: () => id,
        actionFailure: () => actionFailure,
      ),
    );
  }

  void _setActionFailure(Failure failure) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(actionFailure: () => failure));
  }
}
