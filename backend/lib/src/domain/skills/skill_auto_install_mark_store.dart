import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Remembers for which harnesses the automatic skill install already ran.
abstract interface class SkillAutoInstallMarkStore {
  /// Whether the automatic install already ran for [id].
  Future<bool> isMarked(HarnessId id);

  /// Records that the automatic install ran for [id].
  Future<void> mark(HarnessId id);
}
