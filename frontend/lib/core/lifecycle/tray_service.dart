import 'dart:async';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tray_manager/tray_manager.dart';

part 'tray_service.g.dart';

/// Actions triggered by clicking a system tray menu item.
enum TrayAction {
  /// Restore and focus the main application window.
  openWindow,

  /// Quit the UI (and shut down the backend when idle).
  quit,

  /// Explicitly stop the backend and quit the UI.
  stopBackendAndQuit,
}

/// Localized labels rendered in the system tray context menu.
@immutable
final class TrayMenuLabels {
  /// Creates localized tray menu labels.
  const new({
    required this.tooltip,
    required this.statusHeader,
    required this.openApp,
    required this.quit,
    required this.stopBackendAndQuit,
  });

  /// Tooltip shown when hovering over the tray icon.
  final String tooltip;

  /// Disabled header item showing the current backend connection state.
  final String statusHeader;

  /// Menu item label that restores and focuses the window.
  final String openApp;

  /// Menu item label that quits the UI and stops an idle backend.
  final String quit;

  /// Menu item label that stops the backend and quits.
  final String stopBackendAndQuit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrayMenuLabels &&
          other.tooltip == tooltip &&
          other.statusHeader == statusHeader &&
          other.openApp == openApp &&
          other.quit == quit &&
          other.stopBackendAndQuit == stopBackendAndQuit;

  @override
  int get hashCode =>
      Object.hash(tooltip, statusHeader, openApp, quit, stopBackendAndQuit);
}

/// OS-abstracted system tray service (ADR 0012).
abstract interface class TrayService {
  /// Creates the tray icon and registers click/menu action callbacks.
  Future<void> initialize({
    required VoidCallback onTrayClick,
    required void Function(TrayAction action) onAction,
  });

  /// Rebuilds the tray menu with [labels] and backend reachability state.
  Future<void> updateMenu({
    required TrayMenuLabels labels,
    required bool canStopBackend,
  });

  /// Releases native tray icon and menu resources.
  Future<void> dispose();
}

/// Creates the [TrayService] for [operatingSystem].
TrayService trayServiceFor(String operatingSystem) => switch (operatingSystem) {
  'windows' => WindowsTrayService(),
  'linux' => LinuxTrayService(),
  'macos' => MacOSTrayService(),
  _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
};

/// The [TrayService] of the running platform.
TrayService currentTrayService() => trayServiceFor(Platform.operatingSystem);

/// Shared `tray_manager` implementation of [TrayService] parameterized by
/// OS-specific icon asset and template behavior.
abstract base class NativeTrayService implements TrayService {
  TrayIcon? _trayIcon;
  ListenerId? _trayListenerId;
  Menu? _currentMenu;
  final List<MenuItem> _currentItems = <MenuItem>[];
  void Function(TrayAction action)? _onAction;
  bool _disposed = false;

  /// Asset key from [HiveTrayAssets] for this OS.
  String get iconAsset;

  /// Whether the icon should be marked as a macOS template image.
  bool get isTemplateIcon;

  @override
  Future<void> initialize({
    required VoidCallback onTrayClick,
    required void Function(TrayAction action) onAction,
  }) async {
    if (_disposed) return;
    _onAction = onAction;

    final trayIcon = TrayIcon.create();
    if (trayIcon == null) return;
    _trayIcon = trayIcon;

    final image = ImageAsset.fromAsset(iconAsset);
    if (image != null) {
      trayIcon.icon = image;
    }
    trayIcon
      ..isIconTemplate = isTemplateIcon
      ..setContextMenuTrigger(ContextMenuTrigger.rightClicked);

    _trayListenerId = trayIcon.addListener((event) {
      if (event is TrayIconClickedEvent ||
          event is TrayIconDoubleClickedEvent) {
        onTrayClick();
      }
    });

    trayIcon.setVisible(true);
  }

  @override
  Future<void> updateMenu({
    required TrayMenuLabels labels,
    required bool canStopBackend,
  }) async {
    final trayIcon = _trayIcon;
    if (_disposed || trayIcon == null) return;

    trayIcon.setTooltip(labels.tooltip);

    final menu = Menu.create();
    if (menu == null) return;

    final newItems = <MenuItem>[];

    final statusItem = MenuItem.createWithLabelAndType(
      labels.statusHeader,
      MenuItemType.normal,
    );
    if (statusItem != null) {
      statusItem.isEnabled = false;
      menu.addItem(statusItem);
      newItems.add(statusItem);
    }

    menu.addSeparator();

    final openItem = MenuItem.createWithLabelAndType(
      labels.openApp,
      MenuItemType.normal,
    );
    if (openItem != null) {
      openItem.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _onAction?.call(TrayAction.openWindow);
        }
      });
      menu.addItem(openItem);
      newItems.add(openItem);
    }

    menu.addSeparator();

    final quitItem = MenuItem.createWithLabelAndType(
      labels.quit,
      MenuItemType.normal,
    );
    if (quitItem != null) {
      quitItem.addListener((event) {
        if (event is MenuItemClickedEvent) {
          _onAction?.call(TrayAction.quit);
        }
      });
      menu.addItem(quitItem);
      newItems.add(quitItem);
    }

    final stopItem = MenuItem.createWithLabelAndType(
      labels.stopBackendAndQuit,
      MenuItemType.normal,
    );
    if (stopItem != null) {
      stopItem
        ..isEnabled = canStopBackend
        ..addListener((event) {
          if (event is MenuItemClickedEvent) {
            _onAction?.call(TrayAction.stopBackendAndQuit);
          }
        });
      menu.addItem(stopItem);
      newItems.add(stopItem);
    }

    trayIcon.setContextMenu(menu);

    _disposeMenuResources();
    _currentMenu = menu;
    _currentItems.addAll(newItems);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _onAction = null;

    final trayIcon = _trayIcon;
    _trayIcon = null;
    final listenerId = _trayListenerId;
    _trayListenerId = null;

    if (trayIcon != null) {
      if (listenerId != null) {
        trayIcon.removeListener(listenerId);
      }
      trayIcon
        ..setContextMenu(null)
        ..setVisible(false)
        ..dispose();
    }
    _disposeMenuResources();
  }

  void _disposeMenuResources() {
    for (final item in _currentItems) {
      item.dispose();
    }
    _currentItems.clear();
    _currentMenu?.dispose();
    _currentMenu = null;
  }
}

/// Windows implementation of [TrayService] using [HiveTrayAssets.windows].
final class WindowsTrayService extends NativeTrayService {
  @override
  String get iconAsset => HiveTrayAssets.windows;

  @override
  bool get isTemplateIcon => false;
}

/// Linux implementation of [TrayService] using [HiveTrayAssets.linux].
final class LinuxTrayService extends NativeTrayService {
  @override
  String get iconAsset => HiveTrayAssets.linux;

  @override
  bool get isTemplateIcon => false;
}

/// macOS implementation of [TrayService] using [HiveTrayAssets.macosTemplate].
final class MacOSTrayService extends NativeTrayService {
  @override
  String get iconAsset => HiveTrayAssets.macosTemplate;

  @override
  bool get isTemplateIcon => true;
}

/// Provides the OS-appropriate [TrayService].
///
/// Tests can override this provider with a fake [TrayService].
@Riverpod(keepAlive: true)
TrayService trayService(Ref ref) {
  final service = currentTrayService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
}
