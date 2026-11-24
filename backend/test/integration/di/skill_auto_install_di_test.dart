import 'dart:io';

import 'package:agentic_hive_backend/src/backend.dart';
import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/di/dependencies.dart';
import 'package:agentic_hive_backend/src/domain/skills/skill_auto_install_service.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../persistence/support/persistence_harness.dart';

void main() {
  test(
    'registerDependencies leaves SkillAutoInstallService unstarted (R13)',
    () async {
      final dataDir = createTestDir();
      final homeDir = createTestDir();
      final config = AppConfig(
        mode: RuntimeMode.development,
        dataDir: dataDir.path,
      );
      Directory(config.agentsDir).createSync(recursive: true);

      final console = File(p.join(dataDir.path, 'console.log')).openWrite();
      addTearDown(console.close);

      final di = GetIt.asNewInstance();
      addTearDown(di.reset);

      final paths = platformPathsFor(
        Platform.operatingSystem,
        environment: {
          'HOME': homeDir.path,
          'USERPROFILE': homeDir.path,
          'LOCALAPPDATA': homeDir.path,
        },
      );

      await registerDependencies(
        di,
        config: config,
        platformPaths: paths,
        startedAt: DateTime.now().toUtc(),
        consoleOut: console,
      );

      expect(di<SkillAutoInstallService>().isStarted, isFalse);
    },
  );

  test('Backend.start defaults enableSkillAutoInstall to false', () async {
    final dataDir = createTestDir();
    final homeDir = createTestDir();
    final config = AppConfig(
      mode: RuntimeMode.development,
      dataDir: dataDir.path,
    );
    final paths = platformPathsFor(
      Platform.operatingSystem,
      environment: {
        'HOME': homeDir.path,
        'USERPROFILE': homeDir.path,
        'LOCALAPPDATA': homeDir.path,
      },
    );
    final di = GetIt.asNewInstance();
    final backend = await Backend.start(
      config: config,
      platformPaths: paths,
      di: di,
    );
    addTearDown(backend.stop);

    expect(di<SkillAutoInstallService>().isStarted, isFalse);
  });
}
