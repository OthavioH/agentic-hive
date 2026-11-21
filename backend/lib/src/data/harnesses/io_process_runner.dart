import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';

/// Runs subprocesses with `dart:io`, closing `stdin` immediately and enforcing
/// a per-invocation timeout.
final class IoProcessRunner implements ProcessRunner {
  /// Creates a `dart:io` process runner.
  const new();

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) async {
    final Process process;
    try {
      process = await Process.start(executable, arguments);
    } on ProcessException catch (e) {
      return ProcessRunResult(
        exitCode: -1,
        stdout: '',
        stderr: '',
        launchError: e.message,
      );
    }

    // Close stdin immediately so interactive prompts cannot block on input.
    try {
      await process.stdin.close();
    } on Object {
      // Ignore broken-pipe errors when the child exits before stdin closes.
    }

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach(stdoutBuffer.write);
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach(stderrBuffer.write);

    var timedOut = false;
    final exitCode =
        await () async {
          final code = await process.exitCode;
          await stdoutDone;
          await stderrDone;
          return code;
        }().timeout(
          timeout,
          onTimeout: () {
            timedOut = true;
            process.kill();
            return -1;
          },
        );

    return ProcessRunResult(
      exitCode: exitCode,
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
      timedOut: timedOut,
    );
  }
}
