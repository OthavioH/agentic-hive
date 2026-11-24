import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill_loader.dart';

/// [BundledSkillLoader] that resolves the bundled skills root lazily on each
/// [load] call so a missing skills folder returns a failure [Result].
final class LocatedBundledSkillLoader implements BundledSkillLoader {
  /// Creates a loader using [locator] to resolve the skills root directory.
  new({BundledSkillsLocator? locator})
    : locator = locator ?? BundledSkillsLocator();

  /// Locator used to find the bundled skills directory.
  final BundledSkillsLocator locator;

  @override
  Result<BundledSkill> load(String name) {
    final root = locator.resolveRoot();
    return switch (root) {
      Success<String>(:final value) => DirectoryBundledSkillLoader(
        value,
      ).load(name),
      FailureResult<String>(:final failure) => FailureResult(failure),
    };
  }
}
