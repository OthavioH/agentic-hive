import 'dart:async';
import 'dart:ui' show Offset;

import 'package:agentic_hive_frontend/core/lifecycle/window_lifecycle_service.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';

/// [WindowControlsRepository] backed by the per-OS [WindowLifecycleService].
final class WindowControlsRepositoryImpl implements WindowControlsRepository {
  /// Creates a [WindowControlsRepositoryImpl].
  new(this._service) {
    _service.isMaximized.addListener(_onMaximizedChanged);
  }

  final WindowLifecycleService _service;
  final StreamController<bool> _maximizedController =
      StreamController<bool>.broadcast(sync: true);
  late final Stream<bool> _maximizedStream = _maximizedController.stream;
  bool _disposed = false;

  void _onMaximizedChanged() {
    if (!_disposed && !_maximizedController.isClosed) {
      _maximizedController.add(_service.isMaximized.value);
    }
  }

  @override
  bool get hasCustomTitleBar => _service.hasCustomTitleBar;

  @override
  bool get showSystemMenuOnRelease => _service.showSystemMenuOnRelease;

  @override
  bool get isMaximized => _service.isMaximized.value;

  @override
  Stream<bool> watchIsMaximized() => _maximizedStream;

  @override
  Future<Result<void>> setTitle(String title) => _service.setTitle(title);

  @override
  Future<void> minimize() => _service.minimize();

  @override
  Future<void> toggleMaximize() => _service.toggleMaximize();

  @override
  Future<void> hideToTray() => _service.hideToTray();

  @override
  Future<void> startDragging() => _service.startDragging();

  @override
  Future<void> showSystemMenu({required double x, required double y}) =>
      _service.showSystemMenu(Offset(x, y));

  /// Detaches listeners and closes the maximized-state stream.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _service.isMaximized.removeListener(_onMaximizedChanged);
    await _maximizedController.close();
  }
}
