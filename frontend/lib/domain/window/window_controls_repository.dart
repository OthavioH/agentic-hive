import 'package:agentic_hive_frontend/core/result/result.dart';

/// Snapshot of static and initial window chrome capabilities for the UI.
typedef WindowChromeConfig = ({
  bool hasCustomTitleBar,
  bool showSystemMenuOnRelease,
  bool isMaximized,
});

/// Pure-Dart domain interface for desktop window chrome and controls.
abstract interface class WindowControlsRepository {
  /// Whether this platform renders the app's custom title bar.
  bool get hasCustomTitleBar;

  /// Whether the custom title bar's system menu opens on secondary pointer
  /// release (`true`) rather than press (`false`).
  bool get showSystemMenuOnRelease;

  /// Whether the main window is currently maximized.
  bool get isMaximized;

  /// Emits updates whenever [isMaximized] changes.
  Stream<bool> watchIsMaximized();

  /// Updates the OS window title.
  Future<Result<void>> setTitle(String title);

  /// Minimizes the main window.
  Future<void> minimize();

  /// Toggles between maximized and restored states.
  Future<void> toggleMaximize();

  /// Hides the main window to the system tray without exiting.
  Future<void> hideToTray();

  /// Starts an interactive window drag from the custom title bar.
  Future<void> startDragging();

  /// Opens the native window system menu at ([x], [y]) in global coordinates.
  Future<void> showSystemMenu({required double x, required double y});
}
