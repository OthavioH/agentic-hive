import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Outcome of inspecting the skill folder of one harness location.
final class HarnessSkillDetection {
  /// Creates a detection result.
  const new({required this.status, this.message});

  /// Detected skill status.
  final HarnessSkillStatus status;

  /// Human-readable explanation when [status] is not installed/not_installed.
  final String? message;
}

/// Detects, installs and removes the Agentic Hive skill for one location.
abstract interface class HarnessSkillInstaller {
  /// Harnesses that read this installer's location (one for most, two for the
  /// shared `~/.agents/skills` folder).
  Set<HarnessId> get harnessIds;

  /// Reads the disk and the Bundle; never spawns a process, never throws.
  HarnessSkillDetection detect();

  /// Installs or updates the skill. [overwriteModified] confirms replacing
  /// files edited by hand.
  Result<void> install({bool overwriteModified = false});

  /// Removes the skill only when its folder has our sidecar.
  Result<void> remove();
}

/// Registry of [HarnessSkillInstaller]s keyed by [HarnessId].
final class HarnessSkillInstallerRegistry {
  /// Creates a registry indexing [installers] by each installer's
  /// [HarnessSkillInstaller.harnessIds].
  new(Iterable<HarnessSkillInstaller> installers)
    : _byId = {
        for (final installer in installers)
          for (final id in installer.harnessIds) id: installer,
      };

  final Map<HarnessId, HarnessSkillInstaller> _byId;

  /// Returns the installer for [id], or `null` if unsupported.
  HarnessSkillInstaller? operator [](HarnessId id) => _byId[id];
}
