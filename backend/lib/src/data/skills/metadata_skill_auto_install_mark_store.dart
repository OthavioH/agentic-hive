import 'package:agentic_hive_backend/src/db/metadata_repository.dart';
import 'package:agentic_hive_backend/src/domain/skills/skill_auto_install_mark_store.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [SkillAutoInstallMarkStore] backed by `MetadataRepository`.
final class MetadataSkillAutoInstallMarkStore
    implements SkillAutoInstallMarkStore {
  /// Creates a mark store backed by `metadata`.
  new(this._metadata, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());

  /// Key prefix in `app_metadata` for per-harness auto-install marks.
  static const markKeyPrefix = 'skill_auto_install.';

  final MetadataRepository _metadata;
  final DateTime Function() _now;

  static String _keyFor(HarnessId id) => '$markKeyPrefix${id.wireName}';

  @override
  Future<bool> isMarked(HarnessId id) async =>
      await _metadata.read(_keyFor(id)) != null;

  @override
  Future<void> mark(HarnessId id) =>
      _metadata.write(_keyFor(id), _now().toUtc().toIso8601String());
}
