import 'dart:io';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
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

  Future<WorkflowDeletedPayload> nextDeletedEvent(
    WsTestClient ws,
    String id,
  ) async {
    while (true) {
      final envelope = await ws.next(timeout: const Duration(seconds: 10));
      if (envelope.type != WsMessageType.workflowDeleted) continue;
      final payload = WorkflowDeletedPayload.fromJson(envelope.payload);
      if (payload.workflowId == id) return payload;
    }
  }

  Future<({String id, String revision})> createGlobal(
    McpStdioClient mcp,
  ) async {
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
    return (id: match.group(1)!, revision: match.group(2)!);
  }

  test('outside a run: create then delete a global workflow, the app hears '
      'the deletion', () async {
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
    final created = await createGlobal(mcp);
    await nextWorkflowEvent(ws, created.id);

    final deleted = await call(mcp, 'delete_workflow', {
      'id': created.id,
      'revision': created.revision,
      'workspace': 'global',
    });
    expect(
      deleted,
      contains('Deleted workflow "${created.id}" and 0 runs (operation '),
    );

    final event = await nextDeletedEvent(ws, created.id);
    expect(event.workflowId, created.id);
    final gone = await callRaw(mcp, 'get_workflow', {
      'id': created.id,
      'workspace': 'global',
    });
    expect(gone['isError'], isTrue);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('deleting a workflow used by a fan-out node lists the referencing '
      'workflow', () async {
    final dataDir = p.join(tempDir.path, 'data');
    final wsDir = p.join(tempDir.path, 'cwd');
    await Directory(wsDir).create(recursive: true);
    final backend = await startBackend(dataDir);
    final mcp = await spawn(
      socket: backend.socketPath,
      workingDirectory: wsDir,
    );

    final unresolved = await call(mcp, 'create_workflow', {
      'name': 'Missing Child Parent',
      'workspace': 'global',
      'nodes': [
        {
          'id': 'plan',
          'type': 'command',
          'label': 'Plan',
          'config': {'command': 'echo'},
        },
        {
          'id': 'fan',
          'type': 'fan_out',
          'label': 'Fan',
          'config': {
            'workflowId': 'does-not-exist',
            'itemsNodeId': 'plan',
            'itemsPath': 'items',
          },
        },
      ],
      'edges': <Object?>[],
      'entryNodeId': 'plan',
    });
    expect(unresolved, contains('unresolved_child_workflow'));

    final child = await createGlobal(mcp);
    await call(mcp, 'create_workflow', {
      'name': 'Fan Parent',
      'workspace': 'global',
      'nodes': [
        {
          'id': 'plan',
          'type': 'command',
          'label': 'Plan',
          'config': {'command': 'echo'},
        },
        {
          'id': 'fan',
          'type': 'fan_out',
          'label': 'Fan',
          'config': {
            'workflowId': child.id,
            'itemsNodeId': 'plan',
            'itemsPath': 'items',
          },
        },
      ],
      'edges': <Object?>[],
      'entryNodeId': 'plan',
    });

    final deleted = await call(mcp, 'delete_workflow', {
      'id': child.id,
      'revision': child.revision,
      'workspace': 'global',
    });
    expect(deleted, contains('Used by fan-out nodes in 1 workflow:'));
    expect(deleted, contains('"Fan Parent"'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a repeated delete answers already deleted', () async {
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
    final created = await createGlobal(mcp);
    await nextWorkflowEvent(ws, created.id);
    await call(mcp, 'delete_workflow', {
      'id': created.id,
      'revision': created.revision,
      'workspace': 'global',
    });
    await nextDeletedEvent(ws, created.id);

    final repeated = await callRaw(mcp, 'delete_workflow', {
      'id': created.id,
      'revision': created.revision,
      'workspace': 'global',
    });

    expect(repeated['isError'], isNot(true));
    expect(textOf(repeated), contains('is already deleted'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test(
    'a stale revision is an isError result and nothing is deleted',
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
      final created = await createGlobal(mcp);
      await nextWorkflowEvent(ws, created.id);

      final stale = await callRaw(mcp, 'delete_workflow', {
        'id': created.id,
        'revision': 'stale',
        'workspace': 'global',
      });

      expect(stale['isError'], isTrue);
      expect(textOf(stale), contains('Call get_workflow to read it again'));
      expect(
        await call(mcp, 'get_workflow', {
          'id': created.id,
          'workspace': 'global',
        }),
        contains('"Review loop"'),
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('the listed delete_workflow schema has no force', () async {
    final dataDir = p.join(tempDir.path, 'data');
    final wsDir = p.join(tempDir.path, 'cwd');
    await Directory(wsDir).create(recursive: true);
    final backend = await startBackend(dataDir);
    final mcp = await spawn(
      socket: backend.socketPath,
      workingDirectory: wsDir,
    );

    final listed = await mcp.sendRequest('tools/list', {});
    final tools =
        (listed['result']! as Map<String, Object?>)['tools']! as List<Object?>;
    final tool = tools.cast<Map<String, Object?>>().singleWhere(
      (item) => item['name'] == 'delete_workflow',
    );
    final schema = tool['inputSchema']! as Map<String, Object?>;

    expect(
      (schema['properties']! as Map<String, Object?>).keys,
      isNot(contains('force')),
    );
    expect(schema['required'], ['id', 'revision']);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
