import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../http/support/harness.dart';

/// Minimal JSON-RPC client over the stdio of a spawned `hive-mcp` process.
final class McpStdioClient {
  /// Wraps [_process].
  new(this._process) {
    _lines = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();
  }

  final Process _process;
  late final Stream<String> _lines;
  int _nextId = 1;

  Future<Map<String, Object?>> sendRequest(
    String method, [
    Map<String, Object?>? params,
  ]) async {
    final id = _nextId++;
    final payload = <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': ?params,
    };
    _process.stdin.writeln(jsonEncode(payload));
    await _process.stdin.flush();

    final line = await _lines
        .firstWhere((raw) {
          if (raw.trim().isEmpty) return false;
          final decoded = jsonDecode(raw);
          return decoded is Map<String, Object?> && decoded['id'] == id;
        })
        .timeout(ioTimeout);
    return jsonDecode(line) as Map<String, Object?>;
  }

  Future<void> sendNotification(
    String method, [
    Map<String, Object?>? params,
  ]) async {
    final payload = <String, Object?>{
      'jsonrpc': '2.0',
      'method': method,
      'params': ?params,
    };
    _process.stdin.writeln(jsonEncode(payload));
    await _process.stdin.flush();
  }

  Future<void> close() async {
    await _process.stdin.close();
    _process.kill();
    await _process.exitCode.timeout(ioTimeout);
  }
}
