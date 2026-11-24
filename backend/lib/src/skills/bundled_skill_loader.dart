import 'dart:io';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill.dart';
import 'package:path/path.dart' as p;

const _textExtensions = <String>{'.md', '.json', '.txt', '.yaml', '.yml'};

/// Reads a skill by name. One implementation per source (disk for now).
abstract interface class BundledSkillLoader {
  /// Loads the skill [name]. Never throws; returns a failure Result instead.
  Result<BundledSkill> load(String name);
}

/// Reads skills from `<skillsRoot>/<name>/`.
final class DirectoryBundledSkillLoader implements BundledSkillLoader {
  /// Creates a loader over [skillsRoot].
  const new(this.skillsRoot);

  /// Root directory containing skill folders.
  final String skillsRoot;

  @override
  Result<BundledSkill> load(String name) {
    final skillDir = Directory(p.join(skillsRoot, name));
    try {
      if (!skillDir.existsSync()) {
        return FailureResult(
          NotFoundFailure('Skill folder "$name" does not exist.'),
        );
      }

      final files = <String, List<int>>{};
      for (final entity in skillDir.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: skillDir.path);
        final posixPath = p.posix.joinAll(p.split(relative));
        if (posixPath == 'hive-skill.json') continue;

        final rawBytes = entity.readAsBytesSync();
        files[posixPath] = _isTextFile(posixPath)
            ? _normalizeLineEndings(rawBytes)
            : rawBytes;
      }

      if (!files.containsKey('SKILL.md')) {
        return FailureResult(
          ValidationFailure('Skill "$name" is missing SKILL.md.'),
        );
      }

      return Success(
        BundledSkill(
          name: name,
          files: Map.unmodifiable(files),
          contentHash: computeSkillContentHash(files),
        ),
      );
    } on FileSystemException catch (e) {
      return FailureResult(
        PersistenceFailure(
          'Failed to read skill "$name": ${e.message}',
          cause: e,
        ),
      );
    }
  }
}

bool _isTextFile(String posixPath) {
  final lower = posixPath.toLowerCase();
  return _textExtensions.any(lower.endsWith);
}

List<int> _normalizeLineEndings(List<int> bytes) {
  final builder = BytesBuilder(copy: false);
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] == 13 && i + 1 < bytes.length && bytes[i + 1] == 10) {
      continue;
    }
    builder.addByte(bytes[i]);
  }
  return builder.takeBytes();
}

/// Finds the folder that holds the bundled skills.
final class BundledSkillsLocator {
  /// Creates a locator; hooks exist for tests.
  new({
    String? resolvedExecutable,
    bool Function(String path)? directoryExists,
    p.Context? pathContext,
  }) : _resolvedExecutable = resolvedExecutable ?? Platform.resolvedExecutable,
       _directoryExists =
           directoryExists ?? ((path) => Directory(path).existsSync()),
       _ctx = pathContext ?? p.context;

  final String _resolvedExecutable;
  final bool Function(String path) _directoryExists;
  final p.Context _ctx;

  /// Returns the existing skills root or a `NotFoundFailure`.
  Result<String> resolveRoot() {
    final candidates = <String>[
      _ctx.normalize(
        _ctx.join(_ctx.dirname(_resolvedExecutable), '..', 'skills'),
      ),
      _ctx.join(Directory.current.path, 'skills'),
      _ctx.join(Directory.current.path, 'backend', 'skills'),
      if (Platform.script.scheme == 'file' &&
          Platform.script.toFilePath().endsWith('.dart'))
        _ctx.join(
          _ctx.dirname(_ctx.dirname(Platform.script.toFilePath())),
          'skills',
        ),
    ];

    for (final candidate in candidates) {
      if (_directoryExists(candidate)) {
        return Success(candidate);
      }
    }

    return const FailureResult(
      NotFoundFailure('Could not find the bundled skills folder.'),
    );
  }
}
