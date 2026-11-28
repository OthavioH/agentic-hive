import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../http/support/harness.dart';

/// A temporary git repository whose `post-checkout` hook blocks until released.
final class SlowHookRepo {
  new _({
    required this.dir,
    required this._enteredFile,
    required this._releaseFile,
  });

  /// The root directory of the temporary git repository.
  final Directory dir;

  final File _enteredFile;
  final File _releaseFile;

  /// Creates a temp git repo (`init -b main`, user config, one commit of
  /// `a.txt`) whose `post-checkout` hook blocks until [release] is called or
  /// [maxBlock] passes, then exits with [hookExitCode].
  static Future<SlowHookRepo> create({
    Duration maxBlock = const Duration(seconds: 20),
    int hookExitCode = 0,
  }) async {
    final dir = await createTempDir();
    final controlDir = await createTempDir();
    final enteredFile = File(p.join(controlDir.path, 'entered'));
    final releaseFile = File(p.join(controlDir.path, 'release'));

    await _git(dir.path, ['init', '-b', 'main']);
    await _git(dir.path, ['config', 'user.email', 't@example.com']);
    await _git(dir.path, ['config', 'user.name', 'Test']);
    File(p.join(dir.path, 'a.txt')).writeAsStringSync('a');
    await _git(dir.path, ['add', '.']);
    await _git(dir.path, ['commit', '-m', 'init']);

    // sh needs POSIX separators on Windows (Git for Windows bundled sh).
    final enteredPosix = enteredFile.path.replaceAll(r'\', '/');
    final releasePosix = releaseFile.path.replaceAll(r'\', '/');
    final ticks = maxBlock.inMilliseconds ~/ 100;

    final hookPath = p.join(dir.path, '.git', 'hooks', 'post-checkout');
    final whileLine =
        "while [ ! -f '$releasePosix' ] && [ \"\$i\" -lt $ticks ]; "
        r'do sleep 0.1; i=$((i+1)); done';
    final hookScript = <String>[
      '#!/bin/sh',
      ": > '$enteredPosix'",
      'i=0',
      whileLine,
      'exit $hookExitCode',
      '',
    ].join('\n');
    await File(hookPath).writeAsString(hookScript);

    // Test-only platform check: Windows Git runs hooks via sh without +x.
    if (!Platform.isWindows) {
      final chmod = await Process.run('chmod', ['+x', hookPath]);
      if (chmod.exitCode != 0) {
        throw StateError('chmod +x failed: ${chmod.stderr}');
      }
    }

    final repo = SlowHookRepo._(
      dir: dir,
      enteredFile: enteredFile,
      releaseFile: releaseFile,
    );
    // Registered after createTempDir so LIFO teardown releases the hook first.
    addTearDown(repo.release);
    return repo;
  }

  /// Whether the `post-checkout` hook has started executing.
  bool get hookEntered => _enteredFile.existsSync();

  /// Completes once the hook has started; throws [TimeoutException] on
  /// [timeout].
  Future<void> waitUntilHookEntered({Duration timeout = ioTimeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (!hookEntered) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'post-checkout hook did not enter within $timeout',
          timeout,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  /// Writes the release marker file so the blocked hook can exit; idempotent.
  void release() {
    if (!_releaseFile.existsSync()) {
      _releaseFile.writeAsStringSync('');
    }
  }

  static Future<void> _git(String dir, List<String> args) async {
    final result = await Process.run('git', ['-C', dir, ...args]);
    if (result.exitCode != 0) {
      throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
    }
  }
}
