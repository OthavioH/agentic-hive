// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [AgentsRemoteDataSource] backed by [backendClientProvider].

@ProviderFor(agentsRemoteDataSource)
final agentsRemoteDataSourceProvider = AgentsRemoteDataSourceProvider._();

/// Provides the [AgentsRemoteDataSource] backed by [backendClientProvider].

final class AgentsRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          AgentsRemoteDataSource,
          AgentsRemoteDataSource,
          AgentsRemoteDataSource
        >
    with $Provider<AgentsRemoteDataSource> {
  /// Provides the [AgentsRemoteDataSource] backed by [backendClientProvider].
  AgentsRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentsRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentsRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<AgentsRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AgentsRemoteDataSource create(Ref ref) {
    return agentsRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentsRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentsRemoteDataSource>(value),
    );
  }
}

String _$agentsRemoteDataSourceHash() =>
    r'39b0501b8b1701c129151c445502bd59129a9eaa';

/// Provides the [AgentRepository] implementation, forwarding live
/// `agents.changed` WebSocket events from [backendConnectionProvider].

@ProviderFor(agentRepository)
final agentRepositoryProvider = AgentRepositoryProvider._();

/// Provides the [AgentRepository] implementation, forwarding live
/// `agents.changed` WebSocket events from [backendConnectionProvider].

final class AgentRepositoryProvider
    extends
        $FunctionalProvider<AgentRepository, AgentRepository, AgentRepository>
    with $Provider<AgentRepository> {
  /// Provides the [AgentRepository] implementation, forwarding live
  /// `agents.changed` WebSocket events from [backendConnectionProvider].
  AgentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentRepositoryHash();

  @$internal
  @override
  $ProviderElement<AgentRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AgentRepository create(Ref ref) {
    return agentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentRepository>(value),
    );
  }
}

String _$agentRepositoryHash() => r'3820609eb2e6715f9f51f6c45ecc32670fa01be2';
