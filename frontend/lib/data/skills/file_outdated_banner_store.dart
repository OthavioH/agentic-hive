import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/domain/skills/outdated_banner_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_outdated_banner_store.g.dart';

/// File-backed [OutdatedBannerStore] writing `skill_outdated_banner.json`
/// inside [PlatformPaths.defaultDataDir].
final class FileOutdatedBannerStore implements OutdatedBannerStore {
  /// Creates a [FileOutdatedBannerStore].
  const new(this._platformPaths);

  static const String _fileName = 'skill_outdated_banner.json';

  final PlatformPaths _platformPaths;

  File get _file => File(
    _platformPaths.context.join(_platformPaths.defaultDataDir(), _fileName),
  );

  @override
  Future<String?> loadAcknowledgedVersion() async {
    try {
      final file = _file;
      if (!file.existsSync()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        final version = decoded['acknowledgedVersion'];
        if (version is String && version.isNotEmpty) {
          return version;
        }
      }
      return null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveAcknowledgedVersion(String appVersion) async {
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, String>{'acknowledgedVersion': appVersion}),
    );
  }
}

/// Provides the local [OutdatedBannerStore].
@Riverpod(keepAlive: true)
OutdatedBannerStore outdatedBannerStore(Ref ref) =>
    FileOutdatedBannerStore(currentPlatformPaths());
