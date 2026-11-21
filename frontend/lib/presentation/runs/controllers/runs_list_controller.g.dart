// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runs_list_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages the runs list, status/workflow filters, and deletion.

@ProviderFor(RunsListController)
final runsListControllerProvider = RunsListControllerProvider._();

/// Manages the runs list, status/workflow filters, and deletion.
final class RunsListControllerProvider
    extends $AsyncNotifierProvider<RunsListController, RunsListState> {
  /// Manages the runs list, status/workflow filters, and deletion.
  RunsListControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runsListControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runsListControllerHash();

  @$internal
  @override
  RunsListController create() => RunsListController();
}

String _$runsListControllerHash() =>
    r'fdb6e34e0fccd0d484e962e2d7591a53938028e9';

/// Manages the runs list, status/workflow filters, and deletion.

abstract class _$RunsListController extends $AsyncNotifier<RunsListState> {
  FutureOr<RunsListState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RunsListState>, RunsListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RunsListState>, RunsListState>,
              AsyncValue<RunsListState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
