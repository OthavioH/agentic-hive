// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harnesses_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages the Harnesses page state, refresh actions, and live WebSocket
/// status updates.

@ProviderFor(HarnessesController)
final harnessesControllerProvider = HarnessesControllerProvider._();

/// Manages the Harnesses page state, refresh actions, and live WebSocket
/// status updates.
final class HarnessesControllerProvider
    extends $AsyncNotifierProvider<HarnessesController, HarnessesState> {
  /// Manages the Harnesses page state, refresh actions, and live WebSocket
  /// status updates.
  HarnessesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'harnessesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$harnessesControllerHash();

  @$internal
  @override
  HarnessesController create() => HarnessesController();
}

String _$harnessesControllerHash() =>
    r'186bb968717f4c952275916c65ac83a45336dc14';

/// Manages the Harnesses page state, refresh actions, and live WebSocket
/// status updates.

abstract class _$HarnessesController extends $AsyncNotifier<HarnessesState> {
  FutureOr<HarnessesState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<HarnessesState>, HarnessesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<HarnessesState>, HarnessesState>,
              AsyncValue<HarnessesState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
