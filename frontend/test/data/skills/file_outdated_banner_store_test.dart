import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/data/skills/file_outdated_banner_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final class _TempPlatformPaths implements PlatformPaths {
  const new(this._dir);

  final String _dir;

  @override
  p.Context get context => p.context;

  @override
  String defaultDataDir() => _dir;

  @override
  String serverInfoPath() => context.join(_dir, 'server.json');
}

void main() {
  group('FileOutdatedBannerStore', () {
    test('returns null when file is missing', () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_outdated_');
      addTearDown(() => tempDir.delete(recursive: true));

      final store = FileOutdatedBannerStore(_TempPlatformPaths(tempDir.path));
      expect(await store.loadAcknowledgedVersion(), isNull);
    });

    test('save creates parent folder and round-trips version', () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_outdated_');
      addTearDown(() => tempDir.delete(recursive: true));

      final nestedDir = p.join(tempDir.path, 'nested', 'app_data');
      final store = FileOutdatedBannerStore(_TempPlatformPaths(nestedDir));

      await store.saveAcknowledgedVersion('1.4.0');
      expect(await store.loadAcknowledgedVersion(), '1.4.0');
    });

    test('returns null when JSON is malformed', () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_outdated_');
      addTearDown(() => tempDir.delete(recursive: true));

      final file = File(p.join(tempDir.path, 'skill_outdated_banner.json'));
      await file.writeAsString('{not valid json');

      final store = FileOutdatedBannerStore(_TempPlatformPaths(tempDir.path));
      expect(await store.loadAcknowledgedVersion(), isNull);
    });
  });
}
