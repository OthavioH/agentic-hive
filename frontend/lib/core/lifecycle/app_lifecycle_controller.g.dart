// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lifecycle_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Coordinates backend auto-launch on startup, window close-to-tray behavior,
/// system tray menu actions, and graceful backend shutdown (Spec #13).

@ProviderFor(AppLifecycleController)
final appLifecycleControllerProvider = AppLifecycleControllerProvider._();

/// Coordinates backend auto-launch on startup, window close-to-tray behavior,
/// system tray menu actions, and graceful backend shutdown (Spec #13).
final class AppLifecycleControllerProvider
    extends $NotifierProvider<AppLifecycleController, AppLifecycleState> {
  /// Coordinates backend auto-launch on startup, window close-to-tray behavior,
  /// system tray menu actions, and graceful backend shutdown (Spec #13).
  AppLifecycleControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLifecycleControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLifecycleControllerHash();

  @$internal
  @override
  AppLifecycleController create() => AppLifecycleController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLifecycleState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLifecycleState>(value),
    );
  }
}

String _$appLifecycleControllerHash() =>
    r'bb8cfcc9212dd586a15cd8664ae02bce3992e5c0';

/// Coordinates backend auto-launch on startup, window close-to-tray behavior,
/// system tray menu actions, and graceful backend shutdown (Spec #13).

abstract class _$AppLifecycleController extends $Notifier<AppLifecycleState> {
  AppLifecycleState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppLifecycleState, AppLifecycleState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppLifecycleState, AppLifecycleState>,
              AppLifecycleState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
