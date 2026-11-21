// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflows_list_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages the saved workflows list, search filter, and CRUD actions.

@ProviderFor(WorkflowsListController)
final workflowsListControllerProvider = WorkflowsListControllerProvider._();

/// Manages the saved workflows list, search filter, and CRUD actions.
final class WorkflowsListControllerProvider
    extends
        $AsyncNotifierProvider<WorkflowsListController, WorkflowsListState> {
  /// Manages the saved workflows list, search filter, and CRUD actions.
  WorkflowsListControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workflowsListControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workflowsListControllerHash();

  @$internal
  @override
  WorkflowsListController create() => WorkflowsListController();
}

String _$workflowsListControllerHash() =>
    r'bdff465babe4253c3c51e8ea3e65f6c0148dd909';

/// Manages the saved workflows list, search filter, and CRUD actions.

abstract class _$WorkflowsListController
    extends $AsyncNotifier<WorkflowsListState> {
  FutureOr<WorkflowsListState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<WorkflowsListState>, WorkflowsListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WorkflowsListState>, WorkflowsListState>,
              AsyncValue<WorkflowsListState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
