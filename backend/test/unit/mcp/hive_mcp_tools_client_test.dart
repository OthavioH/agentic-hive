import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/mcp/hive_mcp_socket_client.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_tools_client.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('HiveMcpToolsClient', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('hive_tools_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('no socket answers not running', () async {
      const client = HiveMcpToolsClient(socket: null, cwd: '/x');

      final r = await client.callTool('list_workflows', const {});

      expect(r.isError, isTrue);
      expect(r.message, HiveMcpToolsClient.notRunningMessage);
    });

    test('missing socket file answers not running', () async {
      final client = HiveMcpToolsClient(
        socket: HiveMcpSocketClient(socketPath: p.join(tmp.path, 'no.sock')),
        cwd: '/x',
      );

      final r = await client.callTool('list_workflows', const {});

      expect(r.isError, isTrue);
      expect(r.message, HiveMcpToolsClient.notRunningMessage);
    });

    Future<HttpServer> serve(
      int status,
      String body,
      void Function(String path, String requestBody) onRequest,
    ) async {
      final path = p.join(tmp.path, 'b.sock');
      final server = await HttpServer.bind(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      );
      server.listen((req) async {
        final text = await utf8.decoder.bind(req).join();
        onRequest(req.uri.path, text);
        req.response
          ..statusCode = status
          ..write(body);
        await req.response.close();
      });
      addTearDown(() => server.close(force: true));
      return server;
    }

    test('forwards name, arguments and cwd and returns text', () async {
      String? seenPath;
      String? seenBody;
      await serve(200, jsonEncode({'text': 'hello'}), (path, body) {
        seenPath = path;
        seenBody = body;
      });
      final client = HiveMcpToolsClient(
        socket: HiveMcpSocketClient(socketPath: p.join(tmp.path, 'b.sock')),
        cwd: '/work',
      );

      final r = await client.callTool('get_workflow', {'id': 'a'});

      expect(r.isError, isFalse);
      expect(r.message, 'hello');
      expect(seenPath, '/api/v1/internal/mcp/tools/get_workflow');
      expect(jsonDecode(seenBody!), {
        'arguments': {'id': 'a'},
        'cwd': '/work',
      });
    });

    test('backend ApiError message is passed through', () async {
      await serve(
        404,
        jsonEncode({
          'error': {'code': 'not_found', 'message': 'Nope.'},
        }),
        (_, _) {},
      );
      final client = HiveMcpToolsClient(
        socket: HiveMcpSocketClient(socketPath: p.join(tmp.path, 'b.sock')),
        cwd: '/work',
      );

      final r = await client.callTool('get_workflow', const {});

      expect(r.isError, isTrue);
      expect(r.message, 'Nope.');
    });
  });
}
