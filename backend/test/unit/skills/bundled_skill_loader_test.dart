import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/skills/bundled_skills_locator.dart';
import 'package:agentic_hive_backend/src/data/skills/directory_bundled_skill_loader.dart';
import 'package:agentic_hive_backend/src/domain/skills/bundled_skill.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  Directory createTempDir() {
    final dir = Directory.systemTemp.createTempSync('bundled_skill_test_');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });
    return dir;
  }

  group('DirectoryBundledSkillLoader', () {
    test('loads SKILL.md and nested files with POSIX keys', () {
      final root = createTempDir();
      final skillDir = Directory(p.join(root.path, 'agentic-hive'))
        ..createSync();
      File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('# Skill\n');
      Directory(p.join(skillDir.path, 'references')).createSync();
      File(p.join(skillDir.path, 'references', 'a.md'))
          .writeAsStringSync('Ref A\n');

      final result = DirectoryBundledSkillLoader(root.path)
          .load('agentic-hive');
      expect(result, isA<Success<BundledSkill>>());
      final skill = (result as Success<BundledSkill>).value;
      expect(skill.name, 'agentic-hive');
      expect(
        skill.files.keys,
        unorderedEquals(['SKILL.md', 'references/a.md']),
      );
      expect(utf8.decode(skill.files['SKILL.md']!), '# Skill\n');
      expect(utf8.decode(skill.files['references/a.md']!), 'Ref A\n');
    });

    test('normalizes CRLF to LF for text files so hash matches LF', () {
      final rootLf = createTempDir();
      final rootCrlf = createTempDir();
      Directory(p.join(rootLf.path, 's')).createSync();
      Directory(p.join(rootCrlf.path, 's')).createSync();
      File(p.join(rootLf.path, 's', 'SKILL.md'))
          .writeAsBytesSync(utf8.encode('line1\nline2\n'));
      File(p.join(rootCrlf.path, 's', 'SKILL.md'))
          .writeAsBytesSync(utf8.encode('line1\r\nline2\r\n'));

      final lfSkill = (DirectoryBundledSkillLoader(
        rootLf.path,
      ).load('s') as Success<BundledSkill>).value;
      final crlfSkill = (DirectoryBundledSkillLoader(
        rootCrlf.path,
      ).load('s') as Success<BundledSkill>).value;

      expect(crlfSkill.files['SKILL.md'], equals(lfSkill.files['SKILL.md']));
      expect(crlfSkill.contentHash, equals(lfSkill.contentHash));
    });

    test('excludes root hive-skill.json but keeps one in a subfolder', () {
      final root = createTempDir();
      final skillDir = Directory(p.join(root.path, 's'))..createSync();
      File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('# S\n');
      File(p.join(skillDir.path, 'hive-skill.json'))
          .writeAsStringSync('{"ignored":true}');
      Directory(p.join(skillDir.path, 'sub')).createSync();
      File(p.join(skillDir.path, 'sub', 'hive-skill.json'))
          .writeAsStringSync('{"kept":true}');

      final skill = (DirectoryBundledSkillLoader(
        root.path,
      ).load('s') as Success<BundledSkill>).value;
      expect(
        skill.files.keys,
        unorderedEquals(['SKILL.md', 'sub/hive-skill.json']),
      );
    });

    test('returns NotFoundFailure when skill folder is missing', () {
      final root = createTempDir();
      final result = DirectoryBundledSkillLoader(root.path).load('missing');
      expect(
        result,
        isA<FailureResult<BundledSkill>>().having(
          (e) => e.failure,
          'failure',
          isA<NotFoundFailure>(),
        ),
      );
    });

    test('returns ValidationFailure when SKILL.md is missing', () {
      final root = createTempDir();
      Directory(p.join(root.path, 's')).createSync();
      final result = DirectoryBundledSkillLoader(root.path).load('s');
      expect(
        result,
        isA<FailureResult<BundledSkill>>().having(
          (e) => e.failure,
          'failure',
          isA<ValidationFailure>(),
        ),
      );
    });
  });

  group('BundledSkillsLocator', () {
    test('resolves skills dir relative to resolvedExecutable', () {
      final tmp = createTempDir();
      final expectedSkills = p.join(tmp.path, 'backend', 'skills');
      final locator = BundledSkillsLocator(
        resolvedExecutable: p.join(tmp.path, 'backend', 'bin', 'server'),
        directoryExists: (path) => path == expectedSkills,
        pathContext: p.context,
      );

      final result = locator.resolveRoot();
      expect(result, isA<Success<String>>());
      expect((result as Success<String>).value, equals(expectedSkills));
    });

    test('returns NotFoundFailure when no candidate directory exists', () {
      final locator = BundledSkillsLocator(
        resolvedExecutable: p.join('nonexistent', 'bin', 'server'),
        directoryExists: (_) => false,
        pathContext: p.context,
      );

      final result = locator.resolveRoot();
      expect(
        result,
        isA<FailureResult<String>>().having(
          (e) => e.failure,
          'failure',
          isA<NotFoundFailure>(),
        ),
      );
    });

    test('in production mode ignores working directory candidates', () {
      final tmp = createTempDir();
      final cwdSkills = p.join(tmp.path, 'skills');
      final locator = BundledSkillsLocator(
        resolvedExecutable: p.join(tmp.path, 'opt', 'bin', 'server'),
        currentWorkingDirectory: tmp.path,
        directoryExists: (path) => path == cwdSkills,
        pathContext: p.context,
        runtimeMode: RuntimeMode.production,
      );

      final result = locator.resolveRoot();
      expect(
        result,
        isA<FailureResult<String>>().having(
          (e) => e.failure,
          'failure',
          isA<NotFoundFailure>(),
        ),
      );
    });

    test('in development mode falls back to working directory skills', () {
      final tmp = createTempDir();
      final cwdSkills = p.join(tmp.path, 'skills');
      final locator = BundledSkillsLocator(
        resolvedExecutable: p.join(tmp.path, 'opt', 'bin', 'server'),
        currentWorkingDirectory: tmp.path,
        directoryExists: (path) => path == cwdSkills,
        pathContext: p.context,
        runtimeMode: RuntimeMode.development,
      );

      final result = locator.resolveRoot();
      expect(result, isA<Success<String>>());
      expect((result as Success<String>).value, equals(cwdSkills));
    });
  });
}
