// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harness_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [HarnessRepository] implementation.

@ProviderFor(harnessRepository)
final harnessRepositoryProvider = HarnessRepositoryProvider._();

/// Provides the [HarnessRepository] implementation.

final class HarnessRepositoryProvider
    extends
        $FunctionalProvider<
          HarnessRepository,
          HarnessRepository,
          HarnessRepository
        >
    with $Provider<HarnessRepository> {
  /// Provides the [HarnessRepository] implementation.
  HarnessRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'harnessRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$harnessRepositoryHash();

  @$internal
  @override
  $ProviderElement<HarnessRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HarnessRepository create(Ref ref) {
    return harnessRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HarnessRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HarnessRepository>(value),
    );
  }
}

String _$harnessRepositoryHash() => r'5db3face557489c09b9930bab29e07eb30b2d96c';
