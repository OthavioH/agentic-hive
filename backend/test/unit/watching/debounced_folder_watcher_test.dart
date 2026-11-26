import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/data/watching/debounced_folder_watcher.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  const debounce = Duration(milliseconds: 30);
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('debounced_folder_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
  });

  test(
    'emits created, updated, and deleted in order for a matching file',
    () async {
      final events = <(String path, FolderChangeKind kind)>[];
      final watcher = DebouncedFolderWatcher(
        directory: tempDir.path,
        extensions: const {'.md'},
        debounce: debounce,
        onChange: (path, kind) => events.add((path, kind)),
        onError: (error, stackTrace) =>
            fail('Unexpected watcher error: $error'),
      );
      addTearDown(watcher.close);
      await watcher.ready;

      final file = File(p.join(tempDir.path, 'a.md'));
      await file.writeAsString('initial');
      await _waitFor(() => events.length == 1);
      expect(events[0], (file.path, FolderChangeKind.created));

      await file.writeAsString('edited');
      await _waitFor(() => events.length == 2);
      expect(events[1], (file.path, FolderChangeKind.updated));

      await file.delete();
      await _waitFor(() => events.length == 3);
      expect(events[2], (file.path, FolderChangeKind.deleted));
    },
  );

  test('ignores other extensions and subfolders while matching extensions '
      'case-insensitively', () async {
    final events = <(String path, FolderChangeKind kind)>[];
    final watcher = DebouncedFolderWatcher(
      directory: tempDir.path,
      extensions: const {'.md'},
      debounce: debounce,
      onChange: (path, kind) => events.add((path, kind)),
      onError: (error, stackTrace) => fail('Unexpected watcher error: $error'),
    );
    addTearDown(watcher.close);
    await watcher.ready;

    await File(p.join(tempDir.path, 'notes.txt')).writeAsString('ignore');
    final sub = Directory(p.join(tempDir.path, 'sub'));
    await sub.create();
    await File(p.join(sub.path, 'x.md')).writeAsString('ignore nested');

    final accepted = File(p.join(tempDir.path, 'B.MD'));
    await accepted.writeAsString('accept uppercase');
    await _waitFor(() => events.isNotEmpty);

    expect(events, [(accepted.path, FolderChangeKind.created)]);
  });

  test(
    'folds rapid create then write into a single created emission',
    () async {
      final events = <(String path, FolderChangeKind kind)>[];
      final watcher = DebouncedFolderWatcher(
        directory: tempDir.path,
        extensions: const {'.md'},
        debounce: debounce,
        onChange: (path, kind) => events.add((path, kind)),
        onError: (error, stackTrace) =>
            fail('Unexpected watcher error: $error'),
      );
      addTearDown(watcher.close);
      await watcher.ready;

      final file = File(p.join(tempDir.path, 'c.md'))
        ..writeAsStringSync('first')
        ..writeAsStringSync('second');

      await _waitFor(() => events.isNotEmpty);
      await Future<void>.delayed(debounce * 4);

      expect(events, [(file.path, FolderChangeKind.created)]);
    },
  );

  test(
    'collapses several rapid writes to an existing file into one updated',
    () async {
      final file = File(p.join(tempDir.path, 'existing.md'));
      await file.writeAsString('v0');

      final events = <(String path, FolderChangeKind kind)>[];
      final watcher = DebouncedFolderWatcher(
        directory: tempDir.path,
        extensions: const {'.md'},
        debounce: debounce,
        onChange: (path, kind) => events.add((path, kind)),
        onError: (error, stackTrace) =>
            fail('Unexpected watcher error: $error'),
      );
      addTearDown(watcher.close);
      await watcher.ready;

      file
        ..writeAsStringSync('v1')
        ..writeAsStringSync('v2')
        ..writeAsStringSync('v3');

      await _waitFor(() => events.isNotEmpty);
      await Future<void>.delayed(debounce * 4);

      expect(events, [(file.path, FolderChangeKind.updated)]);
    },
  );

  test('close right after a write prevents any emission', () async {
    final events = <(String path, FolderChangeKind kind)>[];
    final watcher = DebouncedFolderWatcher(
      directory: tempDir.path,
      extensions: const {'.md'},
      debounce: debounce,
      onChange: (path, kind) => events.add((path, kind)),
      onError: (error, stackTrace) => fail('Unexpected watcher error: $error'),
    );
    await watcher.ready;

    await File(p.join(tempDir.path, 'd.md')).writeAsString('before close');
    await watcher.close();

    await Future<void>.delayed(debounce * 4);
    expect(events, isEmpty);
  });
}
