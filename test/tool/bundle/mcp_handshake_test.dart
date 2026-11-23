import 'dart:convert';

import 'package:test/test.dart';

import '../../../tool/src/bundle/mcp_handshake.dart';

void main() {
  group('mcpInitializeRequestLine', () {
    test('builds a single-line JSON-RPC initialize request', () {
      final line = mcpInitializeRequestLine();

      expect(line, isNot(contains('\n')));
      final decoded = jsonDecode(line) as Map<String, Object?>;
      expect(decoded['jsonrpc'], '2.0');
      expect(decoded['id'], mcpInitializeRequestId);
      expect(decoded['method'], 'initialize');
      final params = decoded['params']! as Map<String, Object?>;
      expect(params['protocolVersion'], mcpSmokeProtocolVersion);
      final clientInfo = params['clientInfo']! as Map<String, Object?>;
      expect(clientInfo['name'], 'smoke_bundle');
    });
  });

  group('decodeJsonRpcLine', () {
    test('decodes a JSON object line and rejects non-objects or noise', () {
      expect(decodeJsonRpcLine('{"id":1}'), {'id': 1});
      expect(decodeJsonRpcLine('Usage: dartvm ...'), isNull);
      expect(decodeJsonRpcLine('[1]'), isNull);
      expect(decodeJsonRpcLine(''), isNull);
    });
  });

  group('isInitializeReply', () {
    test('matches only messages with the initialize request id', () {
      expect(
        isInitializeReply({
          'jsonrpc': '2.0',
          'id': 1,
          'result': <String, Object?>{},
        }),
        isTrue,
      );
      expect(
        isInitializeReply({
          'jsonrpc': '2.0',
          'id': 2,
          'result': <String, Object?>{},
        }),
        isFalse,
      );
      expect(
        isInitializeReply({
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
        isFalse,
      );
    });
  });

  group('initializeReplyProblem', () {
    test('returns null for a valid initialize reply', () {
      final reply = <String, Object?>{
        'jsonrpc': '2.0',
        'result': <String, Object?>{
          'protocolVersion': '2025-06-18',
          'capabilities': <String, Object?>{
            'tools': <String, Object?>{'listChanged': true},
          },
          'serverInfo': <String, Object?>{
            'name': 'hive-mcp',
            'version': '0.1.0',
          },
          'instructions': '...',
        },
        'id': 1,
      };

      expect(initializeReplyProblem(reply), isNull);
    });

    test('reports JSON-RPC error details', () {
      final reply = <String, Object?>{
        'jsonrpc': '2.0',
        'id': 1,
        'error': <String, Object?>{'code': -32602, 'message': 'bad version'},
      };

      expect(initializeReplyProblem(reply), contains('bad version'));
    });

    test('reports missing protocolVersion in result', () {
      final reply = <String, Object?>{
        'jsonrpc': '2.0',
        'id': 1,
        'result': <String, Object?>{},
      };

      expect(initializeReplyProblem(reply), contains('protocolVersion'));
    });
  });
}
