import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_frontend/domain/skills/outdated_banner_store.dart';

/// In-memory [OutdatedBannerStore] fake for controller and banner tests.
final class MemoryOutdatedBannerStore implements OutdatedBannerStore {
  new({this.acknowledgedVersion, this.throwOnSave = false});

  String? acknowledgedVersion;
  Completer<String?>? pendingLoad;
  bool throwOnSave;
  final List<String> savedVersions = <String>[];

  @override
  Future<String?> loadAcknowledgedVersion() =>
      pendingLoad?.future ?? Future<String?>.value(acknowledgedVersion);

  @override
  Future<void> saveAcknowledgedVersion(String appVersion) async {
    if (throwOnSave) {
      throw const FileSystemException('disk full');
    }
    savedVersions.add(appVersion);
    acknowledgedVersion = appVersion;
  }
}
