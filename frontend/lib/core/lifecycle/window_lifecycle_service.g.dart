// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_lifecycle_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the OS-appropriate [WindowLifecycleService].
///
/// Tests can override this provider with a fake [WindowLifecycleService].

@ProviderFor(windowLifecycleService)
final windowLifecycleServiceProvider = WindowLifecycleServiceProvider._();

/// Provides the OS-appropriate [WindowLifecycleService].
///
/// Tests can override this provider with a fake [WindowLifecycleService].

final class WindowLifecycleServiceProvider
    extends
        $FunctionalProvider<
          WindowLifecycleService,
          WindowLifecycleService,
          WindowLifecycleService
        >
    with $Provider<WindowLifecycleService> {
  /// Provides the OS-appropriate [WindowLifecycleService].
  ///
  /// Tests can override this provider with a fake [WindowLifecycleService].
  WindowLifecycleServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowLifecycleServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowLifecycleServiceHash();

  @$internal
  @override
  $ProviderElement<WindowLifecycleService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WindowLifecycleService create(Ref ref) {
    return windowLifecycleService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WindowLifecycleService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WindowLifecycleService>(value),
    );
  }
}

String _$windowLifecycleServiceHash() =>
    r'1b5b567ac7d510ffcc67439a58f27597d483575b';
