import 'dart:io';

import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/di/dependencies.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../persistence/support/persistence_harness.dart';

void main() {
  test('registerDependencies wires a real AgentPromptResolver backed by the '
      'agents directory', () async {
    final dataDir = createTestDir();
    final config = AppConfig(
      mode: RuntimeMode.development,
      dataDir: dataDir.path,
    );
    Directory(config.agentsDir).createSync(recursive: true);
    File(p.join(config.agentsDir, 'codebase-sweeper.md')).writeAsStringSync(
      '---\n'
      'name: Codebase Sweeper\n'
      '---\n'
      'Sweep the codebase for dead code.\n',
    );

    final console = File(p.join(dataDir.path, 'console.log')).openWrite();
    addTearDown(console.close);

    final di = GetIt.asNewInstance();
    addTearDown(di.reset);

    await registerDependencies(
      di,
      config: config,
      platformPaths: currentPlatformPaths(),
      startedAt: DateTime.now().toUtc(),
      consoleOut: console,
    );

    final resolver = di<AgentPromptResolver>();
    final result = await resolver.resolvePrompt('codebase-sweeper');

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, contains('Sweep the codebase for dead code.'));

    // NodeRegistry must also be wired with the working resolver.
    final node = di<NodeRegistry>().create(NodeTypeId.claudeCode);
    expect(node.isSuccess, isTrue);
  });
}
