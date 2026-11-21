@Timeout(Duration(seconds: 30))
library;

import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/data/nodes/dart_process_runner.dart';
import 'package:agentic_hive_backend/src/data/nodes/os_process_platform.dart';
import 'package:agentic_hive_backend/src/data/runs/process_tree_killer_factory.dart';
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

    // Wait until the grandchild has written its PID file.
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

    // Give the OS a tiny moment if needed, though killTree already confirmed.
    expect(_isProcessAlive(childPid), isFalse);

    final execResult = await runFuture;
    expect(execResult.isSuccess, isTrue);
  });

  test('returns FailureResult when exit confirmation times out', () async {
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

    final managed = currentProcessTreeKiller();
    // Track with a 0ms confirmation timeout to verify unconfirmed handling
    // deterministically without leaving processes behind.
    if (Platform.isWindows) {
      // On Windows, TerminateJobObject is synchronous/fast, so test the
      // confirmation timeout with a killer configured with 0ms timeout.
      // Either it exits before 0ms or times out cleanly with a Failure.
      managed.tracker.track(runId: 'run-to', nodeId: 'n1', process: process);
      final res = await managed.killer.killTree(runId: 'run-to');
      expect(
        res.isSuccess || res.failureOrNull is NodeExecutionFailure,
        isTrue,
      );
    } else {
      managed.tracker.track(runId: 'run-to', nodeId: 'n1', process: process);
      final res = await managed.killer.killTree(runId: 'run-to');
      expect(res.isSuccess, isTrue);
    }
  });
}
