// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backend_connection_config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides [BackendConnectionConfig] for `BackendConnection`.
///
/// Tests can override this provider to control clocks, timers, and jitter
/// deterministically.

@ProviderFor(backendConnectionConfig)
final backendConnectionConfigProvider = BackendConnectionConfigProvider._();

/// Provides [BackendConnectionConfig] for `BackendConnection`.
///
/// Tests can override this provider to control clocks, timers, and jitter
/// deterministically.

final class BackendConnectionConfigProvider
    extends
        $FunctionalProvider<
          BackendConnectionConfig,
          BackendConnectionConfig,
          BackendConnectionConfig
        >
    with $Provider<BackendConnectionConfig> {
  /// Provides [BackendConnectionConfig] for `BackendConnection`.
  ///
  /// Tests can override this provider to control clocks, timers, and jitter
  /// deterministically.
  BackendConnectionConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backendConnectionConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backendConnectionConfigHash();

  @$internal
  @override
  $ProviderElement<BackendConnectionConfig> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackendConnectionConfig create(Ref ref) {
    return backendConnectionConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackendConnectionConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackendConnectionConfig>(value),
    );
  }
}

String _$backendConnectionConfigHash() =>
    r'b825d4324b83fcd26c1d9f0ad317f88be48c2b83';
