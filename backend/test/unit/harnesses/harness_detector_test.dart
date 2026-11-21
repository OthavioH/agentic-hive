import 'package:agentic_hive_backend/src/domain/harnesses/executable_locator.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 11, 20, 20);

  group('CliHarnessDetector', () {
    test('returns notInstalled when executable is not on PATH', () async {
      final runner = _FakeProcessRunner(
        const ProcessRunResult(exitCode: 0, stdout: '1.0.0', stderr: ''),
      );
      final detector = GeminiCliDetector(
        executableLocator: _FakeExecutableLocator({}),
        processRunner: runner,
        now: () => fixedNow,
      );

      final info = await detector.detect();

      expect(info.id, HarnessId.geminiCli);
      expect(info.displayName, 'Gemini CLI');
      expect(info.status, HarnessStatus.notInstalled);
      expect(info.version, isNull);
      expect(info.executablePath, isNull);
      expect(info.errorMessage, isNull);
      expect(info.checkedAt, fixedNow);
      expect(runner.calls, 0);
    });

    test('parses versions for all four concrete harnesses', () async {
      final cases =
          <
            (
              HarnessId,
              String,
              String,
              String,
              CliHarnessDetector Function(ExecutableLocator, ProcessRunner),
            )
          >[
            (
              HarnessId.claudeCode,
              '/usr/local/bin/claude',
              '2.1.14 (Claude Code)',
              '2.1.14',
              (l, r) => ClaudeCodeDetector(
                executableLocator: l,
                processRunner: r,
                now: () => fixedNow,
              ),
            ),
            (
              HarnessId.codex,
              r'C:\tools\codex.cmd',
              'codex-cli 0.25.0',
              '0.25.0',
              (l, r) => CodexDetector(
                executableLocator: l,
                processRunner: r,
                now: () => fixedNow,
              ),
            ),
            (
              HarnessId.geminiCli,
              '/opt/homebrew/bin/gemini',
              '0.1.12\n',
              '0.1.12',
              (l, r) => GeminiCliDetector(
                executableLocator: l,
                processRunner: r,
                now: () => fixedNow,
              ),
            ),
            (
              HarnessId.antigravity,
              '/usr/local/bin/agy',
              'Antigravity v1.4.2-beta.1',
              '1.4.2-beta.1',
              (l, r) => AntigravityDetector(
                executableLocator: l,
                processRunner: r,
                now: () => fixedNow,
              ),
            ),
          ];

      for (final (id, path, stdout, expectedVersion, factory) in cases) {
        final detector = factory(
          _FakeExecutableLocator({
            'claude': path,
            'codex': path,
            'gemini': path,
            'agy': path,
          }),
          _FakeProcessRunner(
            ProcessRunResult(exitCode: 0, stdout: stdout, stderr: ''),
          ),
        );

        final info = await detector.detect();
        expect(info.id, id);
        expect(info.status, HarnessStatus.ready);
        expect(info.version, expectedVersion);
        expect(info.executablePath, path);
        expect(info.errorMessage, isNull);
      }
    });

    test('detects outdated CLI and interactive update prompts', () async {
      final detector = CodexDetector(
        executableLocator: _FakeExecutableLocator({'codex': '/usr/bin/codex'}),
        processRunner: _FakeProcessRunner(
          const ProcessRunResult(
            exitCode: 1,
            stdout: 'codex-cli 0.10.0\nUpdate required. Press Enter to update.',
            stderr: '',
          ),
        ),
        now: () => fixedNow,
      );

      final info = await detector.detect();

      expect(info.status, HarnessStatus.outdated);
      expect(info.version, '0.10.0');
      expect(info.executablePath, '/usr/bin/codex');
      expect(info.errorMessage, contains('Update required'));
    });

    test('detects auth errors without leaking raw stderr/secrets', () async {
      final detector = ClaudeCodeDetector(
        executableLocator: _FakeExecutableLocator({
          'claude': '/usr/bin/claude',
        }),
        processRunner: _FakeProcessRunner(
          const ProcessRunResult(
            exitCode: 1,
            stdout: '',
            stderr: 'Error: Not logged in. Secret token sk-secret-12345',
          ),
        ),
        now: () => fixedNow,
      );

      final info = await detector.detect();

      expect(info.status, HarnessStatus.authError);
      expect(info.executablePath, '/usr/bin/claude');
      expect(info.errorMessage, contains('Authentication required'));
      expect(info.errorMessage, isNot(contains('sk-secret-12345')));
    });

    test('marks timed-out probe as unavailable', () async {
      final detector = AntigravityDetector(
        executableLocator: _FakeExecutableLocator({'agy': '/usr/bin/agy'}),
        processRunner: _FakeProcessRunner(
          const ProcessRunResult(
            exitCode: -1,
            stdout: '',
            stderr: '',
            timedOut: true,
          ),
        ),
        now: () => fixedNow,
      );

      final info = await detector.detect();

      expect(info.status, HarnessStatus.unavailable);
      expect(info.executablePath, '/usr/bin/agy');
      expect(info.errorMessage, contains('Timed out'));
    });

    test(
      'marks non-zero exit without auth/update pattern as unavailable',
      () async {
        final detector = GeminiCliDetector(
          executableLocator: _FakeExecutableLocator({
            'gemini': '/usr/bin/gemini',
          }),
          processRunner: _FakeProcessRunner(
            const ProcessRunResult(
              exitCode: 2,
              stdout: '',
              stderr: 'unexpected flag',
            ),
          ),
          now: () => fixedNow,
        );

        final info = await detector.detect();

        expect(info.status, HarnessStatus.unavailable);
        expect(info.errorMessage, contains('exited with code 2'));
      },
    );

    test('marks unparseable version output as unavailable', () async {
      final detector = ClaudeCodeDetector(
        executableLocator: _FakeExecutableLocator({
          'claude': '/usr/bin/claude',
        }),
        processRunner: _FakeProcessRunner(
          const ProcessRunResult(
            exitCode: 0,
            stdout: 'hello world without version',
            stderr: '',
          ),
        ),
        now: () => fixedNow,
      );

      final info = await detector.detect();

      expect(info.status, HarnessStatus.unavailable);
      expect(info.errorMessage, contains('Could not parse'));
    });
  });
}

final class _FakeExecutableLocator implements ExecutableLocator {
  new(this.paths);

  final Map<String, String> paths;

  @override
  Future<String?> locate(String executableName) async => paths[executableName];
}

final class _FakeProcessRunner implements ProcessRunner {
  new(this.result);

  final ProcessRunResult result;
  int calls = 0;

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) async {
    calls++;
    return result;
  }
}
