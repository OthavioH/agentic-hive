import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';
import '../websocket/support/ws_harness.dart';
import 'support/hive_mcp_kernel.dart';
import 'support/mcp_stdio_client.dart';

void main() {
  final hiveMcp = useCompiledHiveMcp();
  late Directory tempDir;

  setUp(() async => tempDir = await createTempDir());

  Future<McpStdioClient> spawn({
    required String socket,
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      [hiveMcp(), '--socket', socket],
      workingDirectory: workingDirectory,
      environment: const {
        'HIVE_RUN_ID': '',
        'HIVE_NODE_ID': '',
        'HIVE_ATTEMPT': '',
      },
    );
    final client = McpStdioClient(process);
    addTearDown(client.close);
    await client.sendRequest('initialize', {
      'protocolVersion': '2025-03-26',
      'capabilities': <String, Object?>{},
      'clientInfo': {'name': 'test-client', 'version': '1.0'},
    });
    await client.sendNotification('notifications/initialized');
    return client;
  }

  Future<String> call(
    McpStdioClient client,
    String name,
    Map<String, Object?> arguments,
  ) async {
    final response = await client.sendRequest('tools/call', {
      'name': name,
      'arguments': arguments,
    });
    final result = response['result']! as Map<String, Object?>;
    expect(result['isError'], isNot(true));
    return ((result['content']! as List<Object?>).single!
            as Map<String, Object?>)['text']!
        as String;
  }

  Future<WorkflowsChangedPayload> nextWorkflowEvent(
    WsTestClient ws,
    String id,
  ) async {
    while (true) {
      final envelope = await ws.next(timeout: const Duration(seconds: 10));
      if (envelope.type != WsMessageType.workflowsChanged) continue;
      final payload = WorkflowsChangedPayload.fromJson(envelope.payload);
      if (payload.id == id) return payload;
    }
  }

  test(
    'outside a run: create and duplicate a global workflow, the app hears both',
    () async {
      final dataDir = p.join(tempDir.path, 'data');
      final wsDir = p.join(tempDir.path, 'cwd');
      await Directory(wsDir).create(recursive: true);
      final backend = await startBackend(dataDir);
      final ws = await WsTestClient.connect(backend.socketPath);
      addTearDown(ws.close);
      expect((await ws.next()).type, WsMessageType.serverHello);
      final mcp = await spawn(
        socket: backend.socketPath,
        workingDirectory: wsDir,
      );
      const args = <String, Object?>{
        'workspace': 'global',
        'name': 'Review loop',
        'nodes': [
          {
            'id': 'plan',
            'type': 'harness.claude_code',
            'label': 'Plan',
            'config': {'agentId': 'planner'},
          },
        ],
        'edges': [],
        'entryNodeId': 'plan',
      };
      final created = await call(mcp, 'create_workflow', args);
      final id = RegExp(r'Created workflow (\S+) ')
          .firstMatch(created)!
          .group(1)!;
      final event = await nextWorkflowEvent(ws, id);
      expect(event.workspaceId, isNull);
      expect(event.workflow?.revision, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(
        await call(mcp, 'get_workflow', {'id': id, 'workspace': 'global'}),
        contains('- plan (harness.claude_code) "Plan"'),
      );
      final copied = await call(mcp, 'duplicate_workflow', {
        'id': id,
        'workspace': 'global',
      });
      final copyId = RegExp(r' as (\S+) ').firstMatch(copied)!.group(1)!;
      expect((await nextWorkflowEvent(ws, copyId)).workspaceId, isNull);
    },
  );

  test(
    'create in a workspace writes the workflow file and the app hears it',
    () async {
      final dataDir = p.join(tempDir.path, 'data');
      final wsDir = p.join(tempDir.path, 'workspace');
      await Directory(wsDir).create(recursive: true);
      final di = GetIt.asNewInstance();
      final backend = await Backend.start(
        config: configFor(dataDir),
        di: di,
        consoleOut: discardingSink(),
      );
      addTearDown(() => backend.stop().timeout(ioTimeout));
      final workspace = switch (await di<WorkspaceService>().create(
        CreateWorkspaceRequest(rootPath: wsDir, name: 'ws'),
      )) {
        Success(:final value) => value,
        FailureResult(:final failure) => fail('workspace: $failure'),
      };
      final ws = await WsTestClient.connect(backend.socketPath);
      addTearDown(ws.close);
      expect((await ws.next()).type, WsMessageType.serverHello);
      final mcp = await spawn(
        socket: backend.socketPath,
        workingDirectory: wsDir,
      );
      await call(mcp, 'create_workflow', {
        'workspace': workspace.id,
        'name': 'Review loop',
        'nodes': [
          {
            'id': 'plan',
            'type': 'harness.claude_code',
            'label': 'Plan',
            'config': {'agentId': 'planner'},
          },
        ],
        'edges': [],
        'entryNodeId': 'plan',
      });
      expect(
        File(p.join(wsDir, '.agentic-hive', 'workflows', 'review-loop.json'))
            .existsSync(),
        isTrue,
      );
      final event = await nextWorkflowEvent(ws, 'review-loop');
      expect(event.workspaceId, workspace.id);
    },
  );
}
