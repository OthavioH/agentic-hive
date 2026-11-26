import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';
import 'support/mcp_stdio_client.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await createTempDir();
  });

  Future<McpStdioClient> spawn({
    required String socket,
    required String workingDirectory,
  }) async {
    // Run the script by absolute path so it resolves the backend package
    // even though the working directory is the user's folder.
    final scriptPath = p.join(Directory.current.path, 'bin', 'hive_mcp.dart');
    final process = await Process.start(
      Platform.resolvedExecutable,
      <String>['run', scriptPath, '--socket', socket],
      workingDirectory: workingDirectory,
      environment: const <String, String>{
        'HIVE_RUN_ID': '',
        'HIVE_NODE_ID': '',
        'HIVE_ATTEMPT': '',
      },
    );
    final client = McpStdioClient(process);
    addTearDown(client.close);
    await client.sendRequest('initialize', <String, Object?>{
      'protocolVersion': '2025-03-26',
      'capabilities': <String, Object?>{},
      'clientInfo': <String, Object?>{'name': 'test-client', 'version': '1.0'},
    });
    await client.sendNotification('notifications/initialized');
    return client;
  }

  Future<({bool isError, String text})> call(
    McpStdioClient mcp,
    String name, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    final response = await mcp.sendRequest('tools/call', <String, Object?>{
      'name': name,
      'arguments': arguments,
    });
    final result = response['result']! as Map<String, Object?>;
    final content = (result['content']! as List<Object?>)
        .cast<Map<String, Object?>>();
    return (
      isError: result['isError'] == true,
      text: content.single['text']! as String,
    );
  }

  test('outside a run: lists node types and the scope agents with workspace '
      'overrides', () async {
    final dataDir = p.join(tempDir.path, 'data');
    final wsDir = p.join(tempDir.path, 'ws');
    await Directory(wsDir).create(recursive: true);
    final di = GetIt.asNewInstance();
    final backend = await Backend.start(
      config: configFor(dataDir),
      di: di,
      consoleOut: discardingSink(),
    ).timeout(ioTimeout);
    addTearDown(() => backend.stop().timeout(ioTimeout));

    final workspace = switch (await di<WorkspaceService>().create(
      CreateWorkspaceRequest(rootPath: wsDir, name: 'ws'),
    )) {
      Success(:final value) => value,
      FailureResult(:final failure) => fail('workspace: $failure'),
    };
    final agents = di<AgentService>();
    for (final request in [
      const CreateAgentRequest(id: 'reviewer', name: 'Reviewer', prompt: 'g'),
      const CreateAgentRequest(id: 'planner', name: 'Planner', prompt: 'p'),
    ]) {
      switch (await agents.create(request)) {
        case FailureResult(:final failure):
          fail('global agent ${request.id}: $failure');
        case Success():
      }
    }
    switch (await agents.create(
      const CreateAgentRequest(
        id: 'team-reviewer',
        name: 'Reviewer',
        prompt: 'w',
      ),
      scope: WorkspaceScope(workspace.id),
    )) {
      case FailureResult(:final failure):
        fail('workspace agent: $failure');
      case Success():
    }

    final mcp = await spawn(
      socket: backend.socketPath,
      workingDirectory: wsDir,
    );

    final scoped = await call(mcp, 'list_building_blocks');
    expect(scoped.isError, isFalse);
    expect(scoped.text, startsWith('Scope: workspace "ws"'));
    expect(scoped.text, contains('from the current directory'));
    expect(
      scoped.text,
      contains('- validator.review -> approved|changesRequested'),
    );
    expect(scoped.text, contains('- team-reviewer "Reviewer" (workspace)'));
    expect(scoped.text, contains('- planner "Planner" (global)'));
    expect(scoped.text, isNot(contains('- reviewer "Reviewer"')));

    final global = await call(mcp, 'list_building_blocks', <String, Object?>{
      'workspace': 'global',
    });
    expect(global.isError, isFalse);
    expect(global.text, contains('- reviewer "Reviewer" (global)'));
    expect(global.text, isNot(contains('team-reviewer')));
  });
}
