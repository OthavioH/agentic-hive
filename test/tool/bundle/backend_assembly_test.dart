import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../tool/src/bundle/backend_assembly.dart';
import '../../../tool/src/bundle/bundle_layout.dart';
import '../../../tool/src/bundle/bundle_platform.dart';

final class _AotPlatform implements BundlePlatform {
  const new();

  @override
  p.Context get context => p.context;

  @override
  String executableFileName(String name) => name;

  @override
  String get sqliteLibraryFileName => 'libsqlite3.so';

  @override
  String? aotLibraryFileName(String entryPoint) => 'libdartaot$entryPoint.so';
}

void main() {
  late Directory tempDir;
  late String bundleRoot;
  late String buildRoot;
  late BundleLayout layout;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('backend_assembly_test_');
    bundleRoot = p.join(tempDir.path, 'bundle');
    buildRoot = p.join(tempDir.path, 'build');
    Directory(bundleRoot).createSync(recursive: true);
    layout = BundleLayout(bundleRoot, platform: const _AotPlatform());
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  void writeBuild(String entry, Map<String, String> libFiles) {
    final binDir = Directory(p.join(buildRoot, entry, 'bundle', 'bin'))
      ..createSync(recursive: true);
    File(p.join(binDir.path, entry)).writeAsStringSync('stub');
    final libDir = Directory(p.join(buildRoot, entry, 'bundle', 'lib'))
      ..createSync(recursive: true);
    for (final MapEntry(:key, :value) in libFiles.entries) {
      File(p.join(libDir.path, key)).writeAsStringSync(value);
    }
  }

  group('assembleBackend', () {
    test('merges the hive_mcp AOT library into backend/lib', () {
      writeBuild('server', {
        'libdartaotserver.so': 'server-aot',
        'libsqlite3.so': 'sqlite',
      });
      writeBuild('hive_mcp', {
        'libdartaothive_mcp.so': 'mcp-aot',
        'libsqlite3.so': 'sqlite',
      });

      final problems = assembleBackend(layout: layout, buildRoot: buildRoot);

      expect(problems, isEmpty);
      final libNames = Directory(
        p.join(layout.backendDir, 'lib'),
      ).listSync().map((e) => p.basename(e.path)).toList()..sort();
      expect(libNames, [
        'libdartaothive_mcp.so',
        'libdartaotserver.so',
        'libsqlite3.so',
      ]);
      expect(File(layout.serverPath).existsSync(), isTrue);
      expect(File(layout.hiveMcpPath).existsSync(), isTrue);
      expect(layout.missingBackendFiles((f) => File(f).existsSync()), isEmpty);
    });

    test('reports a conflicting library and keeps the server copy', () {
      writeBuild('server', {
        'libdartaotserver.so': 'server-aot',
        'libsqlite3.so': 'sqlite',
      });
      writeBuild('hive_mcp', {
        'libdartaothive_mcp.so': 'mcp-aot',
        'libsqlite3.so': 'other',
      });

      final problems = assembleBackend(layout: layout, buildRoot: buildRoot);

      expect(problems, hasLength(1));
      expect(problems.single, contains('libsqlite3.so'));
      expect(problems.single, contains('differs'));
      expect(File(layout.sqliteLibraryPath).readAsStringSync(), 'sqlite');
    });

    test('replaces an old backend folder', () {
      Directory(layout.backendDir).createSync(recursive: true);
      final stale = File(p.join(layout.backendDir, 'stale.txt'))
        ..writeAsStringSync('old');
      writeBuild('server', {
        'libdartaotserver.so': 'server-aot',
        'libsqlite3.so': 'sqlite',
      });
      writeBuild('hive_mcp', {
        'libdartaothive_mcp.so': 'mcp-aot',
        'libsqlite3.so': 'sqlite',
      });

      final problems = assembleBackend(layout: layout, buildRoot: buildRoot);

      expect(problems, isEmpty);
      expect(stale.existsSync(), isFalse);
      expect(layout.missingBackendFiles((f) => File(f).existsSync()), isEmpty);
    });

    test('reports missing built files', () {
      writeBuild('server', {
        'libdartaotserver.so': 'server-aot',
        'libsqlite3.so': 'sqlite',
      });
      writeBuild('hive_mcp', {'libsqlite3.so': 'sqlite'});

      final problems = assembleBackend(layout: layout, buildRoot: buildRoot);

      expect(
        problems,
        contains('Missing built file: ${layout.aotLibraryPath('hive_mcp')}'),
      );
    });

    test('reports an unexpected folder in hive_mcp lib', () {
      writeBuild('server', {
        'libdartaotserver.so': 'server-aot',
        'libsqlite3.so': 'sqlite',
      });
      writeBuild('hive_mcp', {
        'libdartaothive_mcp.so': 'mcp-aot',
        'libsqlite3.so': 'sqlite',
      });
      Directory(p.join(buildRoot, 'hive_mcp', 'bundle', 'lib', 'sub'))
          .createSync(recursive: true);
      File(p.join(buildRoot, 'hive_mcp', 'bundle', 'lib', 'sub', 'x'))
          .writeAsStringSync('x');

      final problems = assembleBackend(layout: layout, buildRoot: buildRoot);

      expect(problems, hasLength(1));
      expect(problems.single, contains('sub'));
    });
  });
}
