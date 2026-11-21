import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';

/// `dart:io` implementation of [NodeProcessRunner].
final class DartProcessRunner implements NodeProcessRunner {
  /// Creates a Dart process runner.
  const new();

  @override
  Future<Result<ProcessExecutionResult>> run(
    ProcessInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async {
    final Process process;
    try {
      process = await Process.start(
        invocation.executable,
        invocation.arguments,
        workingDirectory: invocation.workingDirectory,
        environment: invocation.environment.isEmpty
            ? null
            : invocation.environment,
      );
    } on ProcessException catch (e) {
      return FailureResult(
        NodeExecutionFailure(
          'Failed to start "${invocation.executable}": ${e.message}',
          cause: e,
        ),
      );
    }

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final stdoutDone = _collectStream(
      process.stdout,
      stdoutBuffer,
      'stdout',
      onOutput,
    );
    final stderrDone = _collectStream(
      process.stderr,
      stderrBuffer,
      'stderr',
      onOutput,
    );

    if (invocation.stdinContent != null) {
      process.stdin.write(invocation.stdinContent);
    }
    await process.stdin.close();

    var timedOut = false;
    final int exitCode;
    final timeout = invocation.timeout;
    if (timeout != null) {
      exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          timedOut = true;
          process.kill();
          return -1;
        },
      );
    } else {
      exitCode = await process.exitCode;
    }

    await Future.wait<void>([stdoutDone, stderrDone]);

    return Success(
      ProcessExecutionResult(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        timedOut: timedOut,
      ),
    );
  }

  Future<void> _collectStream(
    Stream<List<int>> stream,
    StringBuffer buffer,
    String streamName,
    NodeOutputCallback? onOutput,
  ) async {
    await for (final line
        in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.write(line);
      onOutput?.call(streamName, line);
    }
  }
}
