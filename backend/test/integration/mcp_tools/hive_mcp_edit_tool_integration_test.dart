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
import 'support/mcp_stdio_client.dart';

void main() {
  late Directory tempDir;

  setUp(() async => tempDir = await createTempDir());

  Future<McpStdioClient> spawn({
    required String socket,
    required String workingDirectory,
  }) async {
    final script = p.join(Directory.current.path, 'bin', 'hive_mcp.dart');
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', script, '--socket', socket],
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

  /// Calls a tool and returns the whole MCP result, `isError` included.
  Future<Map<String, Object?>> callRaw(
    McpStdioClient client,
    String name,
    Map<String, Object?> arguments,
  ) async {
    final response = await client.sendRequest('tools/call', {
      'name': name,
      'arguments': arguments,
    });
    return response['result']! as Map<String, Object?>;
  }

  String textOf(Map<String, Object?> result) =>
      ((result['content']! as List<Object?>).single!
              as Map<String, Object?>)['text']!
          as String;

  Future<String> call(
    McpStdioClient client,
    String name,
    Map<String, Object?> arguments,
  ) async {
    final result = await callRaw(client, name, arguments);
    expect(result['isError'], isNot(true));
    return textOf(result);
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

  test('outside a run: create then edit a global workflow, the app hears the '
      'update', () async {
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
    final created = await call(mcp, 'create_workflow', {
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
      'edges': <Object?>[],
      'entryNodeId': 'plan',
    });
    final match = RegExp(r'Created workflow (\S+) "[^"]*" revision ([0-9a-f]+)')
        .firstMatch(created)!;
    final id = match.group(1)!;
    final revision = match.group(2)!;
    await nextWorkflowEvent(ws, id);

    final edited = await call(mcp, 'edit_workflow', {
      'id': id,
      'revision': revision,
      'workspace': 'global',
      'operations': [
        {'op': 'update_node', 'id': 'plan', 'label': 'Plan the change'},
      ],
    });
    expect(edited, contains('Edited workflow $id'));
    final newRevision = RegExp(r'revision ([0-9a-f]+) \(was ')
        .firstMatch(edited)!
        .group(1)!;
    expect(newRevision, isNot(revision));

    final event = await nextWorkflowEvent(ws, id);
    expect(event.kind, WorkflowChangeKind.updated);
    expect(event.workspaceId, isNull);
    expect(event.workflow?.revision, newRevision);
    expect(
      await call(mcp, 'get_workflow', {'id': id, 'workspace': 'global'}),
      contains('"Plan the change"'),
    );
  });

  test('edit in a workspace rewrites the workflow file', () async {
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
    final created = await call(mcp, 'create_workflow', {
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
      'edges': <Object?>[],
      'entryNodeId': 'plan',
    });
    final revision = RegExp('revision ([0-9a-f]+)')
        .firstMatch(created)!
        .group(1)!;
    await nextWorkflowEvent(ws, 'review-loop');

    await call(mcp, 'edit_workflow', {
      'id': 'review-loop',
      'revision': revision,
      'workspace': workspace.id,
      'operations': [
        {'op': 'update_node', 'id': 'plan', 'label': 'Plan the change'},
      ],
    });

    final file = File(
      p.join(wsDir, '.agentic-hive', 'workflows', 'review-loop.json'),
    );
    expect(file.readAsStringSync(), contains('Plan the change'));
    expect(file.readAsStringSync(), isNot(contains('"label": "Plan"')));
  });

  test('a stale revision is an isError result and nothing changes', () async {
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
    final created = await call(mcp, 'create_workflow', {
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
      'edges': <Object?>[],
      'entryNodeId': 'plan',
    });
    final match = RegExp(r'Created workflow (\S+) "[^"]*" revision ([0-9a-f]+)')
        .firstMatch(created)!;
    final id = match.group(1)!;
    final revision = match.group(2)!;
    await nextWorkflowEvent(ws, id);

    await call(mcp, 'edit_workflow', {
      'id': id,
      'revision': revision,
      'workspace': 'global',
      'operations': [
        {'op': 'update_node', 'id': 'plan', 'label': 'Plan the change'},
      ],
    });
    await nextWorkflowEvent(ws, id);

    final stale = await callRaw(mcp, 'edit_workflow', {
      'id': id,
      'revision': revision,
      'workspace': 'global',
      'operations': [
        {'op': 'update_node', 'id': 'plan', 'label': 'Second try'},
      ],
    });
    expect(stale['isError'], isTrue);
    expect(
      textOf(stale),
      startsWith('Workflow "$id" changed since you read it'),
    );
    expect(
      await call(mcp, 'get_workflow', {'id': id, 'workspace': 'global'}),
      allOf(contains('"Plan the change"'), isNot(contains('Second try'))),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
