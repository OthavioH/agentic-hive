import 'dart:io';

import 'package:agentic_hive_backend/src/util/canonical_folder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('canonical_folder_');
    addTearDown(() => root.delete(recursive: true));
  });

  test('an existing folder is normalized and resolved', () {
    final folder = Directory(p.join(root.path, 'a'))..createSync();
    final messy = p.join(folder.path, '..', 'a', '.');

    expect(
      canonicalFolder(messy, p.context),
      canonicalFolder(folder.path, p.context),
    );
  });

  test('a missing folder falls back to path canonicalization', () {
    final missing = p.join(root.path, 'x', '..', 'gone');

    expect(
      canonicalFolder(missing, p.context),
      p.canonicalize(p.join(root.path, 'gone')),
    );
  });

  test('a symlinked folder canonicalizes to its target', () {
    final target = Directory(p.join(root.path, 'target'))..createSync();
    final link = Link(p.join(root.path, 'link'));
    try {
      link.createSync(target.path);
    } on FileSystemException {
      markTestSkipped('Symlinks are not available on this machine.');
      return;
    }

    expect(
      canonicalFolder(link.path, p.context),
      canonicalFolder(target.path, p.context),
    );
  });
}
