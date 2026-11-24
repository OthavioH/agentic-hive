import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/skills/bundled_skill.dart';

/// Reads a skill by name. One implementation per source (disk for now).
abstract interface class BundledSkillLoader {
  /// Loads the skill [name]. Never throws; returns a failure Result instead.
  Result<BundledSkill> load(String name);
}
