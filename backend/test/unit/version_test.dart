import 'dart:io';

import 'package:agentic_hive_backend/src/version.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('backendVersion equals the version in backend/pubspec.yaml', () {
    // `dart test` runs with the package root as the working directory.
    final pubspec = File(p.join(Directory.current.path, 'pubspec.yaml'));
    final yaml = loadYaml(pubspec.readAsStringSync()) as YamlMap;

    expect(yaml['name'], 'agentic_hive_backend');
    expect(backendVersion, yaml['version']);
  });
}
