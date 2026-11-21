// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backend_launcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the OS-appropriate [BackendLauncher].
///
/// Tests can override this provider with a fake [BackendLauncher].

@ProviderFor(backendLauncher)
final backendLauncherProvider = BackendLauncherProvider._();

/// Provides the OS-appropriate [BackendLauncher].
///
/// Tests can override this provider with a fake [BackendLauncher].

final class BackendLauncherProvider
    extends
        $FunctionalProvider<BackendLauncher, BackendLauncher, BackendLauncher>
    with $Provider<BackendLauncher> {
  /// Provides the OS-appropriate [BackendLauncher].
  ///
  /// Tests can override this provider with a fake [BackendLauncher].
  BackendLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backendLauncherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backendLauncherHash();

  @$internal
  @override
  $ProviderElement<BackendLauncher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackendLauncher create(Ref ref) {
    return backendLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackendLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackendLauncher>(value),
    );
  }
}

String _$backendLauncherHash() => r'd77497fd9cc19651a1e602ee0fb8af8e90cd97be';
