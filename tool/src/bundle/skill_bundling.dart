import 'dart:io';

import 'package:path/path.dart' as p;

import 'bundle_layout.dart';

/// Copies `[sourceSkillsDir]/<BundleLayout.skillName>/` into
/// `layout.skillsDir/<skillName>/`. Returns problems; empty when ok.
List<String> copyBundledSkills({
  required BundleLayout layout,
  required String sourceSkillsDir,
}) {
  final sourceDir = Directory(p.join(sourceSkillsDir, BundleLayout.skillName));
  if (!sourceDir.existsSync()) {
    return ['Missing bundled skill folder: ${sourceDir.path}'];
  }
  final sourceSkillMd = File(p.join(sourceDir.path, 'SKILL.md'));
  if (!sourceSkillMd.existsSync()) {
    return ['Missing SKILL.md in ${sourceDir.path}'];
  }

  final destSkillsDir = Directory(layout.skillsDir);
  if (destSkillsDir.existsSync()) {
    destSkillsDir.deleteSync(recursive: true);
  }
  final destSkillDir = Directory(
    p.join(layout.skillsDir, BundleLayout.skillName),
  )..createSync(recursive: true);

  for (final entity in sourceDir.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    final relative = p.relative(entity.path, from: sourceDir.path);
    final destFile = File(p.join(destSkillDir.path, relative));
    destFile.parent.createSync(recursive: true);
    entity.copySync(destFile.path);
  }

  final problems = <String>[];
  for (final requiredPath in layout.skillFilePaths) {
    if (!File(requiredPath).existsSync()) {
      problems.add('Missing copied skill file: $requiredPath');
    }
  }
  return problems;
}
