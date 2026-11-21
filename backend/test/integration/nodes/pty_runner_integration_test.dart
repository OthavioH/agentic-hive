import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/data/nodes/os_shell_provider.dart';
import 'package:agentic_hive_backend/src/data/nodes/pty_runner_factory.dart';
import 'package:agentic_hive_backend/src/data/runs/process_tree_killer_factory.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/pty_session.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_pty_int_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('currentPtyRunner spawns real process, streams output, accepts input '
      'and resize, and exits cleanly', () async {
    final registry = PtySessionRegistry(
      coalesceWindow: const Duration(milliseconds: 5),
    );
    addTearDown(registry.dispose);
    final managedKiller = currentProcessTreeKiller();
    final runner = currentPtyRunner(
      processTracker: managedKiller.tracker,
      processTreeKiller: managedKiller.killer,
      sessionRegistry: registry,
    );

    const key = (runId: 'run-pty-1', nodeId: 'term-1', attempt: 1);
    addTearDown(() async {
      await registry.terminateSession(key);
      await managedKiller.killer.killTree(runId: key.runId, nodeId: key.nodeId);
    });
    final shell = currentDefaultShellProvider().defaultShell;
    final outputCompleter = Completer<void>();
    final receivedText = StringBuffer();

    final sub = registry.outputs.listen((payload) {
      final chunk = utf8.decode(
        base64Decode(payload.data),
        allowMalformed: true,
      );
      receivedText.write(chunk);
      if (receivedText.toString().contains('PTY_READY') &&
          !outputCompleter.isCompleted) {
        outputCompleter.complete();
      }
    });
    addTearDown(sub.cancel);

    final runFuture = runner.run(
      PtyInvocation(
        executable: shell,
        workingDirectory: tempDir.path,
        runId: key.runId,
        nodeId: key.nodeId,
        attempt: key.attempt,
        timeout: const Duration(seconds: 15),
      ),
    );

    // Wait briefly for the shell to start, then send echo + exit via
    // PtySessionRegistry.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(registry.isActive(key), isTrue);

    final resizeRes = await registry.resize(key, cols: 100, rows: 30);
    expect(resizeRes.isSuccess, isTrue);

    final newline = Platform.isWindows ? '\r\n' : '\n';
    final inputRes = await registry.writeInput(
      key,
      utf8.encode('echo PTY_READY${newline}exit$newline'),
    );
    expect(inputRes.isSuccess, isTrue);

    await outputCompleter.future.timeout(const Duration(seconds: 10));
    final result = await runFuture.timeout(const Duration(seconds: 10));
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.exitCode, 0);
    expect(result.valueOrNull!.stdout, contains('PTY_READY'));
    expect(registry.isActive(key), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
    'ProcessTreeKiller terminates PTY process tree on cancellation',
    () async {
      final registry = PtySessionRegistry();
      addTearDown(registry.dispose);
      final managedKiller = currentProcessTreeKiller();
      final runner = currentPtyRunner(
        processTracker: managedKiller.tracker,
        processTreeKiller: managedKiller.killer,
        sessionRegistry: registry,
      );

      const key = (runId: 'run-pty-kill', nodeId: 'term-kill', attempt: 1);
      addTearDown(() async {
        await registry.terminateSession(key);
        await managedKiller.killer.killTree(
          runId: key.runId,
          nodeId: key.nodeId,
        );
      });
      final args = Platform.isWindows
          ? <String>['-NoProfile', '-Command', 'Start-Sleep -Seconds 30']
          : <String>['-c', 'sleep 30'];
      final exe = Platform.isWindows ? 'powershell.exe' : '/bin/sh';

      final runFuture = runner.run(
        PtyInvocation(
          executable: exe,
          arguments: args,
          workingDirectory: tempDir.path,
          runId: key.runId,
          nodeId: key.nodeId,
          attempt: key.attempt,
          timeout: const Duration(seconds: 20),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(registry.isActive(key), isTrue);

      final killResult = await managedKiller.killer.killTree(
        runId: key.runId,
        nodeId: key.nodeId,
      );
      expect(killResult.isSuccess, isTrue);

      final execResult = await runFuture.timeout(const Duration(seconds: 10));
      expect(execResult.isSuccess, isTrue);
      expect(execResult.valueOrNull!.timedOut, isFalse);
      expect(registry.isActive(key), isFalse);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
