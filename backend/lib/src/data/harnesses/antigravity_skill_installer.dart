import 'package:agentic_hive_backend/src/data/harnesses/directory_harness_skill_installer.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Installs the Agentic Hive skill into
/// `~/.gemini/config/skills/agentic-hive`.
final class AntigravitySkillInstaller extends DirectoryHarnessSkillInstaller {
  /// Creates an Antigravity skill installer.
  const new({
    required super.platformPaths,
    required super.bundledSkillLoader,
    required super.appVersion,
  }) : super(displayName: 'Antigravity');

  @override
  Set<HarnessId> get harnessIds => const {HarnessId.antigravity};

  @override
  List<String> get skillsRootSegments => const ['.gemini', 'config', 'skills'];
}
