import 'dart:io';

import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/hive_skill_sidecar.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_skill_installer.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill_loader.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Shared copy-based [HarnessSkillInstaller] for directory-backed harnesses.
abstract base class DirectoryHarnessSkillInstaller
    implements HarnessSkillInstaller {
  /// Creates an installer targeting [skillsRootSegments] under home.
  const new({
    required this._platformPaths,
    required this._bundledSkillLoader,
    required this._appVersion,
    required this._displayName,
  });

  final PlatformPaths _platformPaths;
  final BundledSkillLoader _bundledSkillLoader;
  final String _appVersion;
  final String _displayName;

  /// Folder segments below the home folder that hold skills, e.g.
  /// `['.claude', 'skills']`.
  List<String> get skillsRootSegments;

  @override
  String? get skillDirectory {
    final String home;
    try {
      home = _platformPaths.homeDir();
    } on Object catch (_) {
      return null;
    }
    return _platformPaths.context.joinAll([
      home,
      ...skillsRootSegments,
      agenticHiveSkillName,
    ]);
  }

  @override
  HarnessSkillDetection detect() {
    final String home;
    try {
      home = _platformPaths.homeDir();
    } on Object catch (_) {
      return HarnessSkillDetection(
        status: HarnessSkillStatus.unknown,
        message: 'Could not locate the home folder for $_displayName.',
      );
    }

    final context = _platformPaths.context;
    final skillsRoot = context.joinAll([home, ...skillsRootSegments]);
    final skillDir = context.join(skillsRoot, agenticHiveSkillName);
    final sidecarPath = context.join(skillDir, HiveSkillSidecar.fileName);

    final FileSystemEntityType entityType;
    try {
      entityType = FileSystemEntity.typeSync(skillDir, followLinks: false);
    } on FileSystemException catch (error) {
      return HarnessSkillDetection(
        status: HarnessSkillStatus.unknown,
        message: 'Could not inspect the installed skill: ${error.message}',
      );
    }

    if (entityType == FileSystemEntityType.notFound) {
      return const HarnessSkillDetection(
        status: HarnessSkillStatus.notInstalled,
      );
    }
    if (entityType != FileSystemEntityType.directory) {
      return const HarnessSkillDetection(
        status: HarnessSkillStatus.conflict,
        message:
            'A skill named agentic-hive already exists here and was not '
            'installed by Agentic Hive.',
      );
    }

    final String sidecarText;
    try {
      final sidecarType = FileSystemEntity.typeSync(
        sidecarPath,
        followLinks: false,
      );
      if (sidecarType == FileSystemEntityType.notFound) {
        return const HarnessSkillDetection(
          status: HarnessSkillStatus.conflict,
          message:
              'A skill named agentic-hive already exists here and was not '
              'installed by Agentic Hive.',
        );
      }
      sidecarText = File(sidecarPath).readAsStringSync();
    } on FileSystemException catch (error) {
      return HarnessSkillDetection(
        status: HarnessSkillStatus.unknown,
        message: 'Could not read the installed skill: ${error.message}',
      );
    }

    final sidecar = HiveSkillSidecar.tryParse(sidecarText);
    if (sidecar == null) {
      return const HarnessSkillDetection(
        status: HarnessSkillStatus.conflict,
        message:
            'A skill named agentic-hive already exists here and was not '
            'installed by Agentic Hive.',
      );
    }

    final installedResult = DirectoryBundledSkillLoader(skillsRoot)
        .load(agenticHiveSkillName);
    switch (installedResult) {
      case FailureResult<BundledSkill>(:final failure):
        return switch (failure) {
          PersistenceFailure() => HarnessSkillDetection(
            status: HarnessSkillStatus.unknown,
            message: 'Could not read the installed skill: ${failure.message}',
          ),
          ValidationFailure() ||
          NotFoundFailure() => const HarnessSkillDetection(
            status: HarnessSkillStatus.modified,
            message: 'The installed skill was edited by hand.',
          ),
          _ => HarnessSkillDetection(
            status: HarnessSkillStatus.unknown,
            message: failure.message,
          ),
        };
      case Success<BundledSkill>(:final value):
        if (value.contentHash != sidecar.contentHash) {
          return const HarnessSkillDetection(
            status: HarnessSkillStatus.modified,
            message: 'The installed skill was edited by hand.',
          );
        }
    }

    final bundleResult = _bundledSkillLoader.load(agenticHiveSkillName);
    switch (bundleResult) {
      case FailureResult<BundledSkill>(:final failure):
        return HarnessSkillDetection(
          status: HarnessSkillStatus.unknown,
          message: failure.message,
        );
      case Success<BundledSkill>(:final value):
        if (sidecar.contentHash != value.contentHash) {
          return HarnessSkillDetection(
            status: HarnessSkillStatus.outdated,
            message:
                'Installed skill is from Agentic Hive ${sidecar.appVersion}; '
                'this version ships a newer one.',
          );
        }
        return const HarnessSkillDetection(
          status: HarnessSkillStatus.installed,
        );
    }
  }

  @override
  Result<void> install({bool overwriteModified = false}) {
    final detection = detect();
    final bundleResult = _bundledSkillLoader.load(agenticHiveSkillName);
    if (bundleResult case FailureResult<BundledSkill>(:final failure)) {
      return FailureResult(failure);
    }
    final bundle = (bundleResult as Success<BundledSkill>).value;

    switch (detection.status) {
      case HarnessSkillStatus.installed:
        return const Success(null);
      case HarnessSkillStatus.notInstalled:
      case HarnessSkillStatus.outdated:
        break;
      case HarnessSkillStatus.modified:
        if (!overwriteModified) {
          return FailureResult(
            ConflictFailure(
              detection.message ?? 'The installed skill was edited by hand.',
            ),
          );
        }
      case HarnessSkillStatus.conflict:
      case HarnessSkillStatus.unknown:
        return FailureResult(
          ConflictFailure(
            detection.message ??
                'Cannot install the skill because of an existing conflict.',
          ),
        );
    }

    for (final key in bundle.files.keys) {
      if (p.posix.isAbsolute(key) ||
          p.posix.split(key).any((segment) => segment == '..')) {
        return FailureResult(
          ValidationFailure('Invalid bundled skill path: $key'),
        );
      }
    }

    final context = _platformPaths.context;
    final home = _platformPaths.homeDir();
    final skillsRoot = context.joinAll([home, ...skillsRootSegments]);
    final skillDir = context.join(skillsRoot, agenticHiveSkillName);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final stagingDir = context.join(skillsRoot, '.agentic-hive.staging-$stamp');
    final oldDir = context.join(skillsRoot, '.agentic-hive.old-$stamp');
    var createdStaging = false;
    var movedOld = false;

    try {
      Directory(skillsRoot).createSync(recursive: true);
      Directory(stagingDir).createSync(recursive: true);
      createdStaging = true;

      for (final entry in bundle.files.entries) {
        final targetPath = context.joinAll([
          stagingDir,
          ...p.posix.split(entry.key),
        ]);
        final targetFile = File(targetPath);
        targetFile.parent.createSync(recursive: true);
        targetFile.writeAsBytesSync(entry.value, flush: true);
      }

      final sidecar = HiveSkillSidecar(
        appVersion: _appVersion,
        contentHash: bundle.contentHash,
      );
      File(context.join(stagingDir, HiveSkillSidecar.fileName))
          .writeAsStringSync(sidecar.encode(), flush: true);

      final currentType = FileSystemEntity.typeSync(
        skillDir,
        followLinks: false,
      );
      if (currentType == FileSystemEntityType.directory) {
        Directory(skillDir).renameSync(oldDir);
        movedOld = true;
        try {
          Directory(stagingDir).renameSync(skillDir);
          createdStaging = false;
        } on FileSystemException {
          Directory(oldDir).renameSync(skillDir);
          movedOld = false;
          rethrow;
        }
        Directory(oldDir).deleteSync(recursive: true);
        movedOld = false;
      } else {
        Directory(stagingDir).renameSync(skillDir);
        createdStaging = false;
      }
    } on FileSystemException catch (error) {
      if (createdStaging) {
        _deleteBestEffort(stagingDir);
      }
      if (movedOld) {
        _deleteBestEffort(oldDir);
      }
      return FailureResult(
        PersistenceFailure(
          'Could not install the skill: ${error.message}',
          cause: error,
        ),
      );
    }

    final verified = detect();
    if (verified.status != HarnessSkillStatus.installed) {
      return FailureResult(
        PersistenceFailure(
          verified.message ?? 'Skill verification failed after installation.',
        ),
      );
    }
    return const Success(null);
  }

  @override
  Result<void> remove() {
    final detection = detect();
    switch (detection.status) {
      case HarnessSkillStatus.notInstalled:
        return const Success(null);
      case HarnessSkillStatus.installed:
      case HarnessSkillStatus.outdated:
      case HarnessSkillStatus.modified:
        break;
      case HarnessSkillStatus.conflict:
      case HarnessSkillStatus.unknown:
        return FailureResult(
          ConflictFailure(
            detection.message ??
                'Cannot remove the skill because it is not owned by '
                    'Agentic Hive.',
          ),
        );
    }

    final context = _platformPaths.context;
    final home = _platformPaths.homeDir();
    final skillDir = context.joinAll([
      home,
      ...skillsRootSegments,
      agenticHiveSkillName,
    ]);

    try {
      Directory(skillDir).deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Could not remove the skill: ${error.message}',
          cause: error,
        ),
      );
    }

    final verified = detect();
    if (verified.status != HarnessSkillStatus.notInstalled) {
      return FailureResult(
        PersistenceFailure(
          verified.message ?? 'Skill folder still exists after removal.',
        ),
      );
    }
    return const Success(null);
  }

  void _deleteBestEffort(String path) {
    try {
      final dir = Directory(path);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } on FileSystemException {
      // Best-effort cleanup of temporary directories.
    }
  }
}
