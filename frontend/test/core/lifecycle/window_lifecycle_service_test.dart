import 'package:agentic_hive_frontend/core/lifecycle/window_lifecycle_service.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

final class _FakeWindow implements Window {
  TitleBarStyle? appliedTitleBarStyle;
  bool? controlButtonsVisible;
  String? appliedTitle;
  int minimizeCount = 0;

  @override
  bool isMaximized = false;

  @override
  set titleBarStyle(TitleBarStyle value) {
    appliedTitleBarStyle = value;
  }

  @override
  set isWindowControlButtonsVisible(bool value) {
    controlButtonsVisible = value;
  }

  @override
  set title(String value) {
    appliedTitle = value;
  }

  @override
  void minimize() {
    minimizeCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('WindowLifecycleService', () {
    test(
      'dispose completes without throwing when uninitialized across platforms',
      () async {
        final services = <WindowLifecycleService>[
          WindowsWindowLifecycleService(),
          LinuxWindowLifecycleService(environment: const <String, String>{}),
          MacOSWindowLifecycleService(),
        ];

        for (final service in services) {
          await expectLater(service.dispose(), completes);
          await expectLater(service.dispose(), completes);
        }
      },
    );

    test(
      'LinuxWindowLifecycleService skips native hooks when no display is set',
      () async {
        final service = LinuxWindowLifecycleService(
          environment: const <String, String>{},
        );

        expect(service.hasDisplay, isFalse);
        service.configureTitleBar();
        await expectLater(
          service.initialize(onCloseRequested: () {}, onQuitRequested: () {}),
          completes,
        );
        expect(await service.setTitle('Agentic Hive'), isA<Success<void>>());
        await expectLater(service.minimize(), completes);
        await expectLater(service.toggleMaximize(), completes);
        await expectLater(service.startDragging(), completes);
        await expectLater(service.showSystemMenu(Offset.zero), completes);
        await expectLater(service.hideToTray(), completes);
        await expectLater(service.showAndFocus(), completes);
        await expectLater(service.dispose(), completes);
      },
    );

    test('reports hasCustomTitleBar and showSystemMenuOnRelease per OS', () {
      final windows = WindowsWindowLifecycleService();
      final linux = LinuxWindowLifecycleService(
        environment: const <String, String>{},
      );
      final macos = MacOSWindowLifecycleService();

      expect(windows.hasCustomTitleBar, isTrue);
      expect(windows.showSystemMenuOnRelease, isTrue);

      expect(linux.hasCustomTitleBar, isTrue);
      expect(linux.showSystemMenuOnRelease, isFalse);

      expect(macos.hasCustomTitleBar, isFalse);
      expect(macos.showSystemMenuOnRelease, isFalse);
    });

    test('configureTitleBar hides title bar on Windows and Linux', () {
      final winWindow = _FakeWindow();
      WindowsWindowLifecycleService(currentWindow: () => winWindow)
          .configureTitleBar();
      expect(winWindow.appliedTitleBarStyle, TitleBarStyle.hidden);
      expect(winWindow.controlButtonsVisible, isNull);

      final linuxWindow = _FakeWindow();
      LinuxWindowLifecycleService(
        environment: const <String, String>{'DISPLAY': ':0'},
        currentWindow: () => linuxWindow,
      ).configureTitleBar();
      expect(linuxWindow.appliedTitleBarStyle, TitleBarStyle.hidden);
      expect(linuxWindow.controlButtonsVisible, isNull);
    });

    test(
      'MacOSWindowLifecycleService hides title while keeping control buttons',
      () {
        final macWindow = _FakeWindow();
        MacOSWindowLifecycleService(currentWindow: () => macWindow)
            .configureTitleBar();

        expect(macWindow.appliedTitleBarStyle, TitleBarStyle.hidden);
        expect(macWindow.controlButtonsVisible, isTrue);
      },
    );

    test(
      'setTitle updates window title and returns FailureResult on error',
      () async {
        final fakeWindow = _FakeWindow();
        final service = WindowsWindowLifecycleService(
          currentWindow: () => fakeWindow,
        );

        final ok = await service.setTitle('Agentic Hive');
        expect(ok, isA<Success<void>>());
        expect(fakeWindow.appliedTitle, 'Agentic Hive');

        final failingService = WindowsWindowLifecycleService(
          currentWindow: () => throw StateError('no native library'),
        );
        final failed = await failingService.setTitle('Agentic Hive');
        expect(failed, isA<FailureResult<void>>());
        expect(failed.failureOrNull, isA<UnexpectedFailure>());
      },
    );

    test('guard helper skips window calls after dispose', () async {
      final fakeWindow = _FakeWindow();
      final service = WindowsWindowLifecycleService(
        currentWindow: () => fakeWindow,
      );

      await service.minimize();
      expect(fakeWindow.minimizeCount, 1);

      await service.dispose();
      await service.minimize();
      expect(fakeWindow.minimizeCount, 1);
    });

    test('isMaximized defaults to false when uninitialized', () {
      final services = <WindowLifecycleService>[
        WindowsWindowLifecycleService(),
        LinuxWindowLifecycleService(environment: const <String, String>{}),
        MacOSWindowLifecycleService(),
      ];

      for (final service in services) {
        expect(service.isMaximized.value, isFalse);
      }
    });

    test(
      'LinuxWindowLifecycleService detects X11 and Wayland display variables',
      () {
        expect(
          LinuxWindowLifecycleService(
            environment: const <String, String>{'DISPLAY': ':0'},
          ).hasDisplay,
          isTrue,
        );
        expect(
          LinuxWindowLifecycleService(
            environment: const <String, String>{'WAYLAND_DISPLAY': 'wayland-0'},
          ).hasDisplay,
          isTrue,
        );
        expect(
          LinuxWindowLifecycleService(
            environment: const <String, String>{
              'DISPLAY': '',
              'WAYLAND_DISPLAY': '',
            },
          ).hasDisplay,
          isFalse,
        );
      },
    );
  });
}
