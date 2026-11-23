import 'dart:io';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/antigravity_mcp_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/claude_code_mcp_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/codex_mcp_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/gemini_cli_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const devCommand = HiveMcpLaunchCommand(
    executable: '/usr/bin/dart',
    baseArguments: ['run', '/repo/backend/bin/hive_mcp.dart'],
  );

  group('HarnessMcpInstallerRegistry', () {
    test('looks up installers by HarnessId without switching', () {
      final runner = _RecordingProcessRunner((_, _) {
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      final registry = HarnessMcpInstallerRegistry([
        ClaudeCodeMcpInstaller(processRunner: runner),
        CodexMcpInstaller(processRunner: runner),
        GeminiCliMcpInstaller(processRunner: runner),
        AntigravityMcpInstaller(processRunner: runner),
      ]);

      expect(registry[HarnessId.claudeCode], isA<ClaudeCodeMcpInstaller>());
      expect(registry[HarnessId.codex], isA<CodexMcpInstaller>());
      expect(registry[HarnessId.geminiCli], isA<GeminiCliMcpInstaller>());
      expect(registry[HarnessId.antigravity], isA<AntigravityMcpInstaller>());
    });
  });

  group('ClaudeCodeMcpInstaller', () {
    test(
      'detects installed from ~/.claude.json without spawning the CLI',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'claude_mcp_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final configPath = p.join(tempDir.path, '.claude.json');
        await File(configPath).writeAsString('''
{
  "numStartups": 12,
  "mcpServers": {
    "other": {
      "type": "http",
      "url": "https://example.com/mcp"
    },
    "hive": {
      "type": "stdio",
      "command": "/usr/bin/dart",
      "args": ["run", "/repo/backend/bin/hive_mcp.dart"],
      "env": {}
    }
  }
}
''');
        final runner = _RecordingProcessRunner((_, _) {
          fail('detect() must not spawn the claude CLI');
        });
        final installer = ClaudeCodeMcpInstaller(
          processRunner: runner,
          configPathOverride: configPath,
        );

        final result = await installer.detect(
          executablePath: '/usr/local/bin/claude',
          expectedCommand: devCommand,
        );

        expect(runner.calls, isEmpty);
        expect(result.status, HarnessMcpStatus.installed);
      },
    );

    test(
      'detects outdated when command or args differ in ~/.claude.json',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'claude_mcp_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final configPath = p.join(tempDir.path, '.claude.json');
        await File(configPath).writeAsString('''
{
  "mcpServers": {
    "hive": {
      "type": "stdio",
      "command": "/usr/bin/dart",
      "args": ["run", "/old/path/bin/hive_mcp.dart"]
    }
  }
}
''');
        final runner = _RecordingProcessRunner((_, _) {
          fail('detect() must not spawn the claude CLI');
        });
        final installer = ClaudeCodeMcpInstaller(
          processRunner: runner,
          configPathOverride: configPath,
        );

        final result = await installer.detect(
          executablePath: 'claude',
          expectedCommand: devCommand,
        );

        expect(runner.calls, isEmpty);
        expect(result.status, HarnessMcpStatus.outdated);
      },
    );

    test(
      'detects notInstalled when ~/.claude.json or hive entry is missing',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'claude_mcp_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final missingPath = p.join(tempDir.path, 'missing.json');
        final runner = _RecordingProcessRunner((_, _) {
          fail('detect() must not spawn the claude CLI');
        });
        final installer = ClaudeCodeMcpInstaller(
          processRunner: runner,
          configPathOverride: missingPath,
        );

        final missingResult = await installer.detect(
          executablePath: 'claude',
          expectedCommand: devCommand,
        );
        expect(missingResult.status, HarnessMcpStatus.notInstalled);

        final emptyConfigPath = p.join(tempDir.path, '.claude.json');
        await File(emptyConfigPath).writeAsString('{"mcpServers": {}}');
        final emptyInstaller = ClaudeCodeMcpInstaller(
          processRunner: runner,
          configPathOverride: emptyConfigPath,
        );
        final emptyResult = await emptyInstaller.detect(
          executablePath: 'claude',
          expectedCommand: devCommand,
        );
        expect(emptyResult.status, HarnessMcpStatus.notInstalled);
        expect(runner.calls, isEmpty);
      },
    );

    test('detects unknown when ~/.claude.json is malformed JSON', () async {
      final tempDir = await Directory.systemTemp.createTemp('claude_mcp_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final configPath = p.join(tempDir.path, '.claude.json');
      await File(configPath).writeAsString('{not valid json');
      final runner = _RecordingProcessRunner((_, _) {
        fail('detect() must not spawn the claude CLI');
      });
      final installer = ClaudeCodeMcpInstaller(
        processRunner: runner,
        configPathOverride: configPath,
      );

      final result = await installer.detect(
        executablePath: 'claude',
        expectedCommand: devCommand,
      );

      expect(runner.calls, isEmpty);
      expect(result.status, HarnessMcpStatus.unknown);
    });

    test(
      'install passes exact args and removes+re-adds when already exists',
      () async {
        var addAttempts = 0;
        final runner = _RecordingProcessRunner((_, args) {
          if (args[1] == 'add') {
            addAttempts++;
            if (addAttempts == 1) {
              return const ProcessRunResult(
                exitCode: 1,
                stdout: '',
                stderr: 'MCP server hive already exists in user config',
              );
            }
            return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
          }
          return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
        });
        final installer = ClaudeCodeMcpInstaller(processRunner: runner);

        final result = await installer.install(
          executablePath: 'claude',
          command: devCommand,
        );

        expect(result, isA<Success<void>>());
        expect(runner.calls.map((c) => c.arguments), [
          [
            'mcp',
            'add',
            '-s',
            'user',
            'hive',
            '--',
            '/usr/bin/dart',
            'run',
            '/repo/backend/bin/hive_mcp.dart',
          ],
          ['mcp', 'remove', '-s', 'user', 'hive'],
          [
            'mcp',
            'add',
            '-s',
            'user',
            'hive',
            '--',
            '/usr/bin/dart',
            'run',
            '/repo/backend/bin/hive_mcp.dart',
          ],
        ]);
      },
    );
  });

  group('CodexMcpInstaller', () {
    test(
      'detects installed only when command, args, and HIVE_* env_vars match',
      () async {
        final runner = _RecordingProcessRunner((_, _) {
          return const ProcessRunResult(
            exitCode: 0,
            stdout: '''
{
  "name": "hive",
  "enabled": true,
  "transport": {
    "type": "stdio",
    "command": "/usr/bin/dart",
    "args": ["run", "/repo/backend/bin/hive_mcp.dart"],
    "env_vars": ["HIVE_SOCKET_PATH", "HIVE_RUN_ID", "HIVE_NODE_ID", "HIVE_ATTEMPT"]
  }
}
''',
            stderr: '',
          );
        });
        final installer = CodexMcpInstaller(processRunner: runner);

        final result = await installer.detect(
          executablePath: 'codex',
          expectedCommand: devCommand,
        );

        expect(runner.calls.single.arguments, ['mcp', 'get', 'hive', '--json']);
        expect(result.status, HarnessMcpStatus.installed);
      },
    );

    test('detects outdated when env_vars is missing HIVE_* keys', () async {
      final runner = _RecordingProcessRunner((_, _) {
        return const ProcessRunResult(
          exitCode: 0,
          stdout: '''
{
  "name": "hive",
  "enabled": true,
  "transport": {
    "type": "stdio",
    "command": "/usr/bin/dart",
    "args": ["run", "/repo/backend/bin/hive_mcp.dart"],
    "env_vars": []
  }
}
''',
          stderr: '',
        );
      });
      final installer = CodexMcpInstaller(processRunner: runner);

      final result = await installer.detect(
        executablePath: 'codex',
        expectedCommand: devCommand,
      );

      expect(result.status, HarnessMcpStatus.outdated);
    });

    test('install runs codex mcp add and patches env_vars in config.toml '
        'with backup', () async {
      final tempDir = await Directory.systemTemp.createTemp('codex_mcp_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final configPath = p.join(tempDir.path, 'config.toml');
      await File(configPath).writeAsString('''
model = "gpt-5"

[mcp_servers.hive]
command = "/usr/bin/dart"
args = ["run", "/repo/backend/bin/hive_mcp.dart"]

[mcp_servers.other]
command = "node"
''');

      final runner = _RecordingProcessRunner((_, _) {
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      final installer = CodexMcpInstaller(
        processRunner: runner,
        configPathOverride: configPath,
      );

      final result = await installer.install(
        executablePath: 'codex',
        command: devCommand,
      );

      expect(result, isA<Success<void>>());
      expect(runner.calls.single.arguments, [
        'mcp',
        'add',
        'hive',
        '--',
        '/usr/bin/dart',
        'run',
        '/repo/backend/bin/hive_mcp.dart',
      ]);
      expect(File('$configPath.bak').existsSync(), isTrue);
      final updated = await File(configPath).readAsString();
      expect(
        updated,
        contains(
          'env_vars = ["HIVE_SOCKET_PATH", "HIVE_RUN_ID", '
          '"HIVE_NODE_ID", "HIVE_ATTEMPT"]',
        ),
      );
      expect(updated, contains('[mcp_servers.other]'));
    });
  });

  group('GeminiCliMcpInstaller', () {
    test('detects installed from ~/.gemini/settings.json tolerating invalid '
        'sibling entries without spawning the CLI', () async {
      final tempDir = await Directory.systemTemp.createTemp('gemini_mcp_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final configPath = p.join(tempDir.path, 'settings.json');
      await File(configPath).writeAsString('''
{
  "mcpServers": {
    "stitch": {
      "serverUrl": "https://stitch.googleapis.com/mcp",
      "headers": {
        "X-Goog-Api-Key": "secret"
      }
    },
    "hive": {
      "command": "/usr/bin/dart",
      "args": ["run", "/repo/backend/bin/hive_mcp.dart"],
      "trust": true
    }
  }
}
''');
      final runner = _RecordingProcessRunner((_, _) {
        fail('detect() must not spawn the gemini CLI');
      });
      final installer = GeminiCliMcpInstaller(
        processRunner: runner,
        configPathOverride: configPath,
      );

      final result = await installer.detect(
        executablePath: 'gemini',
        expectedCommand: devCommand,
      );

      expect(runner.calls, isEmpty);
      expect(result.status, HarnessMcpStatus.installed);
    });

    test(
      'detects outdated when command or args differ in ~/.gemini/settings.json',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'gemini_mcp_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final configPath = p.join(tempDir.path, 'settings.json');
        await File(configPath).writeAsString('''
{
  "mcpServers": {
    "hive": {
      "command": "/usr/bin/dart",
      "args": ["run", "/old/worktree/backend/bin/hive_mcp.dart"],
      "trust": true
    }
  }
}
''');
        final runner = _RecordingProcessRunner((_, _) {
          fail('detect() must not spawn the gemini CLI');
        });
        final installer = GeminiCliMcpInstaller(
          processRunner: runner,
          configPathOverride: configPath,
        );

        final result = await installer.detect(
          executablePath: 'gemini',
          expectedCommand: devCommand,
        );

        expect(runner.calls, isEmpty);
        expect(result.status, HarnessMcpStatus.outdated);
      },
    );

    test('detects notInstalled when ~/.gemini/settings.json or hive entry is '
        'missing', () async {
      final tempDir = await Directory.systemTemp.createTemp('gemini_mcp_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final missingPath = p.join(tempDir.path, 'settings.json');
      final runner = _RecordingProcessRunner((_, _) {
        fail('detect() must not spawn the gemini CLI');
      });
      final installer = GeminiCliMcpInstaller(
        processRunner: runner,
        configPathOverride: missingPath,
      );

      final result = await installer.detect(
        executablePath: 'gemini',
        expectedCommand: devCommand,
      );

      expect(runner.calls, isEmpty);
      expect(result.status, HarnessMcpStatus.notInstalled);
    });

    test('install passes user scope and --trust', () async {
      final runner = _RecordingProcessRunner((_, _) {
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      final installer = GeminiCliMcpInstaller(processRunner: runner);

      final result = await installer.install(
        executablePath: 'gemini',
        command: devCommand,
      );

      expect(result, isA<Success<void>>());
      expect(runner.calls.single.arguments, [
        'mcp',
        'add',
        '-s',
        'user',
        '--trust',
        'hive',
        '/usr/bin/dart',
        'run',
        '/repo/backend/bin/hive_mcp.dart',
      ]);
    });
  });

  group('AntigravityMcpInstaller', () {
    test('detects installed from agy mcp list table', () async {
      final runner = _RecordingProcessRunner((_, _) {
        return const ProcessRunResult(
          exitCode: 0,
          stdout: '''
NAME                  TYPE   STATUS   COMMAND/URL
dart                  stdio  enabled  dart mcp-server
hive                  stdio  enabled  /usr/bin/dart run /repo/backend/bin/hive_mcp.dart
''',
          stderr: '',
        );
      });
      final installer = AntigravityMcpInstaller(processRunner: runner);

      final result = await installer.detect(
        executablePath: 'agy',
        expectedCommand: devCommand,
      );

      expect(runner.calls.single.arguments, ['mcp', 'list']);
      expect(result.status, HarnessMcpStatus.installed);
    });

    test('install passes exact args', () async {
      final runner = _RecordingProcessRunner((_, _) {
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      final installer = AntigravityMcpInstaller(processRunner: runner);

      final result = await installer.install(
        executablePath: 'agy',
        command: devCommand,
      );

      expect(result, isA<Success<void>>());
      expect(runner.calls.single.arguments, [
        'mcp',
        'add',
        'hive',
        '--',
        '/usr/bin/dart',
        'run',
        '/repo/backend/bin/hive_mcp.dart',
      ]);
    });
  });
}

final class _RecordedCall {
  const new(this.executable, this.arguments);
  final String executable;
  final List<String> arguments;
}

final class _RecordingProcessRunner implements ProcessRunner {
  new(this.onRun);

  final ProcessRunResult Function(String executable, List<String> arguments)
  onRun;
  final List<_RecordedCall> calls = [];

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) async {
    calls.add(_RecordedCall(executable, arguments));
    return onRun(executable, arguments);
  }
}
