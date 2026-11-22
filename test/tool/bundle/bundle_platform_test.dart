import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../tool/src/bundle/bundle_platform.dart';

void main() {
  group('bundlePlatformFor', () {
    test('windows names executables with .exe and uses sqlite3.dll', () {
      final platform = bundlePlatformFor('windows');

      expect(platform.executableFileName('server'), 'server.exe');
      expect(platform.sqliteLibraryFileName, 'sqlite3.dll');
      expect(platform.context.style, p.Style.windows);
    });

    test(
      'linux names executables without extension and uses libsqlite3.so',
      () {
        final platform = bundlePlatformFor('linux');

        expect(platform.executableFileName('server'), 'server');
        expect(platform.sqliteLibraryFileName, 'libsqlite3.so');
        expect(platform.context.style, p.Style.posix);
      },
    );

    test('macos uses libsqlite3.dylib', () {
      final platform = bundlePlatformFor('macos');

      expect(platform.executableFileName('server'), 'server');
      expect(platform.sqliteLibraryFileName, 'libsqlite3.dylib');
      expect(platform.context.style, p.Style.posix);
    });

    test('unknown operating system throws UnsupportedError', () {
      expect(() => bundlePlatformFor('fuchsia'), throwsUnsupportedError);
    });
  });
}
