import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../http/support/harness.dart';

/// A temp git repo whose `post-checkout` hook blocks until released.
final class SlowHookRepo {
  new _(this.dir, this._startedFile, this._releaseFile);

  /// The repository root directory (on branch `main` with one commit).
  final Directory dir;

  final File _startedFile;
  final File _releaseFile;

  /// Whether the `post-checkout` hook has begun blocking.
  bool get hookStarted => _startedFile.existsSync();

  /// Creates a temp git repository with a blocking `post-checkout` hook.
  static Future<SlowHookRepo> create({
    bool fail = false,
    Duration maxBlock = const Duration(seconds: 60),
  }) async {
    final controlDir = await createTempDir();
    final startedFile = File(p.join(controlDir.path, 'started'));
    final releaseFile = File(p.join(controlDir.path, 'release'));

    final repoDir = await createTempDir();
    final repo = SlowHookRepo._(repoDir, startedFile, releaseFile);
    addTearDown(repo.release);

    await _git(repoDir.path, ['init', '-b', 'main']);
    await _git(repoDir.path, ['config', 'user.email', 't@example.com']);
    await _git(repoDir.path, ['config', 'user.name', 'Test']);
    await File(p.join(repoDir.path, 'a.txt')).writeAsString('a');
    await _git(repoDir.path, ['add', '.']);
    await _git(repoDir.path, ['commit', '-m', 'init']);

    final hooksDir = Directory(p.join(repoDir.path, '.git', 'hooks'));
    await hooksDir.create(recursive: true);
    final hookFile = File(p.join(hooksDir.path, 'post-checkout'));

    final startedPath = _shPath(startedFile.path);
    final releasePath = _shPath(releaseFile.path);
    final maxIterations = maxBlock.inMilliseconds ~/ 100;
    final tail = fail
        ? "echo 'post-checkout hook failed on purpose' >&2\nexit 1\n"
        : 'exit 0\n';

    final script =
        '#!/bin/sh\n'
        ": > '$startedPath'\n"
        'i=0\n'
        "while [ ! -f '$releasePath' ] && [ \$i -lt $maxIterations ]; do "
        'sleep 0.1; i=\$((i+1)); done\n'
        '$tail';

    await hookFile.writeAsString(script);
    // Test-only POSIX permission bit; Git for Windows executes hooks via sh.
    if (!Platform.isWindows) {
      final chmod = await Process.run('chmod', ['+x', hookFile.path]);
      if (chmod.exitCode != 0) {
        throw StateError('chmod +x failed: ${chmod.stderr}');
      }
    }

    return repo;
  }

  /// Waits until the `post-checkout` hook has started blocking.
  Future<void> waitUntilHookStarted({Duration timeout = ioTimeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (!hookStarted) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'post-checkout hook did not start within $timeout',
          timeout,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Releases the blocked `post-checkout` hook (idempotent).
  Future<void> release() async {
    if (!_releaseFile.parent.existsSync()) return;
    if (!_releaseFile.existsSync()) {
      await _releaseFile.writeAsString('');
    }
  }

  static String _shPath(String path) => path.replaceAll(r'\', '/');

  static Future<void> _git(String dir, List<String> args) async {
    final result = await Process.run('git', ['-C', dir, ...args]);
    if (result.exitCode != 0) {
      throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
    }
  }
}
