import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/theme/app_theme_preference.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_store.dart';
import 'package:agentic_hive_frontend/data/skills/file_outdated_banner_store.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_selection_store_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'test_data_sandbox.dart';

final class _TempPlatformPaths implements PlatformPaths {
  const new(this.dir);

  final String dir;

  @override
  p.Context get context => p.context;

  @override
  String defaultDataDir() => dir;

  @override
  String serverInfoPath() => context.join(dir, 'server.json');
}

final class _RealIO extends IOOverrides;

void main() {
  group('SandboxIOOverrides', () {
    late Directory realDir;
    late Directory sandboxDir;
    late Directory otherDir;
    late SandboxIOOverrides overrides;

    setUp(() {
      realDir = Directory.systemTemp.createTempSync('hive_real_');
      sandboxDir = Directory.systemTemp.createTempSync('hive_sandbox_');
      otherDir = Directory.systemTemp.createTempSync('hive_other_');
      overrides = SandboxIOOverrides(
        dataDir: realDir.path,
        sandboxRoot: sandboxDir.path,
        context: p.context,
      );
    });

    tearDown(() {
      IOOverrides.runWithIOOverrides(() {
        for (final dir in [realDir, sandboxDir, otherDir]) {
          if (dir.existsSync()) {
            dir.deleteSync(recursive: true);
          }
        }
      }, _RealIO());
    });

    test('redirects a file inside the data dir into the sandbox', () {
      IOOverrides.runWithIOOverrides(() {
        File(p.join(realDir.path, 'a.json')).writeAsStringSync('x');
      }, overrides);

      IOOverrides.runWithIOOverrides(() {
        expect(File(p.join(sandboxDir.path, 'a.json')).existsSync(), isTrue);
        expect(File(p.join(realDir.path, 'a.json')).existsSync(), isFalse);
      }, _RealIO());
    });

    test('redirects nested directories into the sandbox', () {
      IOOverrides.runWithIOOverrides(() {
        Directory(p.join(realDir.path, 'n', 'm')).createSync(recursive: true);
      }, overrides);

      IOOverrides.runWithIOOverrides(() {
        expect(
          Directory(p.join(sandboxDir.path, 'n', 'm')).existsSync(),
          isTrue,
        );
        expect(Directory(p.join(realDir.path, 'n')).existsSync(), isFalse);
      }, _RealIO());
    });

    test('redirects the data dir itself', () {
      final redirectedPath = IOOverrides.runWithIOOverrides(
        () => Directory(realDir.path).path,
        overrides,
      );
      expect(redirectedPath, sandboxDir.path);
    });

    test('leaves paths outside the data dir untouched', () {
      IOOverrides.runWithIOOverrides(() {
        File(p.join(otherDir.path, 'b.json')).writeAsStringSync('y');
      }, overrides);

      IOOverrides.runWithIOOverrides(() {
        expect(File(p.join(otherDir.path, 'b.json')).existsSync(), isTrue);
        expect(File(p.join(sandboxDir.path, 'b.json')).existsSync(), isFalse);
      }, _RealIO());
    });

    test('leaves excludedDirs under dataDir untouched while redirecting '
        'siblings', () {
      final worktreesDir = p.join(realDir.path, 'worktrees');
      final scopedOverrides = SandboxIOOverrides(
        dataDir: realDir.path,
        sandboxRoot: sandboxDir.path,
        context: p.context,
        excludedDirs: [worktreesDir],
      );

      final excludedDirPath = IOOverrides.runWithIOOverrides(
        () => Directory(worktreesDir).path,
        scopedOverrides,
      );
      expect(excludedDirPath, worktreesDir);

      IOOverrides.runWithIOOverrides(() {
        Directory(p.join(worktreesDir, 'wt-1')).createSync(recursive: true);
        File(p.join(worktreesDir, 'wt-1', 'f.txt')).writeAsStringSync('wt');
        File(p.join(realDir.path, 'current_workspace.json'))
            .writeAsStringSync('{"workspaceId":"sb"}');
      }, scopedOverrides);

      IOOverrides.runWithIOOverrides(() {
        expect(
          File(p.join(worktreesDir, 'wt-1', 'f.txt')).readAsStringSync(),
          'wt',
        );
        expect(
          File(p.join(sandboxDir.path, 'worktrees', 'wt-1', 'f.txt'))
              .existsSync(),
          isFalse,
        );
        expect(
          File(p.join(sandboxDir.path, 'current_workspace.json')).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(realDir.path, 'current_workspace.json')).existsSync(),
          isFalse,
        );
      }, _RealIO());
    });

    test(
      'FileWorkspaceSelectionStore ignores a real current_workspace.json',
      () async {
        IOOverrides.runWithIOOverrides(() {
          File(p.join(realDir.path, 'current_workspace.json'))
              .writeAsStringSync('{"workspaceId":"real"}');
        }, _RealIO());

        final loaded = await IOOverrides.runWithIOOverrides(
          () =>
              FileWorkspaceSelectionStore(_TempPlatformPaths(realDir.path))
                  .load(),
          overrides,
        );
        expect(loaded, isNull);
      },
    );

    test(
      'FileThemePreferenceStore ignores a real theme_preference.json',
      () async {
        IOOverrides.runWithIOOverrides(() {
          File(p.join(realDir.path, 'theme_preference.json'))
              .writeAsStringSync('{"theme":"light"}');
        }, _RealIO());

        final loaded = await IOOverrides.runWithIOOverrides(
          () =>
              FileThemePreferenceStore(_TempPlatformPaths(realDir.path)).load(),
          overrides,
        );
        expect(loaded, AppThemePreference.dark);
      },
    );

    test(
      'FileOutdatedBannerStore ignores a real skill_outdated_banner.json',
      () async {
        IOOverrides.runWithIOOverrides(() {
          File(p.join(realDir.path, 'skill_outdated_banner.json'))
              .writeAsStringSync('{"acknowledgedVersion":"1.0.0"}');
        }, _RealIO());

        final loaded = await IOOverrides.runWithIOOverrides(
          () =>
              FileOutdatedBannerStore(_TempPlatformPaths(realDir.path))
                  .loadAcknowledgedVersion(),
          overrides,
        );
        expect(loaded, isNull);
      },
    );

    test(
      'save inside the sandbox does not create the real folder file',
      () async {
        await IOOverrides.runWithIOOverrides(
          () =>
              FileWorkspaceSelectionStore(_TempPlatformPaths(realDir.path))
                  .save('ws-1'),
          overrides,
        );

        IOOverrides.runWithIOOverrides(() {
          expect(
            File(p.join(sandboxDir.path, 'current_workspace.json'))
                .existsSync(),
            isTrue,
          );
          expect(
            File(p.join(realDir.path, 'current_workspace.json')).existsSync(),
            isFalse,
          );
        }, _RealIO());
      },
    );
  });

  group('global installation', () {
    test('flutter_test_config installs the sandbox globally', () {
      expect(IOOverrides.current, isA<SandboxIOOverrides>());
    });

    test('the real data folder is invisible and unchanged', () {
      final realPath = p.join(
        currentPlatformPaths().defaultDataDir(),
        'current_workspace.json',
      );
      final real = File(realPath);
      final before = IOOverrides.runWithIOOverrides(
        () => File(realPath).existsSync(),
        _RealIO(),
      );

      expect(real.existsSync(), isFalse);

      real.writeAsStringSync('{"workspaceId":"leak"}');
      try {
        final sandboxRoot =
            (IOOverrides.current! as SandboxIOOverrides).sandboxRoot;
        expect(
          File(p.join(sandboxRoot, 'current_workspace.json')).existsSync(),
          isTrue,
        );
        final after = IOOverrides.runWithIOOverrides(
          () => File(realPath).existsSync(),
          _RealIO(),
        );
        expect(after, before);
      } finally {
        real.deleteSync();
      }
    });

    testWidgets(
      'default stores resolve inside testWidgets without real file I/O',
      (tester) async {
        final container = ProviderContainer.test();
        expect(
          await container.read(workspaceSelectionStoreProvider).load(),
          isNull,
        );
        expect(
          await container.read(themePreferenceStoreProvider).load(),
          AppThemePreference.dark,
        );
        expect(
          await container
              .read(outdatedBannerStoreProvider)
              .loadAcknowledgedVersion(),
          isNull,
        );
      },
    );
  });
}
