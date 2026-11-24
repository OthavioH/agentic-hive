import 'package:test/test.dart';

import '../../../tool/src/bundle/bundle_layout.dart';
import '../../../tool/src/bundle/bundle_platform.dart';

void main() {
  group('BundleLayout', () {
    test('windows paths', () {
      final layout = BundleLayout(
        r'C:\b',
        platform: const WindowsBundlePlatform(),
      );

      expect(layout.appExecutablePath, r'C:\b\agentic_hive.exe');
      expect(layout.serverPath, r'C:\b\backend\bin\server.exe');
      expect(layout.hiveMcpPath, r'C:\b\backend\bin\hive_mcp.exe');
      expect(layout.sqliteLibraryPath, r'C:\b\backend\lib\sqlite3.dll');
    });

    test('linux paths', () {
      final layout = BundleLayout('/b', platform: const LinuxBundlePlatform());

      expect(layout.appExecutablePath, '/b/agentic_hive');
      expect(layout.serverPath, '/b/backend/bin/server');
      expect(layout.hiveMcpPath, '/b/backend/bin/hive_mcp');
      expect(layout.sqliteLibraryPath, '/b/backend/lib/libsqlite3.so');
    });

    test('complete bundle has no missing files', () {
      final layout = BundleLayout('/b', platform: const LinuxBundlePlatform());

      expect(layout.missingFiles((_) => true), isEmpty);
    });

    test('reports only the missing SQLite library', () {
      final layout = BundleLayout('/b', platform: const LinuxBundlePlatform());

      expect(layout.missingFiles((path) => path != layout.sqliteLibraryPath), [
        layout.sqliteLibraryPath,
      ]);
    });

    test('reports every missing file in order', () {
      final layout = BundleLayout('/b', platform: const LinuxBundlePlatform());

      expect(layout.missingFiles((_) => false), layout.requiredFiles);
      expect(layout.requiredFiles, [
        layout.appExecutablePath,
        layout.serverPath,
        layout.hiveMcpPath,
        layout.sqliteLibraryPath,
        '/b/backend/lib/libdartaotserver.so',
        '/b/backend/lib/libdartaothive_mcp.so',
        ...layout.skillFilePaths,
      ]);
    });

    test('linux AOT library paths', () {
      final layout = BundleLayout('/b', platform: const LinuxBundlePlatform());

      expect(
        layout.aotLibraryPath('server'),
        '/b/backend/lib/libdartaotserver.so',
      );
      expect(
        layout.aotLibraryPath('hive_mcp'),
        '/b/backend/lib/libdartaothive_mcp.so',
      );
    });

    test('windows has no AOT library paths', () {
      final layout = BundleLayout(
        r'C:\b',
        platform: const WindowsBundlePlatform(),
      );

      expect(layout.aotLibraryPath('server'), isNull);
      expect(layout.requiredFiles, [
        layout.appExecutablePath,
        layout.serverPath,
        layout.hiveMcpPath,
        layout.sqliteLibraryPath,
        ...layout.skillFilePaths,
      ]);
    });

    test('backendFiles excludes the app executable', () {
      final layout = BundleLayout('/b', platform: const LinuxBundlePlatform());

      expect(
        layout.backendFiles,
        layout.requiredFiles.skip(1).take(layout.backendFiles.length).toList(),
      );
      expect(
        layout.missingBackendFiles(
          (p) => p != layout.aotLibraryPath('hive_mcp'),
        ),
        ['/b/backend/lib/libdartaothive_mcp.so'],
      );
    });

    test('reports a missing bundled skill file', () {
      final layout = BundleLayout('/b', platform: const LinuxBundlePlatform());

      expect(layout.missingFiles((p) => p != layout.skillFilePaths.single), [
        layout.skillFilePaths.single,
      ]);
    });

    test('reports a missing hive_mcp AOT library', () {
      final layout = BundleLayout('/b', platform: const LinuxBundlePlatform());

      expect(
        layout.missingFiles((p) => p != layout.aotLibraryPath('hive_mcp')),
        ['/b/backend/lib/libdartaothive_mcp.so'],
      );
    });
  });
}
