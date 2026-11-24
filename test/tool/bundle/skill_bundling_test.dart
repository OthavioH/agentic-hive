import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../tool/src/bundle/bundle_layout.dart';
import '../../../tool/src/bundle/bundle_platform.dart';
import '../../../tool/src/bundle/skill_bundling.dart';

void main() {
  Directory createTempDir() {
    final dir = Directory.systemTemp.createTempSync('skill_bundling_test_');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });
    return dir;
  }

  group('copyBundledSkills', () {
    test('copies nested files byte for byte into layout.skillsDir', () {
      final tmp = createTempDir();
      final sourceSkillsDir = p.join(tmp.path, 'src_skills');
      final skillDir = Directory(
        p.join(sourceSkillsDir, BundleLayout.skillName),
      )..createSync(recursive: true);
      File(p.join(skillDir.path, 'SKILL.md')).writeAsBytesSync([1, 2, 3]);
      Directory(p.join(skillDir.path, 'references')).createSync();
      File(p.join(skillDir.path, 'references', 'a.md'))
          .writeAsBytesSync([4, 5, 6]);

      final layout = BundleLayout(
        p.join(tmp.path, 'bundle'),
        platform: const LinuxBundlePlatform(),
      );

      final problems = copyBundledSkills(
        layout: layout,
        sourceSkillsDir: sourceSkillsDir,
      );

      expect(problems, isEmpty);
      expect(
        File(p.join(layout.skillsDir, BundleLayout.skillName, 'SKILL.md'))
            .readAsBytesSync(),
        equals([1, 2, 3]),
      );
      expect(
        File(
          p.join(
            layout.skillsDir,
            BundleLayout.skillName,
            'references',
            'a.md',
          ),
        ).readAsBytesSync(),
        equals([4, 5, 6]),
      );
    });

    test('replaces an existing skills dir so stale files are removed', () {
      final tmp = createTempDir();
      final sourceSkillsDir = p.join(tmp.path, 'src_skills');
      final skillDir = Directory(
        p.join(sourceSkillsDir, BundleLayout.skillName),
      )..createSync(recursive: true);
      File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('# New\n');

      final layout = BundleLayout(
        p.join(tmp.path, 'bundle'),
        platform: const LinuxBundlePlatform(),
      );
      final staleFile =
          File(p.join(layout.skillsDir, BundleLayout.skillName, 'stale.txt'))
            ..createSync(recursive: true)
            ..writeAsStringSync('old');

      final problems = copyBundledSkills(
        layout: layout,
        sourceSkillsDir: sourceSkillsDir,
      );

      expect(problems, isEmpty);
      expect(staleFile.existsSync(), isFalse);
    });

    test('returns problems when source skill folder is missing', () {
      final tmp = createTempDir();
      final layout = BundleLayout(
        p.join(tmp.path, 'bundle'),
        platform: const LinuxBundlePlatform(),
      );

      final problems = copyBundledSkills(
        layout: layout,
        sourceSkillsDir: p.join(tmp.path, 'missing'),
      );

      expect(problems, isNotEmpty);
    });

    test('returns problems when SKILL.md is missing from source', () {
      final tmp = createTempDir();
      final sourceSkillsDir = p.join(tmp.path, 'src_skills');
      Directory(p.join(sourceSkillsDir, BundleLayout.skillName))
          .createSync(recursive: true);

      final layout = BundleLayout(
        p.join(tmp.path, 'bundle'),
        platform: const LinuxBundlePlatform(),
      );

      final problems = copyBundledSkills(
        layout: layout,
        sourceSkillsDir: sourceSkillsDir,
      );

      expect(problems, isNotEmpty);
    });
  });
}
