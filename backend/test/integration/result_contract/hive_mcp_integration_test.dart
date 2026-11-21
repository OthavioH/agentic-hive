import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:agentic_hive_backend/src/data/result_contract/hive_result_contract.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';

final class _McpStdioClient {
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

void main() {
  late Directory tempDir;
  late String workspacePath;
  late GetIt di;
  late Backend backend;

  setUp(() async {
    tempDir = await createTempDir();
    final dataDir = p.join(tempDir.path, 'data');
    workspacePath = p.join(tempDir.path, 'ws');
    await Directory(workspacePath).create(recursive: true);

    di = GetIt.asNewInstance();
    backend = await Backend.start(
      config: configFor(dataDir),
      di: di,
      consoleOut: discardingSink(),
    ).timeout(ioTimeout);
    addTearDown(() => backend.stop().timeout(ioTimeout));
  });

  Future<_McpStdioClient> spawnMcp({
    required String runId,
    required String nodeId,
    required int attempt,
  }) async {
    final scriptPath = p.join(Directory.current.path, 'bin', 'hive_mcp.dart');
    final process = await Process.start(Platform.resolvedExecutable, <String>[
      'run',
      scriptPath,
      '--socket',
      backend.socketPath,
      '--run-id',
      runId,
      '--node-id',
      nodeId,
      '--attempt',
      attempt.toString(),
    ]);
    final client = _McpStdioClient(process);
    addTearDown(client.close);
    return client;
  }

  test('hive-mcp stdio proxy handles initialize, tools/list, report_result, and ask_human', () async {
    final contract = di<ResultContract>() as HiveResultContract;
    final gateway = di<HumanPauseGateway>();

    final session = await contract.openSession(
      NodeExecutionContext(
        runId: 'run-int-1',
        nodeId: 'node-int-1',
        workspacePath: workspacePath,
      ),
    );
    addTearDown(session.dispose);

    final mcp = await spawnMcp(
      runId: 'run-int-1',
      nodeId: 'node-int-1',
      attempt: 1,
    );

    final initResponse = await mcp.sendRequest('initialize', <String, Object?>{
      'protocolVersion': '2025-03-26',
      'capabilities': <String, Object?>{},
      'clientInfo': <String, Object?>{'name': 'test-client', 'version': '1.0'},
    });
    expect(initResponse['error'], isNull);
    await mcp.sendNotification('notifications/initialized');

    final toolsResponse = await mcp.sendRequest('tools/list');
    final toolsResult = toolsResponse['result']! as Map<String, Object?>;
    final tools = (toolsResult['tools']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(
      tools.map((t) => t['name']),
      containsAll(<String>['report_result', 'ask_human']),
    );

    // 1. Invalid report_result -> isError: true (retryable)
    final invalidCall = await mcp.sendRequest('tools/call', <String, Object?>{
      'name': 'report_result',
      'arguments': <String, Object?>{
        'status': 'invalid_status',
        'summary': 'Bad status.',
      },
    });
    final invalidResult = invalidCall['result']! as Map<String, Object?>;
    expect(invalidResult['isError'], isTrue);

    // 2. Valid report_result -> accepted and locked
    final validCall = await mcp.sendRequest('tools/call', <String, Object?>{
      'name': 'report_result',
      'arguments': <String, Object?>{
        'status': 'onSuccess',
        'summary': 'All done via MCP.',
        'data': <String, Object?>{'count': 1},
        'artifacts': <String>['lib/out.dart'],
      },
    });
    final validResult = validCall['result']! as Map<String, Object?>;
    expect(validResult['isError'], isNot(true));

    // 3. Duplicate report_result -> isError: true without overwriting
    final duplicateCall = await mcp.sendRequest('tools/call', <String, Object?>{
      'name': 'report_result',
      'arguments': <String, Object?>{
        'status': 'onFailure',
        'summary': 'Should not overwrite.',
      },
    });
    final duplicateResult = duplicateCall['result']! as Map<String, Object?>;
    expect(duplicateResult['isError'], isTrue);

    final locked = await contract.readReport(
      NodeExecutionContext(
        runId: 'run-int-1',
        nodeId: 'node-int-1',
        workspacePath: workspacePath,
      ),
    );
    expect(locked.valueOrNull?.status, ResultContractStatus.success);
    expect(locked.valueOrNull?.summary, 'All done via MCP.');

    // 4. ask_human -> blocks until human submits answer
    final askFuture = mcp.sendRequest('tools/call', <String, Object?>{
      'name': 'ask_human',
      'arguments': <String, Object?>{
        'question': 'Proceed with deployment?',
        'options': <String>['Yes', 'No'],
      },
    });

    while (gateway.pendingForRun('run-int-1').isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final pauseId = gateway.pendingForRun('run-int-1').single.pauseId;
    gateway.submitAnswer(pauseId: pauseId, answer: 'Yes');

    final askResponse = await askFuture;
    final askResult = askResponse['result']! as Map<String, Object?>;
    expect(askResult['isError'], isNot(true));
    final content = (askResult['content']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(content.single['text'], 'Yes');

    // 5. ask_human -> unblocks with error when run is cancelled
    final cancelledAskFuture = mcp.sendRequest('tools/call', <String, Object?>{
      'name': 'ask_human',
      'arguments': <String, Object?>{'question': 'Still there?'},
    });

    while (gateway.pendingForRun('run-int-1').isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    gateway.cancelRun('run-int-1');

    final cancelledResponse = await cancelledAskFuture;
    final cancelledResult =
        cancelledResponse['result']! as Map<String, Object?>;
    expect(cancelledResult['isError'], isTrue);
  });

  test('rejects internal route requests carrying an Origin header', () async {
    final client = openClient(backend.socketPath);
    final response = await client.post(
      '/api/v1/internal/runs/r1/nodes/n1/attempts/1/report-result',
      headers: const <String, String>{'origin': 'https://evil.example'},
      body: jsonEncode(const <String, Object?>{
        'status': 'onSuccess',
        'summary': 'Blocked.',
      }),
    );

    expect(response.statusCode, 403);
    expect(
      ApiError.fromJson(response.json).code,
      ApiErrorCode.originNotAllowed,
    );
  });
}
