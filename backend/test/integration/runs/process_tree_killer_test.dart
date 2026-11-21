@Timeout(Duration(seconds: 30))
library;

import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/data/nodes/dart_process_runner.dart';
import 'package:agentic_hive_backend/src/data/nodes/os_process_platform.dart';
import 'package:agentic_hive_backend/src/data/runs/posix_process_tree_killer.dart';
import 'package:agentic_hive_backend/src/data/runs/process_tree_killer_factory.dart';
import 'package:agentic_hive_backend/src/data/runs/windows_process_tree_killer.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

bool _isProcessAlive(int pid) {
  if (Platform.isWindows) {
    final result = Process.runSync('tasklist', <String>[
      '/FI',
      'PID eq $pid',
      '/NH',
    ]);
    return (result.stdout as String).contains('$pid');
  }
  final result = Process.runSync('kill', <String>['-0', '$pid']);
  return result.exitCode == 0;
}

void main() {
  test('currentProcessTreeKiller terminates parent and spawned child processes '
      'before returning', () async {
    final tempDir = await Directory.systemTemp.createTemp('hive_tree_kill_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final childPidFile = File(p.join(tempDir.path, 'child.pid'));
    final parentScript = File(p.join(tempDir.path, 'parent.dart'));
    final childScript = File(p.join(tempDir.path, 'child.dart'));

    await childScript.writeAsString(r'''
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> args) async {
  await File(args[0]).writeAsString('$pid');
  await Future<void>.delayed(const Duration(seconds: 60));
}
''');

    await parentScript.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> args) async {
  await Process.start(Platform.resolvedExecutable, [args[0], args[1]]);
  await Future<void>.delayed(const Duration(seconds: 60));
}
''');

    final managed = currentProcessTreeKiller();
    final runner = DartProcessRunner(
      platform: currentProcessPlatform(),
      processTracker: managed.tracker,
    );

    final runFuture = runner.run(
      ProcessInvocation(
        executable: Platform.resolvedExecutable,
        arguments: <String>[
          parentScript.path,
          childScript.path,
          childPidFile.path,
        ],
        workingDirectory: tempDir.path,
        runId: 'run-tree-1',
        nodeId: 'node-1',
      ),
    );

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!childPidFile.existsSync() ||
        childPidFile.readAsStringSync().trim().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for child process to write PID file.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final childPid = int.parse(childPidFile.readAsStringSync().trim());
    expect(_isProcessAlive(childPid), isTrue);

    final killResult = await managed.killer.killTree(runId: 'run-tree-1');
    expect(killResult.isSuccess, isTrue);
    expect(_isProcessAlive(childPid), isFalse);

    final execResult = await runFuture;
    expect(execResult.isSuccess, isTrue);
  });

  test('deterministically returns NodeExecutionFailure when confirmation times '
      'out and blocks new spawns while cancelling', () async {
    final tempDir = await Directory.systemTemp.createTemp('hive_tree_to_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final script = File(p.join(tempDir.path, 'sleep.dart'));
    await script.writeAsString('''
import 'dart:async';
Future<void> main() => Future<void>.delayed(const Duration(seconds: 30));
''');

    final process = await Process.start(Platform.resolvedExecutable, <String>[
      script.path,
    ]);
    addTearDown(() {
      process.kill(ProcessSignal.sigkill);
    });

    WindowsProcessTreeKiller? winKiller;
    PosixProcessTreeKiller? posixKiller;
    final ManagedProcessTreeKiller unconfirmedManaged;
    if (Platform.isWindows) {
      final killer = WindowsProcessTreeKiller(
        confirmationTimeout: Duration.zero,
        skipTerminateForTesting: true,
      );
      winKiller = killer;
      unconfirmedManaged = (killer: killer, tracker: killer);
    } else {
      final killer = PosixProcessTreeKiller(
        gracePeriod: Duration.zero,
        confirmationTimeout: Duration.zero,
        skipTerminateForTesting: true,
      );
      posixKiller = killer;
      unconfirmedManaged = (killer: killer, tracker: killer);
    }

    unconfirmedManaged.tracker.track(
      runId: 'run-to',
      nodeId: 'n1',
      process: process,
    );

    final res = await unconfirmedManaged.killer.killTree(runId: 'run-to');
    expect(res.failureOrNull, isA<NodeExecutionFailure>());
    expect(unconfirmedManaged.tracker.isRunCancelling('run-to'), isTrue);

    // DartProcessRunner refuses to start a new process for a cancelling run.
    final runner = DartProcessRunner(
      platform: currentProcessPlatform(),
      processTracker: unconfirmedManaged.tracker,
    );
    final refused = await runner.run(
      ProcessInvocation(
        executable: Platform.resolvedExecutable,
        arguments: <String>[script.path],
        workingDirectory: tempDir.path,
        runId: 'run-to',
        nodeId: 'n2',
      ),
    );
    expect(refused.failureOrNull, isA<NodeExecutionFailure>());

    // Re-enable real termination and normal confirmation window for retry.
    winKiller
      ?..skipTerminateForTesting = false
      ..confirmationTimeout = const Duration(seconds: 5);
    posixKiller
      ?..skipTerminateForTesting = false
      ..gracePeriod = const Duration(milliseconds: 100)
      ..confirmationTimeout = const Duration(seconds: 5);

    final retryRes = await unconfirmedManaged.killer.killTree(runId: 'run-to');
    expect(retryRes.isSuccess, isTrue);
    expect(unconfirmedManaged.tracker.isRunCancelling('run-to'), isFalse);
  });

  test(
    'PosixProcessPlatform spawns child as leader of its own process group '
    '(pgid == pid)',
    skip: Platform.isWindows
        ? 'POSIX process group ownership applies to Linux and macOS only.'
        : null,
    () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_pgid_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final script = File(p.join(tempDir.path, 'sleep.dart'));
      await script.writeAsString('''
import 'dart:async';
Future<void> main() => Future<void>.delayed(const Duration(seconds: 30));
''');

      final platform = currentProcessPlatform();
      final child = await platform.start(Platform.resolvedExecutable, <String>[
        script.path,
      ], workingDirectory: tempDir.path);
      addTearDown(() => platform.terminateTree(child));

      final ps = await Process.run('ps', <String>[
        '-o',
        'pgid=',
        '-p',
        '${child.pid}',
      ]);
      expect(ps.exitCode, 0);
      final childPgid = int.parse((ps.stdout as String).trim());
      expect(childPgid, child.pid);
    },
  );
}
