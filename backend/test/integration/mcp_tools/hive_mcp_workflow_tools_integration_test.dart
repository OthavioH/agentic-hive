import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';
import 'support/hive_mcp_kernel.dart';
import 'support/mcp_stdio_client.dart';

void main() {
  final hiveMcp = useCompiledHiveMcp();
  late Directory tempDir;

  setUp(() async {
    tempDir = await createTempDir();
  });

  Future<McpStdioClient> spawn({
    required String socket,
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      <String>[hiveMcp(), '--socket', socket],
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

  test('outside a run: lists workspaces, lists workflows and reads one '
      'compactly', () async {
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
    final created = switch (await di<WorkflowService>().createWorkflow(
      CreateWorkflowRequest(name: 'Review loop', workspaceId: workspace.id),
    )) {
      Success(:final value) => value,
      FailureResult(:final failure) => fail('workflow: $failure'),
    };

    final mcp = await spawn(
      socket: backend.socketPath,
      workingDirectory: wsDir,
    );

    final workspaces = await call(mcp, 'list_workspaces');
    expect(workspaces.isError, isFalse);
    expect(workspaces.text, contains('global "Global scope"'));
    expect(workspaces.text, contains('${workspace.id} "ws"'));

    final listed = await call(mcp, 'list_workflows');
    expect(listed.isError, isFalse);
    expect(listed.text, startsWith('Scope: workspace "ws"'));
    expect(listed.text, contains('from the current directory'));
    expect(listed.text, contains(created.workflow.id));

    final read = await call(mcp, 'get_workflow', <String, Object?>{
      'id': created.workflow.id,
    });
    expect(read.isError, isFalse);
    expect(read.text, startsWith('Scope: workspace "ws"'));
    expect(
      read.text,
      contains(
        'Workflow ${created.workflow.id} "Review loop" revision '
        '${created.revision}',
      ),
    );
  });

  test('backend not running gives the short error', () async {
    final mcp = await spawn(
      socket: p.join(tempDir.path, 'missing.sock'),
      workingDirectory: tempDir.path,
    );

    final result = await call(mcp, 'list_workflows');

    expect(result.isError, isTrue);
    expect(
      result.text,
      'Agentic Hive is not running. Start the Agentic Hive app, then call '
      'again.',
    );
  });
}
