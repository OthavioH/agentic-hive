import 'package:agentic_hive_backend/src/data/harnesses/os_executable_locator.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:test/test.dart';

void main() {
  group('executableLocatorFor', () {
    test('returns WindowsExecutableLocator for windows', () {
      final locator = executableLocatorFor(
        'windows',
        processRunner: _FakeProcessRunner(
          const ProcessRunResult(exitCode: 0, stdout: '', stderr: ''),
        ),
      );
      expect(locator, isA<WindowsExecutableLocator>());
    });

    test('returns PosixExecutableLocator for linux and macos', () {
      final runner = _FakeProcessRunner(
        const ProcessRunResult(exitCode: 0, stdout: '', stderr: ''),
      );
      expect(
        executableLocatorFor('linux', processRunner: runner),
        isA<PosixExecutableLocator>(),
      );
      expect(
        executableLocatorFor('macos', processRunner: runner),
        isA<PosixExecutableLocator>(),
      );
    });

    test('throws UnsupportedError for unknown operating systems', () {
      expect(
        () => executableLocatorFor(
          'plan9',
          processRunner: _FakeProcessRunner(
            const ProcessRunResult(exitCode: 0, stdout: '', stderr: ''),
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('WindowsExecutableLocator', () {
    test('runs where and returns the first resolved path', () async {
      final runner = _FakeProcessRunner(
        const ProcessRunResult(
          exitCode: 0,
          stdout: 'C:\\tools\\claude.cmd\r\nC:\\tools\\claude.exe\r\n',
          stderr: '',
        ),
      );
      final locator = WindowsExecutableLocator(processRunner: runner);

      final path = await locator.locate('claude');

      expect(path, r'C:\tools\claude.cmd');
      expect(runner.lastExecutable, 'where');
      expect(runner.lastArguments, ['claude']);
    });

    test('returns null on non-zero exit, timeout, or launch error', () async {
      for (final result in const [
        ProcessRunResult(
          exitCode: 1,
          stdout: '',
          stderr: 'INFO: Could not find',
        ),
        ProcessRunResult(exitCode: -1, stdout: '', stderr: '', timedOut: true),
        ProcessRunResult(
          exitCode: -1,
          stdout: '',
          stderr: '',
          launchError: 'missing',
        ),
      ]) {
        final locator = WindowsExecutableLocator(
          processRunner: _FakeProcessRunner(result),
        );
        expect(await locator.locate('gemini'), isNull);
      }
    });
  });

  group('PosixExecutableLocator', () {
    test('runs which and returns the first resolved path', () async {
      final runner = _FakeProcessRunner(
        const ProcessRunResult(
          exitCode: 0,
          stdout: '/usr/local/bin/agy\n',
          stderr: '',
        ),
      );
      final locator = PosixExecutableLocator(processRunner: runner);

      final path = await locator.locate('agy');

      expect(path, '/usr/local/bin/agy');
      expect(runner.lastExecutable, 'which');
      expect(runner.lastArguments, ['agy']);
    });

    test('returns null when which exits non-zero or output is empty', () async {
      final locator = PosixExecutableLocator(
        processRunner: _FakeProcessRunner(
          const ProcessRunResult(exitCode: 1, stdout: '', stderr: ''),
        ),
      );
      expect(await locator.locate('gemini'), isNull);
    });
  });
}

final class _FakeProcessRunner implements ProcessRunner {
  new(this.result);

  final ProcessRunResult result;
  String? lastExecutable;
  List<String>? lastArguments;

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) async {
    lastExecutable = executable;
    lastArguments = arguments;
    return result;
  }
}
