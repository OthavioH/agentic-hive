import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/window/get_window_chrome_use_case.dart';
import 'package:agentic_hive_frontend/domain/window/hide_window_to_tray_use_case.dart';
import 'package:agentic_hive_frontend/domain/window/minimize_window_use_case.dart';
import 'package:agentic_hive_frontend/domain/window/set_window_title_use_case.dart';
import 'package:agentic_hive_frontend/domain/window/show_window_system_menu_use_case.dart';
import 'package:agentic_hive_frontend/domain/window/start_window_drag_use_case.dart';
import 'package:agentic_hive_frontend/domain/window/toggle_maximize_window_use_case.dart';
import 'package:agentic_hive_frontend/domain/window/watch_window_maximized_use_case.dart';
import 'package:agentic_hive_frontend/domain/window/window_controls_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWindowControlsRepository implements WindowControlsRepository {
  new({bool initialMaximized = false}) : _isMaximized = initialMaximized;

  @override
  final bool hasCustomTitleBar = true;

  @override
  final bool showSystemMenuOnRelease = true;

  bool _isMaximized;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  int minimizeCount = 0;
  int toggleMaximizeCount = 0;
  int hideToTrayCount = 0;
  int startDraggingCount = 0;
  (double, double)? lastSystemMenu;
  final List<String> titles = <String>[];

  @override
  bool get isMaximized => _isMaximized;

  @override
  Stream<bool> watchIsMaximized() => _controller.stream;

  @override
  Future<Result<void>> setTitle(String title) async {
    titles.add(title);
    return const Success<void>(null);
  }

  @override
  Future<void> minimize() async {
    minimizeCount++;
  }

  @override
  Future<void> toggleMaximize() async {
    toggleMaximizeCount++;
    _isMaximized = !_isMaximized;
    _controller.add(_isMaximized);
  }

  @override
  Future<void> hideToTray() async {
    hideToTrayCount++;
  }

  @override
  Future<void> startDragging() async {
    startDraggingCount++;
  }

  @override
  Future<void> showSystemMenu({required double x, required double y}) async {
    lastSystemMenu = (x, y);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  group('Window use cases', () {
    test('GetWindowChromeUseCase returns repository chrome config', () async {
      final repo = _FakeWindowControlsRepository(initialMaximized: true);
      addTearDown(repo.dispose);

      final chrome = GetWindowChromeUseCase(repo)();
      expect(chrome.hasCustomTitleBar, isTrue);
      expect(chrome.showSystemMenuOnRelease, isTrue);
      expect(chrome.isMaximized, isTrue);
    });

    test('action use cases delegate to WindowControlsRepository', () async {
      final repo = _FakeWindowControlsRepository();
      addTearDown(repo.dispose);

      await MinimizeWindowUseCase(repo)();
      expect(repo.minimizeCount, 1);

      await ToggleMaximizeWindowUseCase(repo)();
      expect(repo.toggleMaximizeCount, 1);
      expect(repo.isMaximized, isTrue);

      await HideWindowToTrayUseCase(repo)();
      expect(repo.hideToTrayCount, 1);

      await StartWindowDragUseCase(repo)();
      expect(repo.startDraggingCount, 1);

      await ShowWindowSystemMenuUseCase(repo)(x: 120, y: 24);
      expect(repo.lastSystemMenu, (120.0, 24.0));

      final titleResult = await SetWindowTitleUseCase(repo)('Agentic Hive');
      expect(titleResult, isA<Success<void>>());
      expect(repo.titles, <String>['Agentic Hive']);
    });

    test(
      'WatchWindowMaximizedUseCase streams maximized state changes',
      () async {
        final repo = _FakeWindowControlsRepository();
        addTearDown(repo.dispose);

        final events = <bool>[];
        final sub = WatchWindowMaximizedUseCase(repo)().listen(events.add);
        addTearDown(sub.cancel);

        await ToggleMaximizeWindowUseCase(repo)();
        await ToggleMaximizeWindowUseCase(repo)();
        await Future<void>.delayed(Duration.zero);

        expect(events, <bool>[true, false]);
      },
    );
  });
}
