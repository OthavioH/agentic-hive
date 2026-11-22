import 'dart:async';
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:nativeapi/nativeapi.dart' as na;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

part 'window_lifecycle_service.g.dart';

/// OS-abstracted desktop window lifecycle service (ADR 0012).
///
/// Intercepts window close events to hide the window to the system tray,
/// restores and focuses the window on demand, and exits the UI cleanly.
abstract interface class WindowLifecycleService {
  /// Whether this platform renders the app's custom title bar.
  bool get hasCustomTitleBar;

  /// Whether the main window is currently maximized.
  ValueListenable<bool> get isMaximized;

  /// Registers native window and application quit listeners and configures
  /// the window title bar style.
  Future<void> initialize({
    required VoidCallback onCloseRequested,
    VoidCallback? onQuitRequested,
  });

  /// Minimizes the main window.
  Future<void> minimize();

  /// Toggles between maximized and restored states.
  Future<void> toggleMaximize();

  /// Starts an interactive window drag from the custom title bar.
  Future<void> startDragging();

  /// Opens the native window system menu at [globalPosition].
  Future<void> showSystemMenu(Offset globalPosition);

  /// Hides the main window to the system tray without exiting.
  Future<void> hideToTray();

  /// Restores (if minimized), shows, and focuses the main window.
  Future<void> showAndFocus();

  /// Exits the Flutter desktop application cleanly.
  Future<void> exitApplication();

  /// Unregisters listeners and releases native handles.
  Future<void> dispose();
}

/// Creates the [WindowLifecycleService] for [operatingSystem].
WindowLifecycleService windowLifecycleServiceFor(String operatingSystem) =>
    switch (operatingSystem) {
      'windows' => WindowsWindowLifecycleService(),
      'linux' => LinuxWindowLifecycleService(),
      'macos' => MacOSWindowLifecycleService(),
      _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
    };

/// The [WindowLifecycleService] of the running platform.
WindowLifecycleService currentWindowLifecycleService() =>
    windowLifecycleServiceFor(Platform.operatingSystem);

/// Shared `nativeapi` implementation of [WindowLifecycleService].
abstract base class NativeWindowLifecycleService
    implements WindowLifecycleService {
  /// Creates a [NativeWindowLifecycleService].
  new({this.quitRunner});

  /// Optional test hook invoked with the exit code instead of calling native
  /// `Application.quit` or `exit`.
  @visibleForTesting
  final void Function(int exitCode)? quitRunner;
  Window? _window;
  ListenerId? _windowListenerId;
  na.ListenerId? _appListenerId;
  final ValueNotifier<bool> _isMaximized = ValueNotifier<bool>(false);
  bool _disposed = false;
  bool _exiting = false;

  @override
  ValueListenable<bool> get isMaximized => _isMaximized;

  /// Whether an exit sequence has started and quit events must not be
  /// cancelled.
  bool get isExiting => _exiting;

  /// Whether hiding the window should also remove it from the OS taskbar.
  bool get hideFromTaskbarWhenHidden;

  /// Whether showing the window should also activate the OS application.
  bool get activateAppOnShow;

  /// Whether a native GUI display session is available for window/app hooks.
  bool get hasDisplay => true;

  @override
  Future<void> initialize({
    required VoidCallback onCloseRequested,
    VoidCallback? onQuitRequested,
  }) async {
    if (_disposed || !hasDisplay) return;

    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      window.titleBarStyle = TitleBarStyle.hidden;
      _isMaximized.value = window.isMaximized;
      if (_windowListenerId == null) {
        _window = window;
        _windowListenerId = window.addListener((event) {
          if (event is WindowCloseRequestedEvent) {
            if (_exiting) return;
            event.request.cancel();
            onCloseRequested();
          } else if (event is WindowMaximizedEvent ||
              event is WindowRestoredEvent) {
            _isMaximized.value = window.isMaximized;
          }
        });
      }
    }

    if (onQuitRequested != null && _appListenerId == null) {
      _appListenerId = na.Application.instance.addListener((event) {
        if (event is na.ApplicationQuitRequestedEvent) {
          handleQuitRequestedEvent(event, onQuitRequested);
        }
      });
    }
  }

  /// Handles an [na.ApplicationQuitRequestedEvent] when intercepted.
  ///
  /// Cancels [event] and invokes [onQuitRequested] unless exit is already in
  /// progress ([isExiting] or disposed).
  @visibleForTesting
  void handleQuitRequestedEvent(
    na.ApplicationQuitRequestedEvent event,
    VoidCallback onQuitRequested,
  ) {
    if (_exiting || _disposed) return;
    event.request.cancel();
    onQuitRequested();
  }

  @override
  Future<void> minimize() async {
    if (_disposed || !hasDisplay) return;
    final window = _window ?? WindowManager.instance.getCurrent();
    if (window == null) return;
    window.minimize();
  }

  @override
  Future<void> toggleMaximize() async {
    if (_disposed || !hasDisplay) return;
    final window = _window ?? WindowManager.instance.getCurrent();
    if (window == null) return;
    if (window.isMaximized) {
      window.unmaximize();
    } else {
      window.maximize();
    }
    _isMaximized.value = window.isMaximized;
  }

  @override
  Future<void> startDragging() async {
    if (_disposed || !hasDisplay) return;
    final window = _window ?? WindowManager.instance.getCurrent();
    if (window == null) return;
    window.startDragging();
  }

  @override
  Future<void> showSystemMenu(Offset globalPosition) async {
    if (_disposed || !hasDisplay) return;
    final window = _window ?? WindowManager.instance.getCurrent();
    if (window == null) return;
    window.showSystemMenu(na.Point(x: globalPosition.dx, y: globalPosition.dy));
  }

  @override
  Future<void> hideToTray() async {
    if (_disposed || !hasDisplay) return;
    final window = _window ?? WindowManager.instance.getCurrent();
    if (window == null) return;
    window.hide();
    if (hideFromTaskbarWhenHidden) {
      window.isVisibleInTaskbar = false;
    }
  }

  @override
  Future<void> showAndFocus() async {
    if (_disposed || !hasDisplay) return;
    final window = _window ?? WindowManager.instance.getCurrent();
    if (window == null) return;
    if (hideFromTaskbarWhenHidden) {
      window.isVisibleInTaskbar = true;
    }
    if (window.isMinimized) {
      window.restore();
    }
    window
      ..show()
      ..focus();
    if (activateAppOnShow) {
      na.Application.instance.show();
    }
  }

  @override
  Future<void> exitApplication() async {
    _exiting = true;
    await dispose();
    final runner = quitRunner;
    if (runner != null) {
      runner(0);
      return;
    }
    if (na.Application.instance.isRunning()) {
      na.Application.instance.quit(0);
    } else {
      exit(0);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final windowListenerId = _windowListenerId;
    _windowListenerId = null;
    if (windowListenerId != null) {
      try {
        _window?.removeListener(windowListenerId);
      } on Object catch (_) {}
    }
    final appListenerId = _appListenerId;
    _appListenerId = null;
    if (appListenerId != null) {
      try {
        na.Application.instance.removeListener(appListenerId);
      } on Object catch (_) {}
    }
    _window = null;
    _isMaximized.dispose();
  }
}

/// Windows implementation of [WindowLifecycleService].
final class WindowsWindowLifecycleService extends NativeWindowLifecycleService {
  /// Creates a [WindowsWindowLifecycleService].
  new({super.quitRunner});

  @override
  bool get hasCustomTitleBar => true;

  @override
  bool get hideFromTaskbarWhenHidden => true;

  @override
  bool get activateAppOnShow => false;
}

/// Linux implementation of [WindowLifecycleService].
final class LinuxWindowLifecycleService extends NativeWindowLifecycleService {
  /// Creates a [LinuxWindowLifecycleService].
  new({super.quitRunner, this.environment});

  /// Optional environment map override for testing display detection.
  @visibleForTesting
  final Map<String, String>? environment;

  @override
  bool get hasCustomTitleBar => true;

  @override
  bool get hideFromTaskbarWhenHidden => true;

  @override
  bool get activateAppOnShow => false;

  @override
  bool get hasDisplay {
    final env = environment ?? Platform.environment;
    return (env['DISPLAY']?.isNotEmpty ?? false) ||
        (env['WAYLAND_DISPLAY']?.isNotEmpty ?? false);
  }
}

/// macOS implementation of [WindowLifecycleService].
final class MacOSWindowLifecycleService extends NativeWindowLifecycleService {
  /// Creates a [MacOSWindowLifecycleService].
  new({super.quitRunner});

  @override
  bool get hasCustomTitleBar => false;

  @override
  bool get hideFromTaskbarWhenHidden => false;

  @override
  bool get activateAppOnShow => true;
}

/// Provides the OS-appropriate [WindowLifecycleService].
///
/// Tests can override this provider with a fake [WindowLifecycleService].
@Riverpod(keepAlive: true)
WindowLifecycleService windowLifecycleService(Ref ref) {
  final service = currentWindowLifecycleService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
}
