import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/active_run_lookup.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/worktree_service.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../shelf/support.dart';

final class _FakeLookup implements ActiveRunLookup {
  Set<String> folders = {};

  @override
  Future<Result<Set<String>>> activeTargetFolders(String workspaceId) async =>
      Success(folders);
}

final class _FailingRemoveRunner implements ProcessRunner {
  new({required this.deleteFolder, this.unregisterRepo});

  final bool deleteFolder;
  final String? unregisterRepo;
  final calls = <List<String>>[];

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) async {
    calls.add(arguments);
    final i = arguments.indexOf('worktree');
    if (i >= 0 && i + 1 < arguments.length && arguments[i + 1] == 'remove') {
      final target = arguments.last;
      if (deleteFolder) {
        await Directory(target).delete(recursive: true);
      }
      if (unregisterRepo != null) {
        final admin = Directory(
          p.join(unregisterRepo!, '.git', 'worktrees', p.basename(target)),
        );
        if (admin.existsSync()) await admin.delete(recursive: true);
        final dotGit = File(p.join(target, '.git'));
        if (dotGit.existsSync()) await dotGit.delete();
      }
      return const ProcessRunResult(
        exitCode: 1,
        stdout: '',
        stderr: 'error: failed to delete: Permission denied',
      );
    }
    return await const IoProcessRunner().run(
      executable,
      arguments,
      timeout: timeout,
    );
  }
}

Future<void> _git(String dir, List<String> args) async {
  final result = await Process.run('git', [
    '-c',
    'user.name=Test',
    '-c',
    'user.email=test@example.com',
    ...args,
  ], workingDirectory: dir);
  if (result.exitCode != 0) fail('git ${args.join(' ')}: ${result.stderr}');
}

void main() {
  late Directory root;
  late Directory repo;
  late _FakeLookup lookup;
  late WorktreeService service;

  final workspace = Workspace(
    id: 'ws-1',
    name: 'repo',
    rootPath: '',
    isGit: true,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hive_wt_service_');
    repo = Directory(p.join(root.path, 'repo'))..createSync();
    await _git(repo.path, ['init', '-b', 'main']);
    File(p.join(repo.path, 'a.txt')).writeAsStringSync('a');
    await _git(repo.path, ['add', '.']);
    await _git(repo.path, ['commit', '-m', 'init']);
    lookup = _FakeLookup();
    service = WorktreeService(
      git: const GitClient(IoProcessRunner()),
      activeRuns: lookup,
      worktreesDir: p.join(root.path, 'worktrees'),
    );
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // Best effort cleanup of temp folders.
    }
  });

  Workspace target() => workspace.copyWith(rootPath: repo.path);

  test('removal is blocked while a run is active in the worktree', () async {
    final created = (await service.create(
      target(),
      const CreateWorktreeRequest(name: 'busy'),
    )).valueOrNull!;
    lookup.folders = {created.path};

    final result = await service.remove(target(), 'busy');

    expect(result, isA<FailureResult<RemoveWorktreeResponse>>());
    expect(result.failureOrNull, isA<ConflictFailure>());
    expect(Directory(created.path).existsSync(), isTrue);
  });

  test('removal works once the run is no longer active', () async {
    final created = (await service.create(
      target(),
      const CreateWorktreeRequest(name: 'free'),
    )).valueOrNull!;
    lookup.folders = {p.join(repo.path)};

    final result = await service.remove(target(), 'free');

    expect(result.isSuccess, isTrue);
    expect(Directory(created.path).existsSync(), isFalse);
  });

  test('inspectHead returns the HEAD commit and a clean flag', () async {
    final headResult = await Process.run('git', [
      '-C',
      repo.path,
      'rev-parse',
      'HEAD',
    ]);
    final expectedCommit = (headResult.stdout as String).trim();

    final result = await service.inspectHead(repo.path);

    expect(result.isSuccess, isTrue);
    final head = result.valueOrNull!;
    expect(head.commit, expectedCommit);
    expect(head.hasUncommittedChanges, isFalse);
  });

  test('inspectHead reports uncommitted changes', () async {
    await File(p.join(repo.path, 'untracked.txt')).writeAsString('hi');

    final result = await service.inspectHead(repo.path);

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull!.hasUncommittedChanges, isTrue);
  });

  test('inspectHead fails on a folder without commits', () async {
    final emptyRepo = Directory(p.join(root.path, 'empty-repo'))..createSync();
    await Process.run('git', ['init', emptyRepo.path]);

    final result = await service.inspectHead(emptyRepo.path);

    expect(result, isA<FailureResult<FolderHead>>());
  });

  group('remove', () {
    late LogCapture logs;

    setUp(() {
      logs = LogCapture()..attach();
    });

    tearDown(() => logs.detach());

    WorktreeService serviceWithRunner(_FailingRemoveRunner runner) =>
        WorktreeService(
          git: GitClient(runner),
          activeRuns: lookup,
          worktreesDir: p.join(root.path, 'worktrees'),
        );

    test('succeeds, prunes, deletes merged branch and logs warning when git '
        'remove fails but the folder is gone', () async {
      await service.create(target(), const CreateWorktreeRequest(name: 'gone'));
      final runner = _FailingRemoveRunner(deleteFolder: true);

      final result = await serviceWithRunner(runner).remove(target(), 'gone');

      expect(result.isSuccess, isTrue);
      final body = result.valueOrNull!;
      expect(body.deleted, isTrue);
      expect(body.branchDeleted, isTrue);
      expect(
        runner.calls,
        containsAll([
          ['-C', repo.path, 'worktree', 'prune'],
          ['-C', repo.path, 'branch', '-d', 'gone'],
        ]),
      );
      final warnings = logs.records.where((r) => r.level == Level.WARNING);
      expect(
        warnings.any(
          (r) =>
              r.object is LogEvent &&
              (r.object! as LogEvent).name == 'worktrees.remove_failed' &&
              (r.object! as LogEvent).fields['workspaceId'] == 'ws-1' &&
              (r.object! as LogEvent).fields['worktreeId'] == 'gone' &&
              '${r.error}'.contains('Permission denied'),
        ),
        isTrue,
      );
    });

    test('keeps unmerged branch with notice when git remove fails and folder '
        'is gone', () async {
      final created = (await service.create(
        target(),
        const CreateWorktreeRequest(name: 'wip-gone'),
      )).valueOrNull!;
      File(p.join(created.path, 'b.txt')).writeAsStringSync('b');
      await _git(created.path, ['add', '.']);
      await _git(created.path, ['commit', '-m', 'work']);
      final runner = _FailingRemoveRunner(deleteFolder: true);

      final result = await serviceWithRunner(runner)
          .remove(target(), 'wip-gone');

      expect(result.isSuccess, isTrue);
      final body = result.valueOrNull!;
      expect(body.deleted, isTrue);
      expect(body.branchDeleted, isFalse);
      expect(body.notice, contains('wip-gone'));
    });

    test('returns ConflictFailure without git stderr when git remove fails '
        'and the folder remains', () async {
      final created = (await service.create(
        target(),
        const CreateWorktreeRequest(name: 'locked'),
      )).valueOrNull!;
      final runner = _FailingRemoveRunner(deleteFolder: false);

      final result = await serviceWithRunner(runner).remove(target(), 'locked');

      expect(result.failureOrNull, isA<ConflictFailure>());
      final message = result.failureOrNull!.message;
      expect(message, contains('in use or could not be deleted'));
      expect(message, contains('locked'));
      expect(message, isNot(contains('Permission denied')));
      expect(Directory(created.path).existsSync(), isTrue);
      final warnings = logs.records.where((r) => r.level == Level.WARNING);
      expect(
        warnings.any(
          (r) =>
              r.object is LogEvent &&
              (r.object! as LogEvent).name == 'worktrees.remove_failed' &&
              (r.object! as LogEvent).fields['workspaceId'] == 'ws-1' &&
              (r.object! as LogEvent).fields['worktreeId'] == 'locked' &&
              '${r.error}'.contains('Permission denied'),
        ),
        isTrue,
      );
    });

    test('retries and removes an orphaned folder after git unregisters it on '
        'delete failure', () async {
      final created = (await service.create(
        target(),
        const CreateWorktreeRequest(name: 'orphan'),
      )).valueOrNull!;
      final runner = _FailingRemoveRunner(
        deleteFolder: false,
        unregisterRepo: repo.path,
      );

      final first = await serviceWithRunner(runner).remove(target(), 'orphan');
      expect(first.failureOrNull, isA<ConflictFailure>());
      expect(Directory(created.path).existsSync(), isTrue);

      final withoutForce = await service.remove(target(), 'orphan');
      expect(withoutForce.failureOrNull, isA<ConflictFailure>());
      expect(withoutForce.failureOrNull!.message, contains('uncommitted'));

      final retried = await service.remove(target(), 'orphan', force: true);
      expect(retried.isSuccess, isTrue);
      final body = retried.valueOrNull!;
      expect(body.deleted, isTrue);
      expect(body.branchDeleted, isFalse);
      expect(body.notice, isNotNull);
      expect(Directory(created.path).existsSync(), isFalse);

      final after = await service.remove(target(), 'orphan', force: true);
      expect(after.failureOrNull, isA<NotFoundFailure>());
    });

    test(
      'is idempotent for a registered worktree whose folder is already gone',
      () async {
        final created = (await service.create(
          target(),
          const CreateWorktreeRequest(name: 'stale'),
        )).valueOrNull!;
        await Directory(created.path).delete(recursive: true);

        final first = await service.remove(target(), 'stale');
        expect(first.isSuccess, isTrue);

        final listed = await Process.run('git', [
          '-C',
          repo.path,
          'worktree',
          'list',
          '--porcelain',
        ]);
        expect(listed.stdout as String, isNot(contains('stale')));

        final second = await service.remove(target(), 'stale');
        expect(second.failureOrNull, isA<NotFoundFailure>());
      },
    );

    test('preserves primary, unknown, and dirty guards', () async {
      final primary = await service.remove(target(), primaryWorktreeId);
      expect(primary.failureOrNull, isA<ValidationFailure>());

      final unknown = await service.remove(target(), 'missing');
      expect(unknown.failureOrNull, isA<NotFoundFailure>());

      final created = (await service.create(
        target(),
        const CreateWorktreeRequest(name: 'dirty'),
      )).valueOrNull!;
      File(p.join(created.path, 'dirty.txt')).writeAsStringSync('x');

      final blocked = await service.remove(target(), 'dirty');
      expect(blocked.failureOrNull, isA<ConflictFailure>());
      expect(blocked.failureOrNull!.message, contains('uncommitted'));
      expect(Directory(created.path).existsSync(), isTrue);

      final forced = await service.remove(target(), 'dirty', force: true);
      expect(forced.isSuccess, isTrue);
      expect(Directory(created.path).existsSync(), isFalse);
    });
  });
}
