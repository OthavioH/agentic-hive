import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../tool/src/version_bump.dart';

void main() {
  group('parseSemver', () {
    test('accepts X.Y.Z and vX.Y.Z', () {
      expect(parseSemver('0.4.0'), '0.4.0');
      expect(parseSemver('v1.2.3'), '1.2.3');
      expect(parseSemver(' 0.10.2 '), '0.10.2');
    });

    test('rejects invalid formats', () {
      expect(() => parseSemver('0.4'), throwsFormatException);
      expect(() => parseSemver('0.4.0-alpha'), throwsFormatException);
      expect(() => parseSemver('abc'), throwsFormatException);
    });
  });

  group('updatePubspecVersion', () {
    test('updates version without touching dependencies', () {
      const input = '''
name: agentic_hive_backend
description: Local server.
version: 0.3.1
publish_to: none

dependencies:
  shelf: ^1.4.0
''';
      final updated = updatePubspecVersion(input, '0.4.0');
      expect(updated, contains('version: 0.4.0'));
      expect(updated, contains('shelf: ^1.4.0'));
    });

    test('throws when version field is missing', () {
      expect(
        () => updatePubspecVersion('name: pkg\n', '0.4.0'),
        throwsFormatException,
      );
    });
  });

  group('updateBackendVersionDart', () {
    test('updates backendVersion constant', () {
      const input = "const backendVersion = '0.3.1';\n";
      expect(
        updateBackendVersionDart(input, '0.4.0'),
        "const backendVersion = '0.4.0';\n",
      );
    });

    test('throws when backendVersion is missing', () {
      expect(
        () => updateBackendVersionDart('const other = 1;\n', '0.4.0'),
        throwsFormatException,
      );
    });
  });

  group('bumpVersionInDirectory', () {
    test('updates all four version files', () {
      final dir = Directory.systemTemp.createTempSync('hive_bump_test_');
      addTearDown(() => dir.deleteSync(recursive: true));

      for (final pkg in const <String>['shared', 'backend', 'frontend']) {
        File(p.join(dir.path, pkg, 'pubspec.yaml'))
          ..createSync(recursive: true)
          ..writeAsStringSync('name: $pkg\nversion: 0.3.1\n');
      }
      final versionDart =
          File(p.join(dir.path, 'backend', 'lib', 'src', 'version.dart'))
            ..createSync(recursive: true)
            ..writeAsStringSync("const backendVersion = '0.3.1';\n");

      bumpVersionInDirectory(dir.path, 'v0.4.0');

      for (final pkg in const <String>['shared', 'backend', 'frontend']) {
        expect(
          File(p.join(dir.path, pkg, 'pubspec.yaml')).readAsStringSync(),
          'name: $pkg\nversion: 0.4.0\n',
        );
      }
      expect(
        versionDart.readAsStringSync(),
        "const backendVersion = '0.4.0';\n",
      );
    });
  });
}
