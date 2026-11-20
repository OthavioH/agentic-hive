// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backend_connection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks connectivity to the local backend and supports reconnection.

@ProviderFor(BackendConnection)
final backendConnectionProvider = BackendConnectionProvider._();

/// Tracks connectivity to the local backend and supports reconnection.
final class BackendConnectionProvider
    extends $NotifierProvider<BackendConnection, BackendConnectionState> {
  /// Tracks connectivity to the local backend and supports reconnection.
  BackendConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backendConnectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backendConnectionHash();

  @$internal
  @override
  BackendConnection create() => BackendConnection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackendConnectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackendConnectionState>(value),
    );
  }
}

String _$backendConnectionHash() => r'43e10a91d5eeb6352f5e7c4423ef3bea524759f7';

/// Tracks connectivity to the local backend and supports reconnection.

abstract class _$BackendConnection extends $Notifier<BackendConnectionState> {
  BackendConnectionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<BackendConnectionState, BackendConnectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BackendConnectionState, BackendConnectionState>,
              BackendConnectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
