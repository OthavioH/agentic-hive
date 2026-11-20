import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformPaths', () {
    test('windows uses LOCALAPPDATA/AgenticHive/server.json', () {
      final paths = platformPathsFor(
        'windows',
        environment: const {'LOCALAPPDATA': r'C:\Users\Ada\AppData\Local'},
      );
      expect(paths.defaultDataDir(), r'C:\Users\Ada\AppData\Local\AgenticHive');
      expect(
        paths.serverInfoPath(),
        r'C:\Users\Ada\AppData\Local\AgenticHive\server.json',
      );
    });

    test('linux uses XDG_DATA_HOME when absolute, else ~/.local/share', () {
      final withXdg = platformPathsFor(
        'linux',
        environment: const {'XDG_DATA_HOME': '/var/data', 'HOME': '/home/ada'},
      );
      expect(withXdg.defaultDataDir(), '/var/data/agentic-hive');
      expect(withXdg.serverInfoPath(), '/var/data/agentic-hive/server.json');

      final fallback = platformPathsFor(
        'linux',
        environment: const {'HOME': '/home/ada'},
      );
      expect(fallback.defaultDataDir(), '/home/ada/.local/share/agentic-hive');
    });

    test('macos uses ~/Library/Application Support/AgenticHive', () {
      final paths = platformPathsFor(
        'macos',
        environment: const {'HOME': '/Users/ada'},
      );
      expect(
        paths.defaultDataDir(),
        '/Users/ada/Library/Application Support/AgenticHive',
      );
      expect(
        paths.serverInfoPath(),
        '/Users/ada/Library/Application Support/AgenticHive/server.json',
      );
    });

    test('unsupported OS throws UnsupportedError', () {
      expect(
        () => platformPathsFor('fuchsia', environment: const {}),
        throwsUnsupportedError,
      );
    });
  });
}
