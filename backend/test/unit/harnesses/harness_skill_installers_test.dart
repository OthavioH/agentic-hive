import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/antigravity_skill_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/claude_code_skill_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/hive_skill_sidecar.dart';
import 'package:agentic_hive_backend/src/data/harnesses/shared_agents_skill_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_skill_installer.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill_loader.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _FakeBundledSkillLoader implements BundledSkillLoader {
  new(this.result);

  Result<BundledSkill> result;

  static BundledSkill makeBundle({
    String skillMd = '# Agentic Hive\n\nv1\n',
    String flowMd = '# Flow\n\nv1\n',
    Map<String, List<int>>? extraFiles,
  }) {
    final files = <String, List<int>>{
      'SKILL.md': utf8.encode(skillMd),
      'references/flow.md': utf8.encode(flowMd),
      ...?extraFiles,
    };
    return BundledSkill(
      name: agenticHiveSkillName,
      files: files,
      contentHash: computeSkillContentHash(files),
    );
  }

  @override
  Result<BundledSkill> load(String name) => result;
}

typedef _LocationSpec = ({
  String name,
  HarnessSkillInstaller Function(
    PlatformPaths paths,
    BundledSkillLoader loader,
    String appVersion,
  )
  makeInstaller,
  Set<HarnessId> ids,
  List<String> relativeSegments,
});

void main() {
  final locations = <_LocationSpec>[
    (
      name: 'Claude Code',
      makeInstaller: (paths, loader, version) => ClaudeCodeSkillInstaller(
        platformPaths: paths,
        bundledSkillLoader: loader,
        appVersion: version,
      ),
      ids: {HarnessId.claudeCode},
      relativeSegments: ['.claude', 'skills'],
    ),
    (
      name: 'Shared Agents (Codex & Gemini CLI)',
      makeInstaller: (paths, loader, version) => SharedAgentsSkillInstaller(
        platformPaths: paths,
        bundledSkillLoader: loader,
        appVersion: version,
      ),
      ids: {HarnessId.codex, HarnessId.geminiCli},
      relativeSegments: ['.agents', 'skills'],
    ),
    (
      name: 'Antigravity',
      makeInstaller: (paths, loader, version) => AntigravitySkillInstaller(
        platformPaths: paths,
        bundledSkillLoader: loader,
        appVersion: version,
      ),
      ids: {HarnessId.antigravity},
      relativeSegments: ['.gemini', 'config', 'skills'],
    ),
  ];

  PlatformPaths tempPaths(String home) => platformPathsFor(
    Platform.operatingSystem,
    environment: {'HOME': home, 'USERPROFILE': home, 'LOCALAPPDATA': home},
  );

  String createTempHome() {
    final dir = Directory.systemTemp.createTempSync('hive_skill_test_');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });
    return dir.path;
  }

  test('registry maps Codex and Gemini CLI to the same shared instance', () {
    final home = createTempHome();
    final paths = tempPaths(home);
    final loader = _FakeBundledSkillLoader(
      Success(_FakeBundledSkillLoader.makeBundle()),
    );
    final registry = HarnessSkillInstallerRegistry([
      ClaudeCodeSkillInstaller(
        platformPaths: paths,
        bundledSkillLoader: loader,
        appVersion: '1.0.0',
      ),
      SharedAgentsSkillInstaller(
        platformPaths: paths,
        bundledSkillLoader: loader,
        appVersion: '1.0.0',
      ),
      AntigravitySkillInstaller(
        platformPaths: paths,
        bundledSkillLoader: loader,
        appVersion: '1.0.0',
      ),
    ]);

    expect(registry[HarnessId.claudeCode], isA<ClaudeCodeSkillInstaller>());
    expect(registry[HarnessId.codex], isA<SharedAgentsSkillInstaller>());
    expect(
      identical(registry[HarnessId.codex], registry[HarnessId.geminiCli]),
      isTrue,
    );
    expect(registry[HarnessId.antigravity], isA<AntigravitySkillInstaller>());
  });

  for (final loc in locations) {
    group(loc.name, () {
      late String home;
      late PlatformPaths paths;
      late _FakeBundledSkillLoader loader;
      late HarnessSkillInstaller installer;
      late String skillsRoot;
      late String skillDir;

      setUp(() {
        home = createTempHome();
        paths = tempPaths(home);
        loader = _FakeBundledSkillLoader(
          Success(_FakeBundledSkillLoader.makeBundle()),
        );
        installer = loc.makeInstaller(paths, loader, '9.9.9');
        skillsRoot = p.joinAll([home, ...loc.relativeSegments]);
        skillDir = p.join(skillsRoot, agenticHiveSkillName);
      });

      test('detects not_installed on empty home and empty skills root', () {
        final emptyDetection = installer.detect();
        expect(emptyDetection.status, HarnessSkillStatus.notInstalled);
        expect(emptyDetection.message, isNull);

        Directory(skillsRoot).createSync(recursive: true);
        final rootOnlyDetection = installer.detect();
        expect(rootOnlyDetection.status, HarnessSkillStatus.notInstalled);
        expect(rootOnlyDetection.message, isNull);
      });

      test('installs and detects installed with byte-equal files', () {
        final bundle = _FakeBundledSkillLoader.makeBundle();
        final result = installer.install();
        expect(result, isA<Success<void>>());

        final detection = installer.detect();
        expect(detection.status, HarnessSkillStatus.installed);
        expect(detection.message, isNull);

        expect(
          File(p.join(skillDir, 'SKILL.md')).readAsBytesSync(),
          bundle.files['SKILL.md'],
        );
        expect(
          File(p.join(skillDir, 'references', 'flow.md')).readAsBytesSync(),
          bundle.files['references/flow.md'],
        );

        final sidecar = HiveSkillSidecar.tryParse(
          File(p.join(skillDir, HiveSkillSidecar.fileName)).readAsStringSync(),
        );
        expect(sidecar, isNotNull);
        expect(sidecar!.appVersion, '9.9.9');
        expect(sidecar.contentHash, bundle.contentHash);
      });

      test('detects outdated when bundle changes, ignores appVersion only', () {
        expect(installer.install(), isA<Success<void>>());

        final sameContentDifferentVersion = loc.makeInstaller(
          paths,
          loader,
          '10.0.0',
        );
        expect(
          sameContentDifferentVersion.detect().status,
          HarnessSkillStatus.installed,
        );

        loader.result = Success(
          _FakeBundledSkillLoader.makeBundle(skillMd: '# Agentic Hive\n\nv2\n'),
        );
        final outdated = installer.detect();
        expect(outdated.status, HarnessSkillStatus.outdated);
        expect(outdated.message, contains('9.9.9'));
      });

      test('detects modified on edit, add, delete, and wins over outdated', () {
        expect(installer.install(), isA<Success<void>>());

        // (a) rewrite SKILL.md
        File(p.join(skillDir, 'SKILL.md')).writeAsStringSync('edited\n');
        expect(installer.detect().status, HarnessSkillStatus.modified);

        // modified AND outdated -> modified wins
        loader.result = Success(
          _FakeBundledSkillLoader.makeBundle(skillMd: '# Agentic Hive\n\nv2\n'),
        );
        expect(installer.detect().status, HarnessSkillStatus.modified);

        // restore and test (b) add extra.md
        loader.result = Success(_FakeBundledSkillLoader.makeBundle());
        expect(
          installer.install(overwriteModified: true),
          isA<Success<void>>(),
        );
        File(p.join(skillDir, 'extra.md')).writeAsStringSync('extra\n');
        expect(installer.detect().status, HarnessSkillStatus.modified);

        // restore and test (c) delete SKILL.md
        expect(
          installer.install(overwriteModified: true),
          isA<Success<void>>(),
        );
        File(p.join(skillDir, 'SKILL.md')).deleteSync();
        expect(installer.detect().status, HarnessSkillStatus.modified);
      });

      test('detects conflict for foreign folder, bad sidecar, or file', () {
        // foreign folder without sidecar
        Directory(skillDir).createSync(recursive: true);
        File(p.join(skillDir, 'SKILL.md')).writeAsStringSync('foreign\n');
        final noSidecar = installer.detect();
        expect(noSidecar.status, HarnessSkillStatus.conflict);
        expect(
          noSidecar.message,
          'A skill named agentic-hive already exists here and was not '
          'installed by Agentic Hive.',
        );

        // corrupt sidecar
        File(p.join(skillDir, HiveSkillSidecar.fileName))
            .writeAsStringSync('not json');
        expect(installer.detect().status, HarnessSkillStatus.conflict);

        // sidecar missing contentHash
        File(p.join(skillDir, HiveSkillSidecar.fileName))
            .writeAsStringSync('{"schemaVersion": 1, "appVersion": "1.0.0"}');
        expect(installer.detect().status, HarnessSkillStatus.conflict);

        // regular file at skill path
        Directory(skillDir).deleteSync(recursive: true);
        File(skillDir).writeAsStringSync('not a dir\n');
        expect(installer.detect().status, HarnessSkillStatus.conflict);
      });

      test('detects conflict for symlinks (foreign, our-target, dangling)', () {
        Directory(skillsRoot).createSync(recursive: true);
        final otherDir = Directory(p.join(home, 'other-skill'))
          ..createSync(recursive: true);
        File(p.join(otherDir.path, 'SKILL.md')).writeAsStringSync('other\n');

        try {
          Link(skillDir).createSync(otherDir.path);
        } on FileSystemException {
          markTestSkipped('symlink not permitted');
          return;
        }
        expect(installer.detect().status, HarnessSkillStatus.conflict);

        // symlink pointing to a folder with our valid sidecar -> still conflict
        Link(skillDir).deleteSync();
        final validCopy = Directory(p.join(home, 'valid-copy'))
          ..createSync(recursive: true);
        File(p.join(validCopy.path, 'SKILL.md')).writeAsStringSync('v1\n');
        File(p.join(validCopy.path, HiveSkillSidecar.fileName))
            .writeAsStringSync(
              HiveSkillSidecar(
                appVersion: '9.9.9',
                contentHash: _FakeBundledSkillLoader.makeBundle().contentHash,
              ).encode(),
            );
        Link(skillDir).createSync(validCopy.path);
        expect(installer.detect().status, HarnessSkillStatus.conflict);

        // dangling symlink -> conflict
        Link(skillDir).deleteSync();
        Link(skillDir).createSync(p.join(home, 'does-not-exist'));
        expect(installer.detect().status, HarnessSkillStatus.conflict);
      });

      test(
        'detects unknown on unreadable sidecar, bundle failure, missing home',
        () {
          // sidecar is a directory
          Directory(p.join(skillDir, HiveSkillSidecar.fileName))
              .createSync(recursive: true);
          expect(installer.detect().status, HarnessSkillStatus.unknown);

          // bundle failure while installed folder is valid
          Directory(skillDir).deleteSync(recursive: true);
          expect(installer.install(), isA<Success<void>>());
          loader.result = const FailureResult(
            NotFoundFailure('Bundled skills missing.'),
          );
          final bundleFail = installer.detect();
          expect(bundleFail.status, HarnessSkillStatus.unknown);
          expect(bundleFail.message, 'Bundled skills missing.');

          // homeDir throws StateError
          final emptyEnvPaths = platformPathsFor(
            Platform.operatingSystem,
            environment: const {},
          );
          final noHomeInstaller = loc.makeInstaller(
            emptyEnvPaths,
            loader,
            '1.0.0',
          );
          expect(noHomeInstaller.detect().status, HarnessSkillStatus.unknown);
        },
      );

      test(
        'detects unknown on chmod 000 skill folder',
        skip: Platform.isWindows ? 'chmod is not available' : false,
        () {
          expect(installer.install(), isA<Success<void>>());
          Process.runSync('chmod', ['000', skillDir]);
          addTearDown(() => Process.runSync('chmod', ['755', skillDir]));
          expect(installer.detect().status, HarnessSkillStatus.unknown);
        },
      );

      test('install is idempotent and leaves no staging/old siblings', () {
        expect(installer.install(), isA<Success<void>>());
        final sidecarFile = File(p.join(skillDir, HiveSkillSidecar.fileName));
        final firstBytes = sidecarFile.readAsStringSync();

        expect(installer.install(), isA<Success<void>>());
        expect(sidecarFile.readAsStringSync(), firstBytes);

        final siblings = Directory(skillsRoot)
            .listSync()
            .map((e) => p.basename(e.path))
            .toList();
        expect(siblings, [agenticHiveSkillName]);
      });

      test(
        'update on outdated removes stale files and leaves no leftovers',
        () {
          loader.result = Success(
            _FakeBundledSkillLoader.makeBundle(
              extraFiles: {'stale.md': utf8.encode('stale\n')},
            ),
          );
          expect(installer.install(), isA<Success<void>>());
          expect(File(p.join(skillDir, 'stale.md')).existsSync(), isTrue);

          loader.result = Success(
            _FakeBundledSkillLoader.makeBundle(
              skillMd: '# Agentic Hive\n\nv2\n',
            ),
          );
          expect(installer.install(), isA<Success<void>>());
          expect(installer.detect().status, HarnessSkillStatus.installed);
          expect(File(p.join(skillDir, 'stale.md')).existsSync(), isFalse);
          final siblings = Directory(skillsRoot)
              .listSync()
              .map((e) => p.basename(e.path))
              .toList();
          expect(siblings, [agenticHiveSkillName]);
        },
      );

      test('modified requires overwriteModified: true', () {
        expect(installer.install(), isA<Success<void>>());
        final skillMd = File(p.join(skillDir, 'SKILL.md'))
          ..writeAsStringSync('hand edited\n');

        final blocked = installer.install();
        expect(
          blocked,
          isA<FailureResult<void>>().having(
            (r) => r.failure,
            'failure',
            isA<ConflictFailure>(),
          ),
        );
        expect(skillMd.readAsStringSync(), 'hand edited\n');

        expect(
          installer.install(overwriteModified: true),
          isA<Success<void>>(),
        );
        expect(installer.detect().status, HarnessSkillStatus.installed);
      });

      test('install and remove refuse foreign folder, symlink, and file', () {
        // foreign folder
        Directory(skillDir).createSync(recursive: true);
        final foreignFile = File(p.join(skillDir, 'SKILL.md'))
          ..writeAsStringSync('foreign\n');
        expect(
          installer.install(),
          isA<FailureResult<void>>().having(
            (r) => r.failure,
            'failure',
            isA<ConflictFailure>(),
          ),
        );
        expect(
          installer.remove(),
          isA<FailureResult<void>>().having(
            (r) => r.failure,
            'failure',
            isA<ConflictFailure>(),
          ),
        );
        expect(foreignFile.readAsStringSync(), 'foreign\n');

        // file at skill path
        Directory(skillDir).deleteSync(recursive: true);
        File(skillDir).writeAsStringSync('plain file\n');
        expect(
          installer.install(),
          isA<FailureResult<void>>().having(
            (r) => r.failure,
            'failure',
            isA<ConflictFailure>(),
          ),
        );
        expect(
          installer.remove(),
          isA<FailureResult<void>>().having(
            (r) => r.failure,
            'failure',
            isA<ConflictFailure>(),
          ),
        );
        expect(File(skillDir).readAsStringSync(), 'plain file\n');
      });

      test('remove deletes only agentic-hive and preserves siblings', () {
        expect(installer.install(), isA<Success<void>>());
        final siblingDir = Directory(p.join(skillsRoot, 'other-skill'))
          ..createSync(recursive: true);
        final siblingFile = File(p.join(siblingDir.path, 'SKILL.md'))
          ..writeAsStringSync('other\n');
        final rootFile = File(p.join(skillsRoot, 'notes.txt'))
          ..writeAsStringSync('keep\n');

        expect(installer.remove(), isA<Success<void>>());
        expect(Directory(skillDir).existsSync(), isFalse);
        expect(siblingFile.existsSync(), isTrue);
        expect(rootFile.existsSync(), isTrue);

        // remove on not_installed is a no-op Success
        expect(installer.remove(), isA<Success<void>>());
      });

      test('remove succeeds on modified and outdated, fails on unknown', () {
        expect(installer.install(), isA<Success<void>>());
        File(p.join(skillDir, 'SKILL.md')).writeAsStringSync('edited\n');
        expect(installer.remove(), isA<Success<void>>());
        expect(installer.detect().status, HarnessSkillStatus.notInstalled);

        expect(installer.install(), isA<Success<void>>());
        loader.result = Success(
          _FakeBundledSkillLoader.makeBundle(skillMd: '# v2\n'),
        );
        expect(installer.remove(), isA<Success<void>>());

        // unknown -> ConflictFailure
        Directory(p.join(skillDir, HiveSkillSidecar.fileName))
            .createSync(recursive: true);
        expect(
          installer.remove(),
          isA<FailureResult<void>>().having(
            (r) => r.failure,
            'failure',
            isA<ConflictFailure>(),
          ),
        );
      });

      test('rejects bundle files with .. traversal', () {
        final badFiles = <String, List<int>>{
          'SKILL.md': utf8.encode('# ok\n'),
          '../escape.md': utf8.encode('bad\n'),
        };
        loader.result = Success(
          BundledSkill(
            name: agenticHiveSkillName,
            files: badFiles,
            contentHash: computeSkillContentHash(badFiles),
          ),
        );

        final result = installer.install();
        expect(
          result,
          isA<FailureResult<void>>().having(
            (r) => r.failure,
            'failure',
            isA<ValidationFailure>(),
          ),
        );
        expect(Directory(home).listSync(), isEmpty);
      });
    });
  }

  test('Codex and Gemini CLI share one copy on disk', () {
    final home = createTempHome();
    final paths = tempPaths(home);
    final loader = _FakeBundledSkillLoader(
      Success(_FakeBundledSkillLoader.makeBundle()),
    );
    final shared = SharedAgentsSkillInstaller(
      platformPaths: paths,
      bundledSkillLoader: loader,
      appVersion: '1.0.0',
    );
    final registry = HarnessSkillInstallerRegistry([shared]);

    expect(registry[HarnessId.codex]!.install(), isA<Success<void>>());
    expect(
      registry[HarnessId.geminiCli]!.detect().status,
      HarnessSkillStatus.installed,
    );

    expect(registry[HarnessId.geminiCli]!.remove(), isA<Success<void>>());
    expect(
      registry[HarnessId.codex]!.detect().status,
      HarnessSkillStatus.notInstalled,
    );
  });
}
