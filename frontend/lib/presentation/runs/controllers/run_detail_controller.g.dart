// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages loading and interactive inspection for a single run (`runId`).

@ProviderFor(RunDetailController)
final runDetailControllerProvider = RunDetailControllerFamily._();

/// Manages loading and interactive inspection for a single run (`runId`).
final class RunDetailControllerProvider
    extends $AsyncNotifierProvider<RunDetailController, RunDetailState> {
  /// Manages loading and interactive inspection for a single run (`runId`).
  RunDetailControllerProvider._({
    required RunDetailControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'runDetailControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$runDetailControllerHash();

  @override
  String toString() {
    return r'runDetailControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RunDetailController create() => RunDetailController();

  @override
  bool operator ==(Object other) {
    return other is RunDetailControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$runDetailControllerHash() =>
    r'4006b9881ef133e516e7141568524d6889e24535';

/// Manages loading and interactive inspection for a single run (`runId`).

final class RunDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          RunDetailController,
          AsyncValue<RunDetailState>,
          RunDetailState,
          FutureOr<RunDetailState>,
          String
        > {
  RunDetailControllerFamily._()
    : super(
        retry: null,
        name: r'runDetailControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Manages loading and interactive inspection for a single run (`runId`).

  RunDetailControllerProvider call(String runId) =>
      RunDetailControllerProvider._(argument: runId, from: this);

  @override
  String toString() => r'runDetailControllerProvider';
}

/// Manages loading and interactive inspection for a single run (`runId`).

abstract class _$RunDetailController extends $AsyncNotifier<RunDetailState> {
  late final _$args = ref.$arg as String;
  String get runId => _$args;

  FutureOr<RunDetailState> build(String runId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<RunDetailState>, RunDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RunDetailState>, RunDetailState>,
              AsyncValue<RunDetailState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
