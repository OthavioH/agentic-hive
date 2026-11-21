import 'package:agentic_hive_frontend/core/lifecycle/tray_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrayService', () {
    test(
      'dispose completes without throwing when uninitialized across platforms',
      () async {
        final services = <TrayService>[
          WindowsTrayService(),
          LinuxTrayService(environment: const <String, String>{}),
          MacOSTrayService(),
        ];

        for (final service in services) {
          await expectLater(service.dispose(), completes);
          await expectLater(service.dispose(), completes);
        }
      },
    );

    test(
      'LinuxTrayService skips native hooks when no display is set',
      () async {
        final service = LinuxTrayService(environment: const <String, String>{});

        expect(service.hasDisplay, isFalse);
        await expectLater(
          service.initialize(onTrayClick: () {}, onAction: (_) {}),
          completes,
        );
        await expectLater(
          service.updateMenu(
            labels: const TrayMenuLabels(
              tooltip: 'Agentic Hive',
              statusHeader: 'Connected',
              openApp: 'Open',
              quit: 'Quit',
              stopBackendAndQuit: 'Stop Backend & Quit',
            ),
            canStopBackend: true,
          ),
          completes,
        );
        await expectLater(service.dispose(), completes);
      },
    );

    test('LinuxTrayService detects X11 and Wayland display variables', () {
      expect(
        LinuxTrayService(environment: const <String, String>{'DISPLAY': ':0'})
            .hasDisplay,
        isTrue,
      );
      expect(
        LinuxTrayService(
          environment: const <String, String>{'WAYLAND_DISPLAY': 'wayland-0'},
        ).hasDisplay,
        isTrue,
      );
      expect(
        LinuxTrayService(
          environment: const <String, String>{
            'DISPLAY': '',
            'WAYLAND_DISPLAY': '',
          },
        ).hasDisplay,
        isFalse,
      );
    });
  });
}
