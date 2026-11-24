import 'package:agentic_hive_backend/src/data/harnesses/directory_harness_skill_installer.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Installs the Agentic Hive skill into `~/.agents/skills/agentic-hive`
/// shared by Codex and Gemini CLI.
final class SharedAgentsSkillInstaller extends DirectoryHarnessSkillInstaller {
  /// Creates a shared agents skill installer.
  const new({
    required super.platformPaths,
    required super.bundledSkillLoader,
    required super.appVersion,
  }) : super(displayName: 'Codex and Gemini CLI');

  @override
  Set<HarnessId> get harnessIds => const {HarnessId.codex, HarnessId.geminiCli};

  @override
  List<String> get skillsRootSegments => const ['.agents', 'skills'];
}
