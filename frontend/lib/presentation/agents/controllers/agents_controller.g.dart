// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agents_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages the Agent library list, search/tag filters, inline creation,
/// structured draft editing, `expectedHash` conflict resolution, and live
/// WebSocket synchronization.

@ProviderFor(AgentsController)
final agentsControllerProvider = AgentsControllerProvider._();

/// Manages the Agent library list, search/tag filters, inline creation,
/// structured draft editing, `expectedHash` conflict resolution, and live
/// WebSocket synchronization.
final class AgentsControllerProvider
    extends $NotifierProvider<AgentsController, AgentsState> {
  /// Manages the Agent library list, search/tag filters, inline creation,
  /// structured draft editing, `expectedHash` conflict resolution, and live
  /// WebSocket synchronization.
  AgentsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentsControllerHash();

  @$internal
  @override
  AgentsController create() => AgentsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentsState>(value),
    );
  }
}

String _$agentsControllerHash() => r'7f82eabd151834e9071b3c02fedd51f904860146';

/// Manages the Agent library list, search/tag filters, inline creation,
/// structured draft editing, `expectedHash` conflict resolution, and live
/// WebSocket synchronization.

abstract class _$AgentsController extends $Notifier<AgentsState> {
  AgentsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AgentsState, AgentsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AgentsState, AgentsState>,
              AgentsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
