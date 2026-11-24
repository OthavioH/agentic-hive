import 'dart:io';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/hive_skill_sidecar.dart';
import 'package:agentic_hive_backend/src/domain/skills/bundled_skill.dart';
import 'package:agentic_hive_backend/src/domain/skills/bundled_skill_loader.dart';
import 'package:path/path.dart' as p;

const _textExtensions = <String>{'.md', '.json', '.txt', '.yaml', '.yml'};

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
        if (posixPath == HiveSkillSidecar.fileName) continue;

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
