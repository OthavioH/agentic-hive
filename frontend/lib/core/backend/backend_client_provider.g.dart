// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backend_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the app-wide [BackendClient] over the local Unix domain socket.
///
/// Tests can override this provider with a fake [BackendClient].

@ProviderFor(backendClient)
final backendClientProvider = BackendClientProvider._();

/// Provides the app-wide [BackendClient] over the local Unix domain socket.
///
/// Tests can override this provider with a fake [BackendClient].

final class BackendClientProvider
    extends $FunctionalProvider<BackendClient, BackendClient, BackendClient>
    with $Provider<BackendClient> {
  /// Provides the app-wide [BackendClient] over the local Unix domain socket.
  ///
  /// Tests can override this provider with a fake [BackendClient].
  BackendClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backendClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backendClientHash();

  @$internal
  @override
  $ProviderElement<BackendClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackendClient create(Ref ref) {
    return backendClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackendClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackendClient>(value),
    );
  }
}

String _$backendClientHash() => r'75fee5aa1482c6dff10e0b2eb8842286b6028ae9';
