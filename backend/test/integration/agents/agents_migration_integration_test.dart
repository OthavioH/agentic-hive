@Timeout(Duration(seconds: 60))
library;

import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';

void main() {
  late Directory root;
  late String dataDir;
  late String targetDir;

  setUp(() async {
    root = await createTempDir();
    dataDir = p.join(root.path, 'd');
    targetDir = p.join(root.path, 'lib');
    final legacy = Directory(p.join(dataDir, 'agents'))
      ..createSync(recursive: true);
    Directory(targetDir).createSync(recursive: true);
    File(p.join(legacy.path, 'a.md')).writeAsStringSync('old');
    File(p.join(targetDir, 'a.md')).writeAsStringSync('new');
  });

  Future<Backend> start() async {
    final di = GetIt.asNewInstance();
    final backend = await Backend.start(
      config: AppConfig(
        mode: RuntimeMode.development,
        dataDir: dataDir,
        agentsDir: targetDir,
      ),
      di: di,
      consoleOut: discardingSink(),
    ).timeout(ioTimeout);
    return backend;
  }

  test('conflicts of the agents move are reported and the dismissal '
      'survives a restart', () async {
    var backend = await start();
    var http = SocketHttpClient(backend.socketPath);
    final first = await http.get('/api/v1/agent-library/migration');
    expect(first.statusCode, 200);
    final status = AgentsMigrationStatus.fromJson(first.json);
    expect(status.conflicts, ['a.md']);
    expect(status.targetDir, targetDir);
    expect(status.hasPendingConflicts, isTrue);

    final dismissed = await http.post(
      '/api/v1/agent-library/migration/dismiss',
    );
    expect(dismissed.statusCode, 200);
    http.close();
    await backend.stop();

    backend = await start();
    addTearDown(backend.stop);
    http = SocketHttpClient(backend.socketPath);
    addTearDown(http.close);
    final again = await http.get('/api/v1/agent-library/migration');
    final after = AgentsMigrationStatus.fromJson(again.json);
    expect(after.conflicts, ['a.md']);
    expect(after.hasPendingConflicts, isFalse);
  });
}
