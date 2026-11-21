// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [WorkflowRemoteDataSource] backed by [backendClientProvider].

@ProviderFor(workflowRemoteDataSource)
final workflowRemoteDataSourceProvider = WorkflowRemoteDataSourceProvider._();

/// Provides the [WorkflowRemoteDataSource] backed by [backendClientProvider].

final class WorkflowRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          WorkflowRemoteDataSource,
          WorkflowRemoteDataSource,
          WorkflowRemoteDataSource
        >
    with $Provider<WorkflowRemoteDataSource> {
  /// Provides the [WorkflowRemoteDataSource] backed by [backendClientProvider].
  WorkflowRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workflowRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workflowRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<WorkflowRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkflowRemoteDataSource create(Ref ref) {
    return workflowRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkflowRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkflowRemoteDataSource>(value),
    );
  }
}

String _$workflowRemoteDataSourceHash() =>
    r'8f23e3814b79489df1081e963c771ee401c4609d';

/// Provides the [WorkflowRepository] interface.

@ProviderFor(workflowRepository)
final workflowRepositoryProvider = WorkflowRepositoryProvider._();

/// Provides the [WorkflowRepository] interface.

final class WorkflowRepositoryProvider
    extends
        $FunctionalProvider<
          WorkflowRepository,
          WorkflowRepository,
          WorkflowRepository
        >
    with $Provider<WorkflowRepository> {
  /// Provides the [WorkflowRepository] interface.
  WorkflowRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workflowRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workflowRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkflowRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkflowRepository create(Ref ref) {
    return workflowRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkflowRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkflowRepository>(value),
    );
  }
}

String _$workflowRepositoryHash() =>
    r'd3225ccca1e4440d59d6ffde88a5df3c1c9fa37a';
