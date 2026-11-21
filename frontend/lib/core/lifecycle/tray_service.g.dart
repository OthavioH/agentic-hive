// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tray_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the OS-appropriate [TrayService].
///
/// Tests can override this provider with a fake [TrayService].

@ProviderFor(trayService)
final trayServiceProvider = TrayServiceProvider._();

/// Provides the OS-appropriate [TrayService].
///
/// Tests can override this provider with a fake [TrayService].

final class TrayServiceProvider
    extends $FunctionalProvider<TrayService, TrayService, TrayService>
    with $Provider<TrayService> {
  /// Provides the OS-appropriate [TrayService].
  ///
  /// Tests can override this provider with a fake [TrayService].
  TrayServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trayServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trayServiceHash();

  @$internal
  @override
  $ProviderElement<TrayService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TrayService create(Ref ref) {
    return trayService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrayService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrayService>(value),
    );
  }
}

String _$trayServiceHash() => r'd919a139e585661bf88cfd71732d21bbfcba761e';
