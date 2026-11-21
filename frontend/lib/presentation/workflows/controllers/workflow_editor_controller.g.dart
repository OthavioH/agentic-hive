// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages editing, selection, validation, and saving of a single workflow.

@ProviderFor(WorkflowEditorController)
final workflowEditorControllerProvider = WorkflowEditorControllerFamily._();

/// Manages editing, selection, validation, and saving of a single workflow.
final class WorkflowEditorControllerProvider
    extends
        $AsyncNotifierProvider<WorkflowEditorController, WorkflowEditorState> {
  /// Manages editing, selection, validation, and saving of a single workflow.
  WorkflowEditorControllerProvider._({
    required WorkflowEditorControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workflowEditorControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workflowEditorControllerHash();

  @override
  String toString() {
    return r'workflowEditorControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WorkflowEditorController create() => WorkflowEditorController();

  @override
  bool operator ==(Object other) {
    return other is WorkflowEditorControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workflowEditorControllerHash() =>
    r'9bf7ec435357121bdd92f9c518a8b3a813482125';

/// Manages editing, selection, validation, and saving of a single workflow.

final class WorkflowEditorControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          WorkflowEditorController,
          AsyncValue<WorkflowEditorState>,
          WorkflowEditorState,
          FutureOr<WorkflowEditorState>,
          String
        > {
  WorkflowEditorControllerFamily._()
    : super(
        retry: null,
        name: r'workflowEditorControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Manages editing, selection, validation, and saving of a single workflow.

  WorkflowEditorControllerProvider call(String workflowId) =>
      WorkflowEditorControllerProvider._(argument: workflowId, from: this);

  @override
  String toString() => r'workflowEditorControllerProvider';
}

/// Manages editing, selection, validation, and saving of a single workflow.

abstract class _$WorkflowEditorController
    extends $AsyncNotifier<WorkflowEditorState> {
  late final _$args = ref.$arg as String;
  String get workflowId => _$args;

  FutureOr<WorkflowEditorState> build(String workflowId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<WorkflowEditorState>, WorkflowEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WorkflowEditorState>, WorkflowEditorState>,
              AsyncValue<WorkflowEditorState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
