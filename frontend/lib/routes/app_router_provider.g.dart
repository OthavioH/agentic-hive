// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the application's [GoRouter] instance, reacting to
/// [backendConnectionProvider] via a `refreshListenable`.

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// Provides the application's [GoRouter] instance, reacting to
/// [backendConnectionProvider] via a `refreshListenable`.

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// Provides the application's [GoRouter] instance, reacting to
  /// [backendConnectionProvider] via a `refreshListenable`.
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'2f453e93b87fd6aafa1dbe7a1450ac6c7b34b315';
