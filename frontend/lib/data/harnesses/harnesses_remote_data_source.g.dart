// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harnesses_remote_data_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [HarnessesRemoteDataSource] wired to [backendClientProvider]
/// and the active WebSocket session.

@ProviderFor(harnessesRemoteDataSource)
final harnessesRemoteDataSourceProvider = HarnessesRemoteDataSourceProvider._();

/// Provides the [HarnessesRemoteDataSource] wired to [backendClientProvider]
/// and the active WebSocket session.

final class HarnessesRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          HarnessesRemoteDataSource,
          HarnessesRemoteDataSource,
          HarnessesRemoteDataSource
        >
    with $Provider<HarnessesRemoteDataSource> {
  /// Provides the [HarnessesRemoteDataSource] wired to [backendClientProvider]
  /// and the active WebSocket session.
  HarnessesRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'harnessesRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$harnessesRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<HarnessesRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HarnessesRemoteDataSource create(Ref ref) {
    return harnessesRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HarnessesRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HarnessesRemoteDataSource>(value),
    );
  }
}

String _$harnessesRemoteDataSourceHash() =>
    r'a95e90d3349a018fcf8fa4c2a3b05a474ad8c977';
