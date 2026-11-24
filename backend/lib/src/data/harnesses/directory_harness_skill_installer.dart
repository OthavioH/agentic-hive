import 'dart:io';

import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/hive_skill_sidecar.dart';
import 'package:agentic_hive_backend/src/data/skills/directory_bundled_skill_loader.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_skill_installer.dart';
import 'package:agentic_hive_backend/src/domain/skills/bundled_skill.dart';
import 'package:agentic_hive_backend/src/domain/skills/bundled_skill_loader.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// File-system operations used by [DirectoryHarnessSkillInstaller].
///
/// Extracted as a seam so tests can inject partial-failure scenarios.
abstract interface class SkillInstallerFileOps {
  /// Returns the entity type at [path].
  FileSystemEntityType entityType(String path, {bool followLinks = false});

  /// Returns whether a directory exists at [path].
  bool directoryExists(String path);

  /// Lists the immediate entries of [path].
  List<FileSystemEntity> listDirectory(String path);

  /// Creates the directory at [path].
  void createDirectory(String path, {bool recursive = false});

  /// Renames the directory from [from] to [to].
  void renameDirectory(String from, String to);

  /// Deletes the directory at [path].
  void deleteDirectory(String path, {bool recursive = false});

  /// Reads [path] as UTF-8 text.
  String readString(String path);

  /// Writes [bytes] to [path], creating parent directories if needed.
  void writeBytes(String path, List<int> bytes);

  /// Writes [contents] to [path], creating parent directories if needed.
  void writeString(String path, String contents);
}

/// Default `dart:io` implementation of [SkillInstallerFileOps].
final class DefaultSkillInstallerFileOps implements SkillInstallerFileOps {
  /// Creates the default file-system operations adapter.
  const new();

  @override
  FileSystemEntityType entityType(String path, {bool followLinks = false}) =>
      FileSystemEntity.typeSync(path, followLinks: followLinks);

  @override
  bool directoryExists(String path) => Directory(path).existsSync();

  @override
  List<FileSystemEntity> listDirectory(String path) =>
      Directory(path).listSync();

  @override
  void createDirectory(String path, {bool recursive = false}) {
    Directory(path).createSync(recursive: recursive);
  }

  @override
  void renameDirectory(String from, String to) {
    Directory(from).renameSync(to);
  }

  @override
  void deleteDirectory(String path, {bool recursive = false}) {
    Directory(path).deleteSync(recursive: recursive);
  }

  @override
  String readString(String path) => File(path).readAsStringSync();

  @override
  void writeBytes(String path, List<int> bytes) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes, flush: true);
  }

  @override
  void writeString(String path, String contents) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents, flush: true);
  }
}

/// Shared copy-based [HarnessSkillInstaller] for directory-backed harnesses.
abstract base class DirectoryHarnessSkillInstaller
    implements HarnessSkillInstaller {
  /// Creates an installer targeting [skillsRootSegments] under home.
  const new({
    required this._platformPaths,
    required this._bundledSkillLoader,
    required this._appVersion,
    required this._displayName,
    this._fileOps = const DefaultSkillInstallerFileOps(),
  });

  static final Logger _log = Logger('harnesses.skill_installer');
  static final RegExp _windowsDrivePrefixPattern = RegExp('^[A-Za-z]:');

  static const _stagingPrefix = '.agentic-hive.staging-';
  static const _oldPrefix = '.agentic-hive.old-';
  static const _conflictMessage =
      'A skill named $agenticHiveSkillName already exists here and was not '
      'installed by Agentic Hive.';
  static const _conflictDetection = HarnessSkillDetection(
    status: HarnessSkillStatus.conflict,
    message: _conflictMessage,
  );

  final PlatformPaths _platformPaths;
  final BundledSkillLoader _bundledSkillLoader;
  final String _appVersion;
  final String _displayName;
  final SkillInstallerFileOps _fileOps;

  /// Folder segments below the home folder that hold skills, e.g.
  /// `['.claude', 'skills']`.
  List<String> get skillsRootSegments;

  Result<({String skillsRoot, String skillDir})> _resolvePaths() {
    final String home;
    try {
      home = _platformPaths.homeDir();
    } on Object {
      return FailureResult(
        NotFoundFailure('Could not locate the home folder for $_displayName.'),
      );
    }
    final context = _platformPaths.context;
    final skillsRoot = context.joinAll([home, ...skillsRootSegments]);
    final skillDir = context.join(skillsRoot, agenticHiveSkillName);
    return Success((skillsRoot: skillsRoot, skillDir: skillDir));
  }

  @override
  String? get skillDirectory => switch (_resolvePaths()) {
    Success(:final value) => value.skillDir,
    FailureResult() => null,
  };

  @override
  HarnessSkillDetection detect() {
    final pathsResult = _resolvePaths();
    if (pathsResult case FailureResult(:final failure)) {
      return HarnessSkillDetection(
        status: HarnessSkillStatus.unknown,
        message: failure.message,
      );
    }
    final (:skillsRoot, :skillDir) =
        (pathsResult as Success<({String skillsRoot, String skillDir})>).value;

    final FileSystemEntityType entityType;
    try {
      entityType = _fileOps.entityType(skillDir);
    } on FileSystemException catch (error) {
      return HarnessSkillDetection(
        status: HarnessSkillStatus.unknown,
        message: 'Could not inspect the installed skill: ${error.message}',
      );
    }

    _sweepTempDirs(
      skillsRoot,
      includeOldDirs: entityType != FileSystemEntityType.notFound,
    );

    if (entityType == FileSystemEntityType.notFound) {
      return const HarnessSkillDetection(
        status: HarnessSkillStatus.notInstalled,
      );
    }
    if (entityType != FileSystemEntityType.directory) {
      return _conflictDetection;
    }

    final sidecarResult = _readSidecar(skillDir);
    switch (sidecarResult) {
      case FailureResult(:final failure):
        if (failure is ConflictFailure) {
          return _conflictDetection;
        }
        return HarnessSkillDetection(
          status: HarnessSkillStatus.unknown,
          message: failure.message,
        );
      case Success(:final value):
        final sidecar = value;
        final installedResult = DirectoryBundledSkillLoader(skillsRoot)
            .load(agenticHiveSkillName);
        switch (installedResult) {
          case FailureResult<BundledSkill>(:final failure):
            return switch (failure) {
              PersistenceFailure() => HarnessSkillDetection(
                status: HarnessSkillStatus.unknown,
                message:
                    'Could not read the installed skill: ${failure.message}',
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
                    'Installed skill is from Agentic Hive '
                    '${sidecar.appVersion}; this version ships a newer one.',
              );
            }
            return const HarnessSkillDetection(
              status: HarnessSkillStatus.installed,
            );
        }
    }
  }

  @override
  Result<void> install({bool overwriteModified = false}) {
    final pathsResult = _resolvePaths();
    if (pathsResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final (:skillsRoot, :skillDir) =
        (pathsResult as Success<({String skillsRoot, String skillDir})>).value;

    _sweepTempDirs(skillsRoot, includeOldDirs: true);

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

    final context = _platformPaths.context;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final stagingDir = context.join(skillsRoot, '$_stagingPrefix$stamp');
    final oldDir = context.join(skillsRoot, '$_oldPrefix$stamp');
    final normalizedStaging = context.normalize(stagingDir);

    for (final key in bundle.files.keys) {
      if (_hasInvalidRelativeKey(key)) {
        return FailureResult(
          ValidationFailure('Invalid bundled skill path: $key'),
        );
      }
      final candidateTarget = context.joinAll([
        stagingDir,
        ...p.posix.split(key),
      ]);
      if (!context.isWithin(
        normalizedStaging,
        context.normalize(candidateTarget),
      )) {
        return FailureResult(
          ValidationFailure('Invalid bundled skill path: $key'),
        );
      }
    }

    var createdStaging = false;
    var movedOld = false;

    try {
      _fileOps
        ..createDirectory(skillsRoot, recursive: true)
        ..createDirectory(stagingDir, recursive: true);
      createdStaging = true;

      for (final entry in bundle.files.entries) {
        final targetPath = context.joinAll([
          stagingDir,
          ...p.posix.split(entry.key),
        ]);
        _fileOps.writeBytes(targetPath, entry.value);
      }

      final sidecar = HiveSkillSidecar(
        appVersion: _appVersion,
        contentHash: bundle.contentHash,
      );
      _fileOps.writeString(
        context.join(stagingDir, HiveSkillSidecar.fileName),
        sidecar.encode(),
      );

      final currentType = _fileOps.entityType(skillDir);
      if (currentType == FileSystemEntityType.directory) {
        _fileOps.renameDirectory(skillDir, oldDir);
        movedOld = true;

        final oldSidecar = _readSidecar(oldDir);
        if (oldSidecar case FailureResult()) {
          _fileOps.renameDirectory(oldDir, skillDir);
          movedOld = false;
          _deleteBestEffort(stagingDir);
          createdStaging = false;
          return const FailureResult(ConflictFailure(_conflictMessage));
        }

        try {
          _fileOps.renameDirectory(stagingDir, skillDir);
          createdStaging = false;
        } on FileSystemException {
          _fileOps.renameDirectory(oldDir, skillDir);
          movedOld = false;
          rethrow;
        }
        movedOld = false;

        try {
          _fileOps.deleteDirectory(oldDir, recursive: true);
        } on FileSystemException catch (error, stackTrace) {
          _log.warning(
            LogEvent(
              'harnesses.skill_installer.cleanup_failed',
              userContent:
                  'Installed skill at $skillDir, but failed to delete old '
                  'backup at $oldDir: ${error.message}',
            ),
            error,
            stackTrace,
          );
        }
      } else if (currentType == FileSystemEntityType.notFound) {
        _fileOps.renameDirectory(stagingDir, skillDir);
        createdStaging = false;
      } else {
        _deleteBestEffort(stagingDir);
        createdStaging = false;
        return const FailureResult(ConflictFailure(_conflictMessage));
      }
    } on FileSystemException catch (error, stackTrace) {
      if (createdStaging) {
        _deleteBestEffort(stagingDir);
      }
      if (movedOld) {
        _log.warning(
          LogEvent(
            'harnesses.skill_installer.rollback_failed',
            userContent:
                'Could not restore previous skill copy preserved at $oldDir: '
                '${error.message}',
          ),
          error,
          stackTrace,
        );
        return FailureResult(
          PersistenceFailure(
            'Could not install the skill and could not restore the previous '
            'copy preserved at $oldDir: ${error.message}',
            cause: error,
          ),
        );
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
    final pathsResult = _resolvePaths();
    if (pathsResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final (:skillsRoot, :skillDir) =
        (pathsResult as Success<({String skillsRoot, String skillDir})>).value;

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

    try {
      _fileOps.deleteDirectory(skillDir, recursive: true);
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

  static bool _hasInvalidRelativeKey(String key) =>
      key.isEmpty ||
      key.contains(r'\') ||
      _windowsDrivePrefixPattern.hasMatch(key) ||
      p.posix.isAbsolute(key) ||
      p.windows.isAbsolute(key) ||
      p.posix.split(key).any((segment) => segment == '..');

  Result<HiveSkillSidecar> _readSidecar(String skillDir) {
    final sidecarPath = _platformPaths.context.join(
      skillDir,
      HiveSkillSidecar.fileName,
    );
    final String sidecarText;
    try {
      final sidecarType = _fileOps.entityType(sidecarPath);
      if (sidecarType == FileSystemEntityType.notFound) {
        return const FailureResult(ConflictFailure(_conflictMessage));
      }
      if (sidecarType != FileSystemEntityType.file) {
        return const FailureResult(ConflictFailure(_conflictMessage));
      }
      sidecarText = _fileOps.readString(sidecarPath);
    } on FileSystemException catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Could not read the installed skill: ${error.message}',
          cause: error,
        ),
      );
    }

    final sidecar = HiveSkillSidecar.tryParse(sidecarText);
    if (sidecar == null) {
      return const FailureResult(ConflictFailure(_conflictMessage));
    }
    return Success(sidecar);
  }

  void _sweepTempDirs(String skillsRoot, {required bool includeOldDirs}) {
    try {
      if (!_fileOps.directoryExists(skillsRoot)) return;
      for (final entity in _fileOps.listDirectory(skillsRoot)) {
        final name = _platformPaths.context.basename(entity.path);
        final isTemp =
            name.startsWith(_stagingPrefix) ||
            (includeOldDirs && name.startsWith(_oldPrefix));
        if (!isTemp) continue;
        _deleteBestEffort(entity.path);
      }
    } on FileSystemException {
      // Best-effort sweep of leftover temporary directories.
    }
  }

  void _deleteBestEffort(String path) {
    try {
      if (_fileOps.directoryExists(path)) {
        _fileOps.deleteDirectory(path, recursive: true);
      }
    } on FileSystemException {
      // Best-effort cleanup of temporary directories.
    }
  }
}
