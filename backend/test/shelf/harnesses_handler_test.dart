import 'package:agentic_hive_backend/src/api/harnesses/harnesses_handler.dart';
import 'package:agentic_hive_backend/src/data/harnesses/os_executable_locator.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final startedAt = DateTime.utc(2026, 11, 20, 12);

  late _ScriptedProcessRunner processRunner;
  late DefaultHarnessService harnessService;
  late Handler handler;

  setUp(() {
    processRunner = _ScriptedProcessRunner(
      onRun: (executable, arguments) {
        if (executable == 'which') {
          return switch (arguments.single) {
            'claude' => const ProcessRunResult(
              exitCode: 0,
              stdout: '/usr/local/bin/claude\n',
              stderr: '',
            ),
            'codex' => const ProcessRunResult(
              exitCode: 0,
              stdout: '/usr/local/bin/codex\n',
              stderr: '',
            ),
            'agy' => const ProcessRunResult(
              exitCode: 0,
              stdout: '/usr/local/bin/agy\n',
              stderr: '',
            ),
            _ => const ProcessRunResult(exitCode: 1, stdout: '', stderr: ''),
          };
        }
        return switch (executable) {
          '/usr/local/bin/claude' => const ProcessRunResult(
            exitCode: 0,
            stdout: '2.1.0 (Claude Code)',
            stderr: '',
          ),
          '/usr/local/bin/codex' => const ProcessRunResult(
            exitCode: 1,
            stdout: '',
            stderr: 'Not logged in. Run codex login.',
          ),
          '/usr/local/bin/agy' => const ProcessRunResult(
            exitCode: -1,
            stdout: '',
            stderr: '',
            timedOut: true,
          ),
          _ => const ProcessRunResult(exitCode: 1, stdout: '', stderr: ''),
        };
      },
    );

    final locator = PosixExecutableLocator(processRunner: processRunner);
    harnessService = DefaultHarnessService(
      detectors: [
        ClaudeCodeDetector(
          executableLocator: locator,
          processRunner: processRunner,
        ),
        CodexDetector(executableLocator: locator, processRunner: processRunner),
        GeminiCliDetector(
          executableLocator: locator,
          processRunner: processRunner,
        ),
        AntigravityDetector(
          executableLocator: locator,
          processRunner: processRunner,
        ),
      ],
    );

    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 1),
        ),
        version: '0.1.0',
        dataDir: '/data',
        startedAt: startedAt,
      ),
      webSocketHandler: (_) => Response(418),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      harnessesHandler: HarnessesHandler(harnessService: harnessService),
    );
  });

  tearDown(() => harnessService.dispose());

  test(
    'GET /api/v1/harnesses returns all 4 harnesses and caches them',
    () async {
      final first = await handler(buildRequest('/api/v1/harnesses'));
      expect(first.statusCode, 200);
      final decoded = HarnessListResponse.fromJson(await readJson(first));
      expect(decoded.harnesses.map((h) => (h.id, h.status)), [
        (HarnessId.claudeCode, HarnessStatus.ready),
        (HarnessId.codex, HarnessStatus.authError),
        (HarnessId.geminiCli, HarnessStatus.notInstalled),
        (HarnessId.antigravity, HarnessStatus.unavailable),
      ]);

      final callsAfterFirst = processRunner.calls;
      final second = await handler(buildRequest('/api/v1/harnesses'));
      expect(second.statusCode, 200);
      expect(processRunner.calls, callsAfterFirst);
    },
  );

  test('POST /api/v1/harnesses/refresh re-scans and updates status', () async {
    await handler(buildRequest('/api/v1/harnesses'));

    processRunner.onRun = (executable, arguments) {
      if (executable == 'which') {
        return ProcessRunResult(
          exitCode: 0,
          stdout: '/usr/local/bin/${arguments.single}\n',
          stderr: '',
        );
      }
      return const ProcessRunResult(exitCode: 0, stdout: '3.0.0', stderr: '');
    };

    final response = await handler(
      buildRequest('/api/v1/harnesses/refresh', method: 'POST'),
    );

    expect(response.statusCode, 200);
    final decoded = HarnessListResponse.fromJson(await readJson(response));
    expect(
      decoded.harnesses.every((h) => h.status == HarnessStatus.ready),
      isTrue,
    );
  });

  test('POST /api/v1/harnesses/:id/refresh updates one harness and clears '
      'authError', () async {
    await handler(buildRequest('/api/v1/harnesses'));

    final previousOnRun = processRunner.onRun;
    processRunner.onRun = (executable, arguments) {
      if (executable == '/usr/local/bin/codex') {
        return const ProcessRunResult(
          exitCode: 0,
          stdout: 'codex-cli 0.26.0',
          stderr: '',
        );
      }
      return previousOnRun(executable, arguments);
    };

    final response = await handler(
      buildRequest('/api/v1/harnesses/codex/refresh', method: 'POST'),
    );

    expect(response.statusCode, 200);
    final updated = HarnessInfo.fromJson(await readJson(response));
    expect(updated.id, HarnessId.codex);
    expect(updated.status, HarnessStatus.ready);
    expect(updated.version, '0.26.0');
    expect(updated.errorMessage, isNull);
  });

  test(
    'POST /api/v1/harnesses/:id/refresh returns 404 for unknown id',
    () async {
      final response = await handler(
        buildRequest('/api/v1/harnesses/unknown_cli/refresh', method: 'POST'),
      );

      expect(response.statusCode, 404);
      final requestId = response.headers[requestIdHeader];
      expect(await readJson(response), {
        'error': {
          'code': ApiErrorCode.notFound,
          'message': 'Unknown harness "unknown_cli".',
          'requestId': requestId,
        },
      });
    },
  );

  test('GET /api/v1/harnesses with Origin header returns 403', () async {
    final response = await handler(
      buildRequest(
        '/api/v1/harnesses',
        headers: {'origin': 'https://evil.example'},
      ),
    );

    expect(response.statusCode, 403);
  });
}

final class _ScriptedProcessRunner implements ProcessRunner {
  new({required this.onRun});

  ProcessRunResult Function(String executable, List<String> arguments) onRun;
  int calls = 0;

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) async {
    calls++;
    return onRun(executable, arguments);
  }
}
