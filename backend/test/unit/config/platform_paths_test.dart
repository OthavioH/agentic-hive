import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('platformPathsFor', () {
    test('returns WindowsPaths for "windows"', () {
      expect(
        platformPathsFor('windows', environment: const {}),
        isA<WindowsPaths>(),
      );
    });

    test('returns LinuxPaths for "linux"', () {
      expect(
        platformPathsFor('linux', environment: const {}),
        isA<LinuxPaths>(),
      );
    });

    test('returns MacOSPaths for "macos"', () {
      expect(
        platformPathsFor('macos', environment: const {}),
        isA<MacOSPaths>(),
      );
    });

    for (final os in ['fuchsia', 'android', 'ios', '']) {
      test('throws UnsupportedError for "$os"', () {
        expect(
          () => platformPathsFor(os, environment: const {}),
          throwsUnsupportedError,
        );
      });
    }

    test('passes the environment to the implementation', () {
      final paths = platformPathsFor(
        'macos',
        environment: const {'HOME': '/Users/ana'},
      );

      expect(
        paths.defaultDataDir(),
        '/Users/ana/Library/Application Support/AgenticHive',
      );
    });
  });

  group('WindowsPaths', () {
    test(r'puts the data folder in %LOCALAPPDATA%\AgenticHive', () {
      final paths = WindowsPaths(const {
        'LOCALAPPDATA': r'C:\Users\ana\AppData\Local',
      });

      expect(paths.defaultDataDir(), r'C:\Users\ana\AppData\Local\AgenticHive');
    });

    test('throws a StateError when LOCALAPPDATA is missing', () {
      expect(
        () => WindowsPaths(const {}).defaultDataDir(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('LOCALAPPDATA'),
          ),
        ),
      );
    });

    test('throws a StateError when LOCALAPPDATA is empty', () {
      expect(
        () => WindowsPaths(const {'LOCALAPPDATA': ''}).defaultDataDir(),
        throwsStateError,
      );
    });

    test('uses Windows path rules and a 107-byte socket limit', () {
      final paths = WindowsPaths(const {});

      expect(paths.context.style, p.Style.windows);
      expect(paths.maxSocketPathBytes, 107);
    });
  });

  group('LinuxPaths', () {
    test(r'uses an absolute $XDG_DATA_HOME', () {
      final paths = LinuxPaths(const {
        'XDG_DATA_HOME': '/xdg/data',
        'HOME': '/home/ana',
      });

      expect(paths.defaultDataDir(), '/xdg/data/agentic-hive');
    });

    test(r'does not need HOME when $XDG_DATA_HOME is absolute', () {
      final paths = LinuxPaths(const {'XDG_DATA_HOME': '/xdg/data'});

      expect(paths.defaultDataDir(), '/xdg/data/agentic-hive');
    });

    test(r'ignores a relative $XDG_DATA_HOME', () {
      final paths = LinuxPaths(const {
        'XDG_DATA_HOME': 'relative/data',
        'HOME': '/home/ana',
      });

      expect(paths.defaultDataDir(), '/home/ana/.local/share/agentic-hive');
    });

    test(r'falls back to ~/.local/share without $XDG_DATA_HOME', () {
      final paths = LinuxPaths(const {'HOME': '/home/ana'});

      expect(paths.defaultDataDir(), '/home/ana/.local/share/agentic-hive');
    });

    test(r'ignores an empty $XDG_DATA_HOME', () {
      final paths = LinuxPaths(const {'XDG_DATA_HOME': '', 'HOME': '/h'});

      expect(paths.defaultDataDir(), '/h/.local/share/agentic-hive');
    });

    test('throws a StateError when HOME is needed and missing', () {
      expect(
        () => LinuxPaths(const {}).defaultDataDir(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('HOME'),
          ),
        ),
      );
    });

    test('uses POSIX path rules and a 107-byte socket limit', () {
      final paths = LinuxPaths(const {});

      expect(paths.context.style, p.Style.posix);
      expect(paths.maxSocketPathBytes, 107);
    });
  });

  group('MacOSPaths', () {
    test('puts the data folder in ~/Library/Application Support', () {
      final paths = MacOSPaths(const {'HOME': '/Users/ana'});

      expect(
        paths.defaultDataDir(),
        '/Users/ana/Library/Application Support/AgenticHive',
      );
    });

    test('throws a StateError when HOME is missing', () {
      expect(() => MacOSPaths(const {}).defaultDataDir(), throwsStateError);
    });

    test('uses POSIX path rules and a 103-byte socket limit', () {
      final paths = MacOSPaths(const {});

      expect(paths.context.style, p.Style.posix);
      expect(paths.maxSocketPathBytes, 103);
    });
  });
}
