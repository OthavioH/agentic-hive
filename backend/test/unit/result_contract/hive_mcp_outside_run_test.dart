import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/mcp/hive_mcp_server.dart';
import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('HiveMcpServer outside a run', () {
    test('exposes tools and returns isError when client is null', () async {
      final clientToServer = StreamController<List<int>>();
      final serverToClient = StreamController<List<int>>();
      final serverChannel = stdioChannel(
        input: clientToServer.stream,
        output: serverToClient.sink,
      );
      final clientChannel = stdioChannel(
        input: serverToClient.stream,
        output: clientToServer.sink,
      );

      final server = HiveMcpServer(serverChannel, client: null);
      addTearDown(server.shutdown);

      final client = MCPClient(
        Implementation(name: 'test-client', version: '0.1.0'),
      );
      final connection = client.connectServer(clientChannel);
      addTearDown(connection.shutdown);

      final init = await connection.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test-client', version: '0.1.0'),
        ),
      );
      expect(init.serverInfo.name, 'hive-mcp');

      final toolsResult = await connection.listTools();
      expect(
        toolsResult.tools.map((t) => t.name),
        containsAll(['report_result', 'ask_human']),
      );

      final reportResult = await connection.callTool(
        CallToolRequest(
          name: 'report_result',
          arguments: {'status': 'onSuccess', 'summary': 'Done'},
        ),
      );
      expect(reportResult.isError, isTrue);
      expect(
        (reportResult.content.single as TextContent).text,
        contains('Not running inside an Agentic Hive run'),
      );

      final askResult = await connection.callTool(
        CallToolRequest(name: 'ask_human', arguments: {'question': 'Proceed?'}),
      );
      expect(askResult.isError, isTrue);
      expect(
        (askResult.content.single as TextContent).text,
        contains('Not running inside an Agentic Hive run'),
      );
    });

    test('bin/hive_mcp.dart starts and answers tool calls with isError when '
        'HIVE_* env vars are absent', () async {
      final scriptPath = p.join(Directory.current.path, 'bin', 'hive_mcp.dart');
      final process = await Process.start(
        Platform.resolvedExecutable,
        <String>['run', scriptPath],
        environment: const <String, String>{
          'HIVE_SOCKET_PATH': '',
          'HIVE_RUN_ID': '',
          'HIVE_NODE_ID': '',
          'HIVE_ATTEMPT': '',
        },
      );
      addTearDown(() async {
        await process.stdin.close();
        process.kill();
        await process.exitCode;
      });

      final lines = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();

      Future<Map<String, Object?>> send(
        int id,
        String method, [
        Map<String, Object?>? params,
      ]) async {
        process.stdin.writeln(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'method': method,
            'params': ?params,
          }),
        );
        await process.stdin.flush();
        final raw = await lines
            .firstWhere((line) {
              if (line.trim().isEmpty) return false;
              final decoded = jsonDecode(line);
              return decoded is Map<String, Object?> && decoded['id'] == id;
            })
            .timeout(const Duration(seconds: 15));
        return jsonDecode(raw) as Map<String, Object?>;
      }

      final init = await send(1, 'initialize', {
        'protocolVersion': '2024-11-05',
        'capabilities': <String, Object?>{},
        'clientInfo': {'name': 'probe', 'version': '1.0.0'},
      });
      expect(init['result'], isA<Map<String, Object?>>());

      process.stdin.writeln(
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
      );
      await process.stdin.flush();

      final call = await send(2, 'tools/call', {
        'name': 'report_result',
        'arguments': {'status': 'onSuccess', 'summary': 'ok'},
      });
      final result = call['result']! as Map<String, Object?>;
      expect(result['isError'], isTrue);
    });
  });
}
