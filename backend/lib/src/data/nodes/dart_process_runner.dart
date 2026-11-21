import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/nodes/os_process_platform.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';

/// `dart:io` implementation of [NodeProcessRunner].
final class DartProcessRunner implements NodeProcessRunner {
  /// Creates a Dart process runner.
  const new({
    this.platform,
    this.maxOutputLength = defaultMaxOutputLength,
    this.drainTimeout = defaultDrainTimeout,
  });

  /// Default per-stream output cap (1 MiB of characters).
  static const int defaultMaxOutputLength = 1024 * 1024;

  /// Default maximum time to wait for stream drain after a timeout kill.
  static const Duration defaultDrainTimeout = Duration(seconds: 2);

  /// OS-specific process launcher and terminator.
  final OsProcessPlatform? platform;

  /// Maximum number of characters retained per stream (`stdout` / `stderr`).
  final int maxOutputLength;

  /// Maximum time to wait for pipes to close after terminating a timed-out
  /// process tree.
  final Duration drainTimeout;

  @override
  Future<Result<ProcessExecutionResult>> run(
    ProcessInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async {
    final effectivePlatform = platform ?? currentProcessPlatform();
    final Process process;
    try {
      process = await effectivePlatform.start(
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
    final cancelSignal = Completer<void>();

    final stdoutDone = _collectStream(
      process.stdout,
      stdoutBuffer,
      'stdout',
      onOutput,
      cancelSignal.future,
    );
    final stderrDone = _collectStream(
      process.stderr,
      stderrBuffer,
      'stderr',
      onOutput,
      cancelSignal.future,
    );

    unawaited(process.stdin.done.catchError((Object _) {}));
    try {
      if (invocation.stdinContent != null) {
        process.stdin.write(invocation.stdinContent);
        await process.stdin.flush();
      }
      await process.stdin.close();
    } on Object {
      // Ignore broken-pipe / early-exit errors when writing or closing stdin.
    }

    var timedOut = false;
    final int exitCode;
    final timeout = invocation.timeout;
    if (timeout != null) {
      exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () async {
          timedOut = true;
          await effectivePlatform.terminateTree(process);
          return -1;
        },
      );
    } else {
      exitCode = await process.exitCode;
    }

    if (timedOut) {
      await Future.wait<void>(<Future<void>>[stdoutDone, stderrDone]).timeout(
        drainTimeout,
        onTimeout: () {
          if (!cancelSignal.isCompleted) {
            cancelSignal.complete();
          }
          return const <void>[];
        },
      );
    } else {
      await Future.wait<void>(<Future<void>>[stdoutDone, stderrDone]);
    }

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
    Future<void> cancelSignal,
  ) async {
    final completer = Completer<void>();
    var truncated = false;

    final subscription = stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          (line) {
            onOutput?.call(streamName, line);
            if (truncated) return;

            final separatorLength = buffer.isEmpty ? 0 : 1;
            final remaining = maxOutputLength - buffer.length - separatorLength;
            if (remaining <= 0) {
              truncated = true;
              return;
            }
            if (separatorLength > 0) {
              buffer.writeln();
            }
            if (line.length <= remaining) {
              buffer.write(line);
            } else {
              buffer.write(line.substring(0, remaining));
              truncated = true;
            }
          },
          onError: (Object _) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          cancelOnError: true,
        );

    unawaited(
      cancelSignal.then((_) async {
        await subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }),
    );

    await completer.future;
  }
}
