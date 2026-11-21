import 'package:agentic_hive_frontend/core/lifecycle/window_lifecycle_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
        await expectLater(
          service.initialize(onCloseRequested: () {}, onQuitRequested: () {}),
          completes,
        );
        await expectLater(service.hideToTray(), completes);
        await expectLater(service.showAndFocus(), completes);
        await expectLater(service.dispose(), completes);
      },
    );

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
