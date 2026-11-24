import 'package:agentic_hive_backend/src/data/harnesses/directory_harness_skill_installer.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Installs the Agentic Hive skill into `~/.claude/skills/agentic-hive`.
final class ClaudeCodeSkillInstaller extends DirectoryHarnessSkillInstaller {
  /// Creates a Claude Code skill installer.
  const new({
    required super.platformPaths,
    required super.bundledSkillLoader,
    required super.appVersion,
    super.fileOps,
  }) : super(displayName: 'Claude Code');

  @override
  Set<HarnessId> get harnessIds => const {HarnessId.claudeCode};

  @override
  List<String> get skillsRootSegments => const ['.claude', 'skills'];
}
