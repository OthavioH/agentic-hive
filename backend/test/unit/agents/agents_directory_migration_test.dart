import 'dart:io';

import 'package:agentic_hive_backend/src/data/agents/agents_directory_migration.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String legacy;
  late String target;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agents_migration_test_');
    legacy = p.join(tempDir.path, 'AgenticHive', 'agents');
    target = p.join(tempDir.path, 'home', '.agents', 'agents');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  void write(String dir, String name, String content) {
    File(p.join(dir, name))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  String read(String dir, String name) =>
      File(p.join(dir, name)).readAsStringSync();

  AgentsDirectoryMigration migration() =>
      AgentsDirectoryMigration(legacyDir: legacy, targetDir: target);

  test('copies files into a missing target and keeps the source', () async {
    write(legacy, 'reviewer.md', 'A');
    write(legacy, 'writer.md', 'B');

    final report = await migration().run();

    expect(report.copied, unorderedEquals(['reviewer.md', 'writer.md']));
    expect(report.conflicts, isEmpty);
    expect(read(target, 'reviewer.md'), 'A');
    expect(read(target, 'writer.md'), 'B');
    expect(read(legacy, 'reviewer.md'), 'A');
  });

  test('never overwrites a different file and reports the conflict', () async {
    write(legacy, 'reviewer.md', 'legacy');
    write(target, 'reviewer.md', 'mine');
    write(legacy, 'writer.md', 'B');

    final report = await migration().run();

    expect(report.copied, ['writer.md']);
    expect(report.conflicts, ['reviewer.md']);
    expect(read(target, 'reviewer.md'), 'mine');
  });

  test('is idempotent', () async {
    write(legacy, 'reviewer.md', 'legacy');
    write(target, 'reviewer.md', 'mine');
    write(legacy, 'writer.md', 'B');

    await migration().run();
    final second = await migration().run();

    expect(second.copied, isEmpty);
    expect(second.conflicts, ['reviewer.md']);
    expect(read(target, 'writer.md'), 'B');
    expect(read(target, 'reviewer.md'), 'mine');
  });

  test('an identical file is neither copied nor a conflict', () async {
    write(legacy, 'reviewer.md', 'same');
    write(target, 'reviewer.md', 'same');

    final report = await migration().run();

    expect(report.copied, isEmpty);
    expect(report.conflicts, isEmpty);
  });

  test('does nothing when the legacy folder is missing', () async {
    final report = await migration().run();

    expect(report.copied, isEmpty);
    expect(report.conflicts, isEmpty);
    expect(Directory(target).existsSync(), isFalse);
  });

  test('does nothing when legacy and target are the same folder', () async {
    write(legacy, 'reviewer.md', 'A');

    final report = await AgentsDirectoryMigration(
      legacyDir: legacy,
      targetDir: legacy,
    ).run();

    expect(report.copied, isEmpty);
    expect(report.conflicts, isEmpty);
  });
}
