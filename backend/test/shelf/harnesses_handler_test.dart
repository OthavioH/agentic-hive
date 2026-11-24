import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/api/harnesses/harnesses_handler.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/claude_code_mcp_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/os_executable_locator.dart';
import 'package:agentic_hive_backend/src/data/harnesses/shared_agents_skill_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_skill_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/skills/bundled_skill.dart';
import 'package:agentic_hive_backend/src/domain/skills/bundled_skill_loader.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
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

  group('POST /api/v1/harnesses/:id/mcp/install', () {
    late bool failInstall;
    late _ScriptedProcessRunner mcpRunner;
    late DefaultHarnessService mcpService;
    late Handler mcpHandler;

    late Directory tempDir;
    late String claudeConfigPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('harnesses_handler_');
      claudeConfigPath = p.join(tempDir.path, '.claude.json');
      failInstall = false;
      mcpRunner = _ScriptedProcessRunner(
        onRun: (executable, arguments) {
          if (executable == 'which') {
            return switch (arguments.single) {
              'claude' => const ProcessRunResult(
                exitCode: 0,
                stdout: '/usr/local/bin/claude\n',
                stderr: '',
              ),
              _ => const ProcessRunResult(exitCode: 1, stdout: '', stderr: ''),
            };
          }
          if (executable == '/usr/local/bin/claude' &&
              arguments.length >= 2 &&
              arguments[0] == 'mcp') {
            if (arguments[1] == 'add') {
              if (failInstall) {
                return const ProcessRunResult(
                  exitCode: 2,
                  stdout: '',
                  stderr: 'Permission denied writing ~/.claude.json',
                );
              }
              File(claudeConfigPath).writeAsStringSync('''
{
  "mcpServers": {
    "hive": {
      "type": "stdio",
      "command": "/usr/bin/hive-mcp",
      "args": []
    }
  }
}
''');
              return const ProcessRunResult(
                exitCode: 0,
                stdout: '',
                stderr: '',
              );
            }
          }
          if (executable == '/usr/local/bin/claude') {
            return const ProcessRunResult(
              exitCode: 0,
              stdout: '2.1.0 (Claude Code)',
              stderr: '',
            );
          }
          return const ProcessRunResult(exitCode: 1, stdout: '', stderr: '');
        },
      );

      final locator = PosixExecutableLocator(processRunner: mcpRunner);
      mcpService = DefaultHarnessService(
        detectors: [
          ClaudeCodeDetector(
            executableLocator: locator,
            processRunner: mcpRunner,
          ),
          GeminiCliDetector(
            executableLocator: locator,
            processRunner: mcpRunner,
          ),
        ],
        mcpInstallers: HarnessMcpInstallerRegistry([
          ClaudeCodeMcpInstaller(
            processRunner: mcpRunner,
            configPathOverride: claudeConfigPath,
          ),
          const _UnsupportedStubInstaller(HarnessId.geminiCli),
        ]),
        mcpLocator: HiveMcpLocator(
          overrideCommand: const HiveMcpLaunchCommand(
            executable: '/usr/bin/hive-mcp',
          ),
        ),
      );

      mcpHandler = buildApiHandler(
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
        harnessesHandler: HarnessesHandler(harnessService: mcpService),
      );
    });

    tearDown(() async {
      await mcpService.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('installs MCP and returns refreshed HarnessInfo', () async {
      final listResp = await mcpHandler(buildRequest('/api/v1/harnesses'));
      final initial = HarnessListResponse.fromJson(await readJson(listResp));
      expect(initial.harnesses[0].mcpStatus, HarnessMcpStatus.notInstalled);
      expect(initial.harnesses[1].mcpStatus, HarnessMcpStatus.unsupported);

      final installResp = await mcpHandler(
        buildRequest(
          '/api/v1/harnesses/claude_code/mcp/install',
          method: 'POST',
        ),
      );
      expect(installResp.statusCode, 200);
      final updated = HarnessInfo.fromJson(await readJson(installResp));
      expect(updated.mcpStatus, HarnessMcpStatus.installed);
    });

    test('returns 409 when harness CLI is not installed', () async {
      final response = await mcpHandler(
        buildRequest(
          '/api/v1/harnesses/gemini_cli/mcp/install',
          method: 'POST',
        ),
      );
      expect(response.statusCode, 409);
      final body = await readJson(response);
      expect(
        (body['error']! as Map<String, Object?>)['code'],
        ApiErrorCode.conflict,
      );
    });

    test('returns 404 for unknown harness id', () async {
      final response = await mcpHandler(
        buildRequest(
          '/api/v1/harnesses/unknown_cli/mcp/install',
          method: 'POST',
        ),
      );
      expect(response.statusCode, 404);
    });

    test('returns 500 with stderr summary when CLI install fails', () async {
      failInstall = true;
      final response = await mcpHandler(
        buildRequest(
          '/api/v1/harnesses/claude_code/mcp/install',
          method: 'POST',
        ),
      );
      expect(response.statusCode, 500);
      final body = await readJson(response);
      expect(
        (body['error']! as Map<String, Object?>)['message'],
        contains('Permission denied writing ~/.claude.json'),
      );
    });
  });

  // Contract:
  //   POST /api/v1/harnesses/<id>/skill/install?overwriteModified=true|false
  //   Success (200): JSON HarnessInfo with updated skillStatus/skillMessage.
  //   400: invalid overwriteModified query param (details.overwriteModified).
  //   404: unknown harness <id>.
  //   409: modified without overwriteModified=true, conflict/unknown, or CLI
  //        not installed.
  group('POST /api/v1/harnesses/<id>/skill/install', () {
    late Directory tempDir;
    late DefaultHarnessService skillService;
    late Handler skillHandler;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hive_skill_handler_');
      final paths = platformPathsFor(
        Platform.operatingSystem,
        environment: {
          'HOME': tempDir.path,
          'USERPROFILE': tempDir.path,
          'LOCALAPPDATA': tempDir.path,
        },
      );
      final files = <String, List<int>>{'SKILL.md': utf8.encode('# Skill\n')};
      final loader = _FakeBundledSkillLoader(
        Success(
          BundledSkill(
            name: agenticHiveSkillName,
            files: files,
            contentHash: computeSkillContentHash(files),
          ),
        ),
      );
      final registry = HarnessSkillInstallerRegistry([
        SharedAgentsSkillInstaller(
          platformPaths: paths,
          bundledSkillLoader: loader,
          appVersion: '1.0.0',
        ),
      ]);
      final codexBin = p.join(tempDir.path, 'codex');
      File(codexBin).writeAsStringSync('stub');

      skillService = DefaultHarnessService(
        detectors: [
          _FakeSkillDetector(
            HarnessId.codex,
            HarnessInfo(
              id: HarnessId.codex,
              displayName: 'Codex',
              status: HarnessStatus.ready,
              executablePath: codexBin,
              checkedAt: startedAt,
            ),
          ),
        ],
        skillInstallers: registry,
      );

      skillHandler = buildApiHandler(
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
        harnessesHandler: HarnessesHandler(harnessService: skillService),
      );
    });

    tearDown(() async {
      await skillService.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('installs skill and returns 200 HarnessInfo, and GET includes '
        'skillStatus', () async {
      final response = await skillHandler(
        buildRequest('/api/v1/harnesses/codex/skill/install', method: 'POST'),
      );
      expect(response.statusCode, 200);
      final decoded = HarnessInfo.fromJson(await readJson(response));
      expect(decoded.skillStatus, HarnessSkillStatus.installed);

      final listResp = await skillHandler(buildRequest('/api/v1/harnesses'));
      expect(listResp.statusCode, 200);
      final listJson = await readJson(listResp);
      final items = (listJson['harnesses']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(items.first['skillStatus'], 'installed');
    });

    test('returns 409 on modified without flag and 200 with '
        'overwriteModified=true', () async {
      await skillHandler(
        buildRequest('/api/v1/harnesses/codex/skill/install', method: 'POST'),
      );
      File(
        p.join(
          tempDir.path,
          '.agents',
          'skills',
          agenticHiveSkillName,
          'SKILL.md',
        ),
      ).writeAsStringSync('edited\n');

      final conflictResp = await skillHandler(
        buildRequest('/api/v1/harnesses/codex/skill/install', method: 'POST'),
      );
      expect(conflictResp.statusCode, 409);

      final forcedResp = await skillHandler(
        buildRequest(
          '/api/v1/harnesses/codex/skill/install?overwriteModified=true',
          method: 'POST',
        ),
      );
      expect(forcedResp.statusCode, 200);
      final decoded = HarnessInfo.fromJson(await readJson(forcedResp));
      expect(decoded.skillStatus, HarnessSkillStatus.installed);
    });

    test('returns 400 when overwriteModified is not true or false', () async {
      final response = await skillHandler(
        buildRequest(
          '/api/v1/harnesses/codex/skill/install?overwriteModified=maybe',
          method: 'POST',
        ),
      );
      expect(response.statusCode, 400);
      final body = await readJson(response);
      final error = body['error']! as Map<String, Object?>;
      expect(
        (error['details']! as Map<String, Object?>).containsKey(
          'overwriteModified',
        ),
        isTrue,
      );
    });

    test('returns 404 for unknown harness id', () async {
      final response = await skillHandler(
        buildRequest('/api/v1/harnesses/nope/skill/install', method: 'POST'),
      );
      expect(response.statusCode, 404);
    });
  });

  // Contract:
  //   DELETE /api/v1/harnesses/<id>/skill
  //   Success (200): JSON HarnessInfo with skillStatus == not_installed.
  //   404: unknown harness <id>.
  //   409: foreign folder/symlink (conflict/unknown), or CLI not installed.
  group('DELETE /api/v1/harnesses/<id>/skill', () {
    late Directory tempDir;
    late DefaultHarnessService skillService;
    late Handler skillHandler;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hive_skill_del_handler_');
      final paths = platformPathsFor(
        Platform.operatingSystem,
        environment: {
          'HOME': tempDir.path,
          'USERPROFILE': tempDir.path,
          'LOCALAPPDATA': tempDir.path,
        },
      );
      final files = <String, List<int>>{'SKILL.md': utf8.encode('# Skill\n')};
      final loader = _FakeBundledSkillLoader(
        Success(
          BundledSkill(
            name: agenticHiveSkillName,
            files: files,
            contentHash: computeSkillContentHash(files),
          ),
        ),
      );
      final registry = HarnessSkillInstallerRegistry([
        SharedAgentsSkillInstaller(
          platformPaths: paths,
          bundledSkillLoader: loader,
          appVersion: '1.0.0',
        ),
      ]);
      final codexBin = p.join(tempDir.path, 'codex');
      File(codexBin).writeAsStringSync('stub');

      skillService = DefaultHarnessService(
        detectors: [
          _FakeSkillDetector(
            HarnessId.codex,
            HarnessInfo(
              id: HarnessId.codex,
              displayName: 'Codex',
              status: HarnessStatus.ready,
              executablePath: codexBin,
              checkedAt: startedAt,
            ),
          ),
        ],
        skillInstallers: registry,
      );

      skillHandler = buildApiHandler(
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
        harnessesHandler: HarnessesHandler(harnessService: skillService),
      );
    });

    tearDown(() async {
      await skillService.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('removes installed skill and returns 200 not_installed', () async {
      await skillHandler(
        buildRequest('/api/v1/harnesses/codex/skill/install', method: 'POST'),
      );
      final response = await skillHandler(
        buildRequest('/api/v1/harnesses/codex/skill', method: 'DELETE'),
      );
      expect(response.statusCode, 200);
      final decoded = HarnessInfo.fromJson(await readJson(response));
      expect(decoded.skillStatus, HarnessSkillStatus.notInstalled);
    });

    test('returns 409 on foreign folder', () async {
      final foreignDir = Directory(
        p.join(tempDir.path, '.agents', 'skills', agenticHiveSkillName),
      )..createSync(recursive: true);
      File(p.join(foreignDir.path, 'SKILL.md')).writeAsStringSync('foreign\n');

      final response = await skillHandler(
        buildRequest('/api/v1/harnesses/codex/skill', method: 'DELETE'),
      );
      expect(response.statusCode, 409);
    });

    test('returns 404 for unknown harness id', () async {
      final response = await skillHandler(
        buildRequest('/api/v1/harnesses/nope/skill', method: 'DELETE'),
      );
      expect(response.statusCode, 404);
    });
  });
}

final class _UnsupportedStubInstaller implements HarnessMcpInstaller {
  const new(this.id);

  @override
  final HarnessId id;

  @override
  String? get configPath => null;

  @override
  Future<HarnessMcpDetectionResult> detect({
    required String executablePath,
    required HiveMcpLaunchCommand expectedCommand,
  }) async =>
      const HarnessMcpDetectionResult(status: HarnessMcpStatus.unsupported);

  @override
  Future<Result<void>> install({
    required String executablePath,
    required HiveMcpLaunchCommand command,
  }) async => const Success<void>(null);
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

final class _FakeBundledSkillLoader implements BundledSkillLoader {
  new(this.result);
  final Result<BundledSkill> result;

  @override
  Result<BundledSkill> load(String name) => result;
}

final class _FakeSkillDetector implements HarnessDetector {
  new(this.id, this.info);

  @override
  final HarnessId id;
  final HarnessInfo info;

  @override
  void setExecutableOverride(String? path) {}

  @override
  Future<String?> locateExecutable() async => info.executablePath;

  @override
  Future<HarnessInfo> detect() async => info;
}
