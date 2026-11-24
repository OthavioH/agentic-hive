import 'dart:io';

import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/db/database_health_check.dart';
import 'package:agentic_hive_backend/src/di/dependencies.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/persistence_harness.dart';

void main() {
  test(
    'registerDependencies creates hive.db in the data dir and reset() closes '
    'it',
    () async {
      final dataDir = createTestDir();
      final dbFile = databaseFileIn(dataDir);
      final console = File(p.join(dataDir.path, 'console.log')).openWrite();
      addTearDown(console.close);

      final di = GetIt.asNewInstance();
      var resetDone = false;
      addTearDown(() async {
        if (!resetDone) await di.reset();
      });

      await registerDependencies(
        di,
        config: AppConfig(mode: RuntimeMode.development, dataDir: dataDir.path),
        platformPaths: currentPlatformPaths(),
        startedAt: DateTime.now().toUtc(),
        consoleOut: console,
      );

      expect(dbFile.existsSync(), isTrue);
      expect(di<AppDatabase>().schemaVersion, 9);
      final status = await di<DatabaseHealthCheck>().check();
      expect(status.ok, isTrue);

      await di.reset();
      resetDone = true;

      // Read the file through a separate connection.
      expect(await readUserVersion(dbFile), 9);
      expect(
        (await readMetadataRows(dbFile)).keys,
        contains(AppDatabase.installedAtKey),
      );

      // On Windows an open SQLite handle blocks deletion, so this only
      // succeeds when reset() closed the database.
      dbFile.deleteSync();
      expect(dbFile.existsSync(), isFalse);
    },
  );
}
