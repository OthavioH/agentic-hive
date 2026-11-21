// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [RunsRemoteDataSource] backed by [backendClientProvider].

@ProviderFor(runsRemoteDataSource)
final runsRemoteDataSourceProvider = RunsRemoteDataSourceProvider._();

/// Provides the [RunsRemoteDataSource] backed by [backendClientProvider].

final class RunsRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          RunsRemoteDataSource,
          RunsRemoteDataSource,
          RunsRemoteDataSource
        >
    with $Provider<RunsRemoteDataSource> {
  /// Provides the [RunsRemoteDataSource] backed by [backendClientProvider].
  RunsRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runsRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runsRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<RunsRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RunsRemoteDataSource create(Ref ref) {
    return runsRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RunsRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RunsRemoteDataSource>(value),
    );
  }
}

String _$runsRemoteDataSourceHash() =>
    r'5533718416eca42d693d2d7fbd7b74d7acf7fc04';

/// Provides the [RunRepository] interface.

@ProviderFor(runRepository)
final runRepositoryProvider = RunRepositoryProvider._();

/// Provides the [RunRepository] interface.

final class RunRepositoryProvider
    extends $FunctionalProvider<RunRepository, RunRepository, RunRepository>
    with $Provider<RunRepository> {
  /// Provides the [RunRepository] interface.
  RunRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runRepositoryHash();

  @$internal
  @override
  $ProviderElement<RunRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RunRepository create(Ref ref) {
    return runRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RunRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RunRepository>(value),
    );
  }
}

String _$runRepositoryHash() => r'f486dcc1e985ab51ab320dd47bfac58f3bf288c5';
