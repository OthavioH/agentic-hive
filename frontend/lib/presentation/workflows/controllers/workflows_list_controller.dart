import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_delete_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// ID of the workflow currently undergoing duplicate.
  final String? busyWorkflowId;

  /// Transient failure from a list action (create, duplicate).
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
///
/// The list covers the global workflows plus those of the current workspace
/// (each item carries its scope). With the Global entry selected, or without a
/// workspace, only global workflows are listed. Workspace workflow files that
/// change on disk, and workflows written through MCP, refresh the list live.
@riverpod
class WorkflowsListController extends _$WorkflowsListController {
  /// Scope whose workflows are listed besides the global ones.
  DefinitionScope get _scope => DefinitionScope.ofWorkspaceId(
    ref.read(
      workspaceRegistryControllerProvider.select(
        (state) => state.asData?.value.currentWorkspaceId,
      ),
    ),
  );

  @override
  Future<WorkflowsListState> build() async {
    final workspaceId = ref.watch(
      workspaceRegistryControllerProvider.select(
        (state) => state.asData?.value.currentWorkspaceId,
      ),
    );
    final scope = DefinitionScope.ofWorkspaceId(workspaceId);
    final changes = ref.read(watchWorkflowChangesProvider).call().listen((
      payload,
    ) {
      if (payload.workspaceId == null ||
          payload.workspaceId == _scope.workspaceIdOrNull) {
        unawaited(_reloadSilently());
      }
    });
    ref.onDispose(() => unawaited(changes.cancel()));
    // Deletions finish for any client (MCP, another window): clear the row
    // whose deletion ended, whoever started it (ADR 0027).
    final deletions = ref
        .read(watchWorkflowDeletionsProvider)
        .call()
        .listen(_applyFinishedDeletion);
    ref.onDispose(() => unawaited(deletions.cancel()));
    // Rows deleted by the Workflows page's delete flow leave the list.
    ref.listen(
      workflowDeleteControllerProvider.select((state) => state.removed),
      (previous, next) {
        for (final key in next.difference(previous ?? const {})) {
          removeWorkflow(key.id, scope: key.scope);
        }
      },
    );
    final result = await ref.read(listWorkflowsProvider).call(scope: scope);
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
    final result = await ref.read(listWorkflowsProvider).call(scope: _scope);
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
  ///
  /// It is stored in [scope].
  Future<Result<Workflow>> createWorkflow({
    required String name,
    String? description,
    DefinitionScope scope = const GlobalScope(),
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
            workspaceId: scope.workspaceIdOrNull,
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

  /// Duplicates an existing workflow of [scope] and refreshes the list on
  /// success.
  Future<Result<Workflow>> duplicateWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    _setBusy(id);
    final result = await ref
        .read(duplicateWorkflowProvider)
        .call(id, scope: scope);
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

  /// Marks the listed workflow [id] of [scope] as being deleted, or back to
  /// normal (ADR 0027).
  void setDeleting(
    String id, {
    required DefinitionScope scope,
    required bool deleting,
  }) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        workflows: [
          for (final workflow in current.workflows)
            if (workflow.id == id && workflow.scope == scope)
              workflow.copyWith(deleting: deleting)
            else
              workflow,
        ],
      ),
    );
  }

  /// Removes the listed workflow [id] of [scope] after its deletion.
  void removeWorkflow(String id, {required DefinitionScope scope}) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        workflows: current.workflows
            .where((workflow) => workflow.id != id || workflow.scope != scope)
            .toList(),
      ),
    );
  }

  /// A deletion ended on the backend: the row goes on success and returns to
  /// normal on failure. Rows of other scopes are left alone.
  void _applyFinishedDeletion(WorkflowDeletionFinished event) {
    final current = state.asData?.value;
    if (current == null) return;
    final eventScope = DefinitionScope.ofWorkspaceId(event.workspaceId);
    final listed = current.workflows.any(
      (workflow) =>
          workflow.id == event.workflowId && workflow.scope == eventScope,
    );
    if (!listed) return;
    if (event.failure == null) {
      removeWorkflow(event.workflowId, scope: eventScope);
    } else {
      setDeleting(event.workflowId, scope: eventScope, deleting: false);
    }
  }

  Future<void> _reloadSilently() async {
    final result = await ref.read(listWorkflowsProvider).call(scope: _scope);
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
