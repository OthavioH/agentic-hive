import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_selection_store_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final class _TempPlatformPaths implements PlatformPaths {
  const new(this.dir);

  final String dir;

  @override
  p.Context get context => p.context;

  @override
  String defaultDataDir() => dir;

  @override
  String serverInfoPath() => context.join(dir, 'server.json');
}

void main() {
  late Directory tempDir;
  late FileWorkspaceSelectionStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ws_selection_test_');
    store = FileWorkspaceSelectionStore(_TempPlatformPaths(tempDir.path));
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('load returns null when no selection file exists', () async {
    expect(await store.load(), isNull);
  });

  test('save and load round-trip the workspace id', () async {
    await store.save('ws-42');
    expect(await store.load(), 'ws-42');
  });

  test('save(null) clears the persisted workspace id', () async {
    await store.save('ws-42');
    await store.save(null);
    expect(await store.load(), isNull);
  });

  test('load returns null when file contains malformed json', () async {
    final file = File(p.join(tempDir.path, 'current_workspace.json'));
    await file.writeAsString('{not valid');
    expect(await store.load(), isNull);
  });
}
