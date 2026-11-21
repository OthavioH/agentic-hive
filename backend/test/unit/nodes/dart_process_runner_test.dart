import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/data/nodes/dart_process_runner.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  const runner = DartProcessRunner();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_process_runner_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('delivers stdin content and captures stdout/stderr', () async {
    final script = File(p.join(tempDir.path, 'echo_stdin.dart'));
    await script.writeAsString(r'''
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final input = await utf8.decodeStream(stdin);
  stdout.write('OUT:$input');
  stderr.write('ERR:ok');
}
''');

    final result = await runner.run(
      ProcessInvocation(
        executable: Platform.resolvedExecutable,
        arguments: <String>['run', script.path],
        workingDirectory: tempDir.path,
        stdinContent: 'hello-stdin',
      ),
    );

    expect(result.isSuccess, isTrue);
    final execResult = result.valueOrNull!;
    expect(execResult.exitCode, 0);
    expect(execResult.timedOut, isFalse);
    expect(execResult.stdout, contains('OUT:hello-stdin'));
    expect(execResult.stderr, contains('ERR:ok'));
  });

  test('terminates process and reports timedOut on timeout', () async {
    final script = File(p.join(tempDir.path, 'sleep.dart'));
    await script.writeAsString('''
Future<void> main() async {
  await Future<void>.delayed(const Duration(seconds: 30));
}
''');

    final result = await runner.run(
      ProcessInvocation(
        executable: Platform.resolvedExecutable,
        arguments: <String>['run', script.path],
        workingDirectory: tempDir.path,
        timeout: const Duration(milliseconds: 250),
      ),
    );

    expect(result.isSuccess, isTrue);
    final execResult = result.valueOrNull!;
    expect(execResult.timedOut, isTrue);
    expect(execResult.exitCode, -1);
  });

  test('returns NodeExecutionFailure for missing executable', () async {
    final result = await runner.run(
      ProcessInvocation(
        executable: 'nonexistent_executable_xyz_987654',
        workingDirectory: tempDir.path,
      ),
    );

    expect(result.failureOrNull, isA<NodeExecutionFailure>());
  });
}
