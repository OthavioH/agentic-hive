import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_target_preparer.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/active_run_lookup.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/worktree_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _EmptyActiveRuns implements ActiveRunLookup {
  @override
  Future<Result<Set<String>>> activeTargetFolders(String workspaceId) async =>
      const Success({});
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
  late WorktreeService worktrees;
  late WorkspacePreparationService workspacePreparation;

  final baseWorkspace = Workspace(
    id: 'ws-1',
    name: 'repo',
    rootPath: '',
    isGit: true,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  Workspace workspace() => baseWorkspace.copyWith(rootPath: repo.path);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hive_target_preparer_');
    repo = Directory(p.join(root.path, 'repo'))..createSync();
    await _git(repo.path, ['init', '-b', 'main']);
    File(p.join(repo.path, 'a.txt')).writeAsStringSync('a');
    await _git(repo.path, ['add', '.']);
    await _git(repo.path, ['commit', '-m', 'init']);

    const git = GitClient(IoProcessRunner());
    worktrees = WorktreeService(
      git: git,
      activeRuns: _EmptyActiveRuns(),
      worktreesDir: p.join(root.path, 'worktrees'),
    );
    workspacePreparation = const WorkspacePreparationService(git: git);
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // Best effort cleanup of temp folders.
    }
  });

  test('forTarget maps each RunTarget variant to its preparer', () {
    expect(
      RunTargetPreparer.forTarget(
        const RunTarget.primary(),
        worktrees: worktrees,
        workspacePreparation: workspacePreparation,
      ),
      isA<PrimaryCheckoutPreparer>(),
    );
    expect(
      RunTargetPreparer.forTarget(
        const RunTarget.worktree(worktreeId: 'wt-1'),
        worktrees: worktrees,
        workspacePreparation: workspacePreparation,
      ),
      isA<ExistingWorktreePreparer>(),
    );
    expect(
      RunTargetPreparer.forTarget(
        const RunTarget.newWorktree(),
        worktrees: worktrees,
        workspacePreparation: workspacePreparation,
      ),
      isA<NewWorktreePreparer>(),
    );
  });

  group('PrimaryCheckoutPreparer', () {
    test('claims workspace root and returns direct mode', () async {
      final claimed = <String>[];
      final result = await const PrimaryCheckoutPreparer().prepare(
        workspace: workspace(),
        runId: 'run-1',
        claim: (folder) async {
          claimed.add(folder);
          return null;
        },
      );

      expect(claimed, [repo.path]);
      final prepared = result.valueOrNull!;
      expect(prepared.targetFolder, repo.path);
      expect(prepared.isolationMode, WorkspaceIsolationMode.direct);
      expect(prepared.worktreePath, isNull);
    });

    test('returns conflict when claim fails', () async {
      const conflict = ConflictFailure('busy');
      final result = await const PrimaryCheckoutPreparer().prepare(
        workspace: workspace(),
        runId: 'run-1',
        claim: (_) async => conflict,
      );

      expect(result.failureOrNull, same(conflict));
    });
  });

  group('ExistingWorktreePreparer', () {
    test('returns UnexpectedFailure when worktree service is null', () async {
      final result =
          await const ExistingWorktreePreparer(
            worktreeId: 'wt-1',
            worktrees: null,
          ).prepare(
            workspace: workspace(),
            runId: 'run-1',
            claim: (_) async => null,
          );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(
        result.failureOrNull!.message,
        'Worktree service is not configured.',
      );
    });

    test(
      'returns NotFoundFailure for unknown id without calling claim',
      () async {
        var claimCalled = false;
        final result =
            await ExistingWorktreePreparer(
              worktreeId: 'missing',
              worktrees: worktrees,
            ).prepare(
              workspace: workspace(),
              runId: 'run-1',
              claim: (_) async {
                claimCalled = true;
                return null;
              },
            );

        expect(claimCalled, isFalse);
        expect(result.failureOrNull, isA<NotFoundFailure>());
        expect(
          result.failureOrNull!.message,
          'Worktree "missing" was not found.',
        );
      },
    );

    test('primaryWorktreeId claims rootPath and returns direct mode', () async {
      final claimed = <String>[];
      final result =
          await ExistingWorktreePreparer(
            worktreeId: primaryWorktreeId,
            worktrees: worktrees,
          ).prepare(
            workspace: workspace(),
            runId: 'run-1',
            claim: (folder) async {
              claimed.add(folder);
              return null;
            },
          );

      expect(claimed, [repo.path]);
      final prepared = result.valueOrNull!;
      expect(prepared.targetFolder, repo.path);
      expect(prepared.isolationMode, WorkspaceIsolationMode.direct);
      expect(prepared.worktreePath, isNull);
    });

    test(
      'created worktree claims its path and returns worktree mode',
      () async {
        final created = (await worktrees.create(
          workspace(),
          const CreateWorktreeRequest(name: 'wt-1', branch: 'feat/wt-1'),
        )).valueOrNull!;
        final claimed = <String>[];

        final result =
            await ExistingWorktreePreparer(
              worktreeId: created.id,
              worktrees: worktrees,
            ).prepare(
              workspace: workspace(),
              runId: 'run-1',
              claim: (folder) async {
                claimed.add(folder);
                return null;
              },
            );

        expect(claimed, [created.path]);
        final prepared = result.valueOrNull!;
        expect(prepared.targetFolder, created.path);
        expect(prepared.isolationMode, WorkspaceIsolationMode.worktree);
        expect(prepared.worktreePath, created.path);
        expect(prepared.worktreeBranch, 'feat/wt-1');
      },
    );
  });

  group('NewWorktreePreparer', () {
    test(
      'defaults blank or null name and branch to runId and hive/<runId>',
      () async {
        final preparer = NewWorktreePreparer(
          name: '   ',
          worktrees: worktrees,
          workspacePreparation: workspacePreparation,
        );
        final result = await preparer.prepare(
          workspace: workspace(),
          runId: 'run-42',
          claim: (_) async => null,
        );

        final prepared = result.valueOrNull!;
        expect(prepared.isolationMode, WorkspaceIsolationMode.worktree);
        expect(p.basename(prepared.worktreePath!), 'run-42');
        expect(prepared.worktreeBranch, 'hive/run-42');
        expect(Directory(prepared.worktreePath!).existsSync(), isTrue);
      },
    );

    test('cleans up created worktree when claim returns a conflict', () async {
      const conflict = ConflictFailure('busy');
      final preparer = NewWorktreePreparer(
        name: 'wt-conflict',
        worktrees: worktrees,
        workspacePreparation: workspacePreparation,
      );

      final result = await preparer.prepare(
        workspace: workspace(),
        runId: 'run-99',
        claim: (_) async => conflict,
      );

      expect(result.failureOrNull, same(conflict));
      final wtDir = Directory(
        p.join(root.path, 'worktrees', 'ws-1', 'wt-conflict'),
      );
      expect(wtDir.existsSync(), isFalse);
    });

    test('discard removes the created worktree directory', () async {
      final preparer = NewWorktreePreparer(
        name: 'wt-discard',
        worktrees: worktrees,
        workspacePreparation: workspacePreparation,
      );
      final prepared = (await preparer.prepare(
        workspace: workspace(),
        runId: 'run-77',
        claim: (_) async => null,
      )).valueOrNull!;
      expect(Directory(prepared.worktreePath!).existsSync(), isTrue);

      await preparer.discard(workspace(), prepared);

      expect(Directory(prepared.worktreePath!).existsSync(), isFalse);
    });
  });
}
