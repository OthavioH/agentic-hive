import 'dart:async';

import 'package:agentic_hive_backend/src/mcp/hive_mcp_server.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_socket_client.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_tools_client.dart';
import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:test/test.dart';

final class _FakeForwarder implements HiveMcpToolForwarder {
  new(this.response);

  BackendToolCallResponse response;
  String? name;
  Map<String, Object?>? arguments;

  @override
  Future<BackendToolCallResponse> callTool(
    String name,
    Map<String, Object?> arguments,
  ) async {
    this.name = name;
    this.arguments = arguments;
    return response;
  }
}

void main() {
  late _FakeForwarder forwarder;
  late ServerConnection connection;
  late InitializeResult init;

  setUp(() async {
    forwarder = _FakeForwarder(
      const BackendToolCallResponse(isError: false, message: 'ok text'),
    );
    final clientToServer = StreamController<List<int>>();
    final serverToClient = StreamController<List<int>>();
    final server = HiveMcpServer(
      stdioChannel(input: clientToServer.stream, output: serverToClient.sink),
      client: null,
      tools: forwarder,
    );
    addTearDown(server.shutdown);
    final client = MCPClient(
      Implementation(name: 'test-client', version: '0.1.0'),
    );
    connection = client.connectServer(
      stdioChannel(input: serverToClient.stream, output: clientToServer.sink),
    );
    addTearDown(connection.shutdown);
    init = await connection.initialize(
      InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: ClientCapabilities(),
        clientInfo: Implementation(name: 'test-client', version: '0.1.0'),
      ),
    );
  });

  test('lists the run tools and the three workflow tools', () async {
    final tools = await connection.listTools();

    expect(
      tools.tools.map((t) => t.name),
      containsAll([
        'report_result',
        'ask_human',
        'list_workspaces',
        'list_workflows',
        'get_workflow',
      ]),
    );
  });

  test('get_workflow schema has the detail enum and requires id', () async {
    final tools = await connection.listTools();
    final tool = tools.tools.singleWhere((t) => t.name == 'get_workflow');
    final schema = tool.inputSchema;

    expect(schema.required, ['id']);
    expect(schema.additionalProperties, isFalse);
    expect(schema.properties!['detail'], isA<EnumSchema>());
  });

  test('instructions are the R11 text', () {
    expect(
      init.instructions,
      'Manage Agentic Hive workflows only through these tools, never by '
      'editing workspace workflow files. Workflow tools take an optional '
      'workspace (id, root path or "global"); report_result and ask_human '
      'work only inside a run.',
    );
  });

  test('forwards a workflow tool call to the forwarder', () async {
    final r = await connection.callTool(
      CallToolRequest(name: 'get_workflow', arguments: {'id': 'a'}),
    );

    expect(r.isError, isNot(true));
    expect((r.content.single as TextContent).text, 'ok text');
    expect(forwarder.name, 'get_workflow');
    expect(forwarder.arguments, {'id': 'a'});
  });

  test('forwarder error becomes isError', () async {
    forwarder.response = const BackendToolCallResponse(
      isError: true,
      message: 'bad',
    );

    final r = await connection.callTool(
      CallToolRequest(name: 'list_workflows'),
    );

    expect(r.isError, isTrue);
    expect((r.content.single as TextContent).text, 'bad');
  });
}
