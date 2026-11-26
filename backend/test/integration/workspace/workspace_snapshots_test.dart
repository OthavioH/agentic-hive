@Timeout(Duration(seconds: 60))
library;

import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_event_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/drift_snapshot_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/shadow_snapshot_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _MissingGitProcessRunner implements ProcessRunner {
  const new();

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) async => const ProcessRunResult(
    exitCode: -1,
    stdout: '',
    stderr: '',
    launchError: 'No such file or directory',
  );
}

final class _RecordingProcessRunner implements ProcessRunner {
  new();

  final List<List<String>> calls = [];
  final _inner = const IoProcessRunner();

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) {
    calls.add(arguments);
    return _inner.run(executable, arguments, timeout: timeout);
  }
}

void main() {
  late Directory tempRoot;
  late Directory dataDir;
  late Directory workspaceDir;
  late AppDatabase db;
  late DriftRunRepository runs;
  late DriftCheckpointRepository checkpoints;
  late DriftRunEventRepository events;
  late DriftSnapshotRepository snapshots;
  late GitClient git;
  late WorkspaceCapabilitiesService capabilitiesService;
  late WorkspacePreparationService preparationService;
  late ShadowSnapshotService snapshotService;
  late RunService runService;

  final sampleWorkflow = Workflow(
    id: 'wf-1',
    name: 'Snapshot Flow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Step 1',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 21, 9),
    updatedAt: DateTime.utc(2026, 11, 21, 9),
  );

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('hive_f8_test_');
    dataDir = Directory(p.join(tempRoot.path, 'data'))..createSync();
    workspaceDir = Directory(p.join(tempRoot.path, 'workspace'))..createSync();
    db = AppDatabase.open(File(p.join(dataDir.path, 'hive.db')));
    await db.customSelect('SELECT 1').get();

    runs = DriftRunRepository(db);
    checkpoints = DriftCheckpointRepository(db);
    events = DriftRunEventRepository(db);
    snapshots = DriftSnapshotRepository(db);
    git = const GitClient(IoProcessRunner());

    capabilitiesService = WorkspaceCapabilitiesService(git);
    preparationService = WorkspacePreparationService(git: git);
    snapshotService = ShadowSnapshotService(
      git: git,
      runs: runs,
      snapshots: snapshots,
      events: events,
      snapshotsDir: p.join(dataDir.path, 'snapshots'),
      pathContext: p.context,
    );
    runService = RunService(
      runs: runs,
      checkpoints: checkpoints,
      events: events,
      snapshots: snapshotService,
      workspacePreparation: preparationService,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<Run> createRun({
    required String id,
    required String wsPath,
    RunStatus status = RunStatus.paused,
    WorkspaceIsolationMode isolationMode = WorkspaceIsolationMode.direct,
    String? worktreePath,
    String? worktreeBranch,
  }) async {
    final run = Run(
      id: id,
      workflowId: 'wf-1',
      workflowName: sampleWorkflow.name,
      workflowDefinition: sampleWorkflow,
      workspaceRoot: wsPath,
      status: status,
      startedAt: DateTime.utc(2026, 11, 21, 10),
      isolationMode: isolationMode,
      worktreePath: worktreePath,
      worktreeBranch: worktreeBranch,
    );
    final result = await runs.create(run);
    expect(result, isA<Success<Run>>());
    return run;
  }

  Future<void> runGit(List<String> args) async {
    final res = await git.runChecked(args);
    expect(res, isA<Success<String>>());
  }

  group('WorkspaceCapabilitiesService', () {
    test('reports gitAvailable=false gracefully when git is missing', () async {
      const missingService = WorkspaceCapabilitiesService(
        GitClient(_MissingGitProcessRunner()),
      );
      final result = await missingService.getCapabilities(
        path: workspaceDir.path,
      );
      final caps = (result as Success<WorkspaceCapabilities>).value;
      expect(caps.gitAvailable, isFalse);
      expect(caps.gitVersion, isNull);
      expect(caps.isGitRepo, isFalse);
      expect(caps.hasCommits, isFalse);
    });

    test(
      'distinguishes non-git, unborn HEAD, and committed git repo',
      () async {
        final nonGit = (await capabilitiesService.getCapabilities(
          path: workspaceDir.path,
        ) as Success<WorkspaceCapabilities>).value;
        expect(nonGit.gitAvailable, isTrue);
        expect(nonGit.gitVersion, isNotNull);
        expect(nonGit.isGitRepo, isFalse);
        expect(nonGit.hasCommits, isFalse);

        await runGit(['init', workspaceDir.path]);
        final unborn = (await capabilitiesService.getCapabilities(
          path: workspaceDir.path,
        ) as Success<WorkspaceCapabilities>).value;
        expect(unborn.isGitRepo, isTrue);
        expect(unborn.hasCommits, isFalse);

        await File(p.join(workspaceDir.path, 'README.md'))
            .writeAsString('hello\n');
        await runGit(['-C', workspaceDir.path, 'config', 'user.name', 'Test']);
        await runGit([
          '-C',
          workspaceDir.path,
          'config',
          'user.email',
          'test@example.com',
        ]);
        await runGit(['-C', workspaceDir.path, 'add', '.']);
        await runGit(['-C', workspaceDir.path, 'commit', '-m', 'init']);

        final committed = (await capabilitiesService.getCapabilities(
          path: workspaceDir.path,
        ) as Success<WorkspaceCapabilities>).value;
        expect(committed.isGitRepo, isTrue);
        expect(committed.hasCommits, isTrue);
      },
    );
  });

  group('ShadowSnapshotService', () {
    test('captures non-git snapshots, deduplicates unchanged trees, and '
        'computes diffs', () async {
      await createRun(id: 'run-1', wsPath: workspaceDir.path);
      await File(p.join(workspaceDir.path, 'doc.txt')).writeAsString('v1\n');
      await File(p.join(workspaceDir.path, 'notes.md'))
          .writeAsString('initial\n');

      // Snapshot 1: initial 2 added files.
      final snap1 = (await snapshotService.captureSnapshot(
        runId: 'run-1',
        targetFolder: workspaceDir.path,
        nodeId: 'n1',
      ) as Success<Snapshot>).value;
      expect(snap1.kind, SnapshotKind.preNode);
      expect(snap1.addedCount, 2);
      expect(snap1.modifiedCount, 0);
      expect(snap1.deletedCount, 0);

      final diff1 = (await snapshotService.getSnapshotDiff(
        'run-1',
        snap1.id,
      ) as Success<SnapshotDiff>).value;
      expect(
        diff1.files.map((f) => (f.path, f.changeType)),
        unorderedEquals([
          ('doc.txt', SnapshotChangeType.added),
          ('notes.md', SnapshotChangeType.added),
        ]),
      );

      // Snapshot 2: unchanged working tree reuses commitHash with +0 ~0 -0.
      final snap2 = (await snapshotService.captureSnapshot(
        runId: 'run-1',
        targetFolder: workspaceDir.path,
        nodeId: 'n2',
      ) as Success<Snapshot>).value;
      expect(snap2.commitHash, snap1.commitHash);
      expect(snap2.addedCount, 0);
      expect(snap2.modifiedCount, 0);
      expect(snap2.deletedCount, 0);

      final diff2 = (await snapshotService.getSnapshotDiff(
        'run-1',
        snap2.id,
      ) as Success<SnapshotDiff>).value;
      expect(diff2.files, isEmpty);

      // Snapshot 3: modify doc.txt, delete notes.md, add new.txt.
      await File(p.join(workspaceDir.path, 'doc.txt')).writeAsString('v2\n');
      await File(p.join(workspaceDir.path, 'notes.md')).delete();
      await File(p.join(workspaceDir.path, 'new.txt')).writeAsString('new\n');

      final snap3 = (await snapshotService.captureSnapshot(
        runId: 'run-1',
        targetFolder: workspaceDir.path,
        nodeId: 'n3',
      ) as Success<Snapshot>).value;
      expect(snap3.commitHash, isNot(snap1.commitHash));
      expect(snap3.addedCount, 1);
      expect(snap3.modifiedCount, 1);
      expect(snap3.deletedCount, 1);

      final diff3 = (await snapshotService.getSnapshotDiff(
        'run-1',
        snap3.id,
      ) as Success<SnapshotDiff>).value;
      expect(
        diff3.files.map((f) => (f.path, f.changeType)),
        unorderedEquals([
          ('new.txt', SnapshotChangeType.added),
          ('doc.txt', SnapshotChangeType.modified),
          ('notes.md', SnapshotChangeType.deleted),
        ]),
      );
    });

    test('respects .hiveignore, custom exclusions, and file size limit with '
        'snapshot.warning', () async {
      await createRun(id: 'run-excl', wsPath: workspaceDir.path);
      await File(p.join(workspaceDir.path, '.hiveignore'))
          .writeAsString('*.log\nignored_dir/\n');
      await File(p.join(workspaceDir.path, 'app.log'))
          .writeAsString('log line\n');
      final ignoredDir = Directory(p.join(workspaceDir.path, 'ignored_dir'))
        ..createSync();
      await File(p.join(ignoredDir.path, 'cache.bin')).writeAsString('cache');
      await File(p.join(workspaceDir.path, 'custom.tmp')).writeAsString('temp');
      await File(p.join(workspaceDir.path, 'huge.bin'))
          .writeAsBytes(List.filled(256, 1));
      await File(p.join(workspaceDir.path, 'keep.txt')).writeAsString('keep\n');

      final snap = (await snapshotService.captureSnapshot(
        runId: 'run-excl',
        targetFolder: workspaceDir.path,
        extraExclusions: const ['*.tmp'],
        maxFileSizeBytes: 100,
      ) as Success<Snapshot>).value;
      final diff = (await snapshotService.getSnapshotDiff(
        'run-excl',
        snap.id,
      ) as Success<SnapshotDiff>).value;
      expect(
        diff.files.map((f) => f.path),
        unorderedEquals(['.hiveignore', 'keep.txt']),
      );

      final evPage = (await events.listForRun(
        'run-excl',
      ) as Success<({List<RunEvent> items, int lastSequence})>).value;
      final warnings = evPage.items
          .where((e) => e.type == RunEventType.snapshotWarning)
          .toList();
      expect(warnings, hasLength(1));
      expect(warnings.single.payload['reason'], 'file_size_limit');
      expect(warnings.single.payload['path'], 'huge.bin');
    });

    test('restores files, removes untracked files, preserves .git and excluded '
        'files, and rejects running', () async {
      // Initialize user git repo to verify .git/ is preserved on restore.
      await runGit(['init', workspaceDir.path]);
      await runGit(['-C', workspaceDir.path, 'config', 'user.name', 'User']);
      await runGit([
        '-C',
        workspaceDir.path,
        'config',
        'user.email',
        'user@example.com',
      ]);
      await File(p.join(workspaceDir.path, '.hiveignore'))
          .writeAsString('excluded.dat\n');
      await File(p.join(workspaceDir.path, 'tracked.txt'))
          .writeAsString('original\n');
      await File(p.join(workspaceDir.path, 'to_delete.txt'))
          .writeAsString('stay\n');
      await File(p.join(workspaceDir.path, 'excluded.dat'))
          .writeAsString('secret\n');
      await runGit(['-C', workspaceDir.path, 'add', 'tracked.txt']);
      await runGit(['-C', workspaceDir.path, 'commit', '-m', 'user commit']);

      await createRun(
        id: 'run-restore',
        wsPath: workspaceDir.path,
        status: RunStatus.running,
      );

      final snap1 = (await snapshotService.captureSnapshot(
        runId: 'run-restore',
        targetFolder: workspaceDir.path,
        nodeId: 'n1',
      ) as Success<Snapshot>).value;

      // Mutate workspace: modify tracked.txt, delete to_delete.txt, create
      // untracked.txt.
      await File(p.join(workspaceDir.path, 'tracked.txt'))
          .writeAsString('mutated\n');
      await File(p.join(workspaceDir.path, 'to_delete.txt')).delete();
      await File(p.join(workspaceDir.path, 'untracked.txt'))
          .writeAsString('extra\n');

      // While running, restore must be rejected with ConflictFailure.
      final conflict = await snapshotService.restoreSnapshot(
        'run-restore',
        snap1.id,
      );
      expect(conflict, isA<FailureResult<RestoreSnapshotResponse>>());
      expect(
        (conflict as FailureResult<RestoreSnapshotResponse>).failure,
        isA<ConflictFailure>(),
      );

      // Pause run and restore.
      await runs.updateStatus('run-restore', status: RunStatus.paused);
      final restoreRes = (await snapshotService.restoreSnapshot(
        'run-restore',
        snap1.id,
      ) as Success<RestoreSnapshotResponse>).value;

      expect(restoreRes.restoredSnapshotId, snap1.id);
      expect(restoreRes.safetySnapshot.kind, SnapshotKind.safetyPreRestore);

      // Verify files restored & untracked removed & .git + excluded preserved.
      expect(
        await File(p.join(workspaceDir.path, 'tracked.txt')).readAsString(),
        'original\n',
      );
      expect(
        await File(p.join(workspaceDir.path, 'to_delete.txt')).readAsString(),
        'stay\n',
      );
      expect(
        File(p.join(workspaceDir.path, 'untracked.txt')).existsSync(),
        isFalse,
      );
      expect(
        await File(p.join(workspaceDir.path, 'excluded.dat')).readAsString(),
        'secret\n',
      );
      expect(Directory(p.join(workspaceDir.path, '.git')).existsSync(), isTrue);

      final evPage = (await events.listForRun(
        'run-restore',
      ) as Success<({List<RunEvent> items, int lastSequence})>).value;
      expect(
        evPage.items.map((e) => e.type),
        containsAll([
          RunEventType.snapshotCaptured,
          RunEventType.snapshotRestored,
        ]),
      );
    });
  });

  group('ShadowSnapshotService hardening', () {
    test(
      'shadow commands ignore user git config and commit with --no-verify',
      () async {
        final recorder = _RecordingProcessRunner();
        final service = ShadowSnapshotService(
          git: GitClient(recorder),
          runs: runs,
          snapshots: snapshots,
          events: events,
          snapshotsDir: p.join(dataDir.path, 'snapshots'),
          pathContext: p.context,
        );
        await createRun(id: 'run-cfg', wsPath: workspaceDir.path);
        await File(p.join(workspaceDir.path, 'a.txt')).writeAsString('a\n');
        expect(
          await service.captureSnapshot(
            runId: 'run-cfg',
            targetFolder: workspaceDir.path,
          ),
          isA<Success<Snapshot>>(),
        );

        final shadowCalls = recorder.calls
            .where(
              (c) =>
                  c.any((a) => a.startsWith('--git-dir=')) &&
                  !c.contains('config') &&
                  !c.contains('init'),
            )
            .toList();
        expect(shadowCalls, isNotEmpty);
        for (final call in shadowCalls) {
          expect(call, contains('commit.gpgsign=false'));
          expect(call, contains('core.fsmonitor=false'));
          expect(call, contains('core.excludesFile='));
          expect(call, contains('core.longpaths=true'));
          expect(call.any((a) => a.startsWith('core.hooksPath=')), isTrue);
        }
        final commit = shadowCalls.firstWhere((c) => c.contains('commit'));
        expect(commit, contains('--no-verify'));
      },
    );

    test('pins every snapshot under refs/hive/snap and clears a stale '
        'index.lock', () async {
      await createRun(id: 'run-pin', wsPath: workspaceDir.path);
      await File(p.join(workspaceDir.path, 'a.txt')).writeAsString('1\n');
      final first = (await snapshotService.captureSnapshot(
        runId: 'run-pin',
        targetFolder: workspaceDir.path,
      ) as Success<Snapshot>).value;

      final shadow = snapshotService.shadowRepoPath('run-pin');
      File(p.join(shadow, 'index.lock')).writeAsStringSync('');
      await File(p.join(workspaceDir.path, 'a.txt')).writeAsString('2\n');
      final second = (await snapshotService.captureSnapshot(
        runId: 'run-pin',
        targetFolder: workspaceDir.path,
      ) as Success<Snapshot>).value;
      expect(second.commitHash, isNot(first.commitHash));
      expect(File(p.join(shadow, 'index.lock')).existsSync(), isFalse);

      final refs = (await git.runChecked([
        '--git-dir=$shadow',
        'for-each-ref',
        'refs/hive/snap/',
        '--format=%(refname)',
      ]) as Success<String>).value;
      expect(refs, contains('refs/hive/snap/${first.id}'));
      expect(refs, contains('refs/hive/snap/${second.id}'));
    });

    test('size guard also applies to tracked files that grow and escapes '
        'glob characters in names', () async {
      await createRun(id: 'run-grow', wsPath: workspaceDir.path);
      await File(p.join(workspaceDir.path, 'grow.txt')).writeAsString('s\n');
      await File(p.join(workspaceDir.path, '[big]#.bin'))
          .writeAsBytes(List.filled(10, 1));
      await File(p.join(workspaceDir.path, 'other.bin'))
          .writeAsBytes(List.filled(10, 1));
      // First capture without a limit tracks the files.
      await snapshotService.captureSnapshot(
        runId: 'run-grow',
        targetFolder: workspaceDir.path,
        maxFileSizeBytes: null,
      );

      await File(p.join(workspaceDir.path, 'grow.txt'))
          .writeAsBytes(List.filled(500, 2));
      await File(p.join(workspaceDir.path, '[big]#.bin'))
          .writeAsBytes(List.filled(500, 2));
      await File(p.join(workspaceDir.path, 'other.bin'))
          .writeAsBytes(List.filled(11, 3));

      final snap = (await snapshotService.captureSnapshot(
        runId: 'run-grow',
        targetFolder: workspaceDir.path,
        maxFileSizeBytes: 100,
      ) as Success<Snapshot>).value;
      final shadow = snapshotService.shadowRepoPath('run-grow');
      final tree = (await git.runChecked([
        '--git-dir=$shadow',
        'ls-tree',
        '-r',
        '--name-only',
        snap.commitHash,
      ]) as Success<String>).value;
      final blobSize = (await git.runChecked([
        '--git-dir=$shadow',
        'cat-file',
        '-s',
        '${snap.commitHash}:other.bin',
      ]) as Success<String>).value;
      // `other.bin` stays under the limit and is captured in its new form;
      // grown tracked files are dropped from the snapshot.
      expect(blobSize.trim(), '11');
      expect(tree, contains('other.bin'));
      expect(tree, isNot(contains('grow.txt')));
      expect(tree, isNot(contains('[big]')));

      final evPage = (await events.listForRun(
        'run-grow',
      ) as Success<({List<RunEvent> items, int lastSequence})>).value;
      final warned = evPage.items
          .where((e) => e.type == RunEventType.snapshotWarning)
          .map((e) => e.payload['path'])
          .toList();
      expect(warned, unorderedEquals(['grow.txt', '[big]#.bin']));
    });

    test(
      'restore reuses the persisted exclusions of the last capture',
      () async {
        await createRun(id: 'run-opts', wsPath: workspaceDir.path);
        await File(p.join(workspaceDir.path, 'keep.txt')).writeAsString('k\n');
        final snap = (await snapshotService.captureSnapshot(
          runId: 'run-opts',
          targetFolder: workspaceDir.path,
          extraExclusions: const ['*.cache'],
        ) as Success<Snapshot>).value;
        await File(p.join(workspaceDir.path, 'x.cache')).writeAsString('c\n');
        await File(p.join(workspaceDir.path, 'new.txt')).writeAsString('n\n');

        expect(
          await snapshotService.restoreSnapshot('run-opts', snap.id),
          isA<Success<RestoreSnapshotResponse>>(),
        );
        expect(File(p.join(workspaceDir.path, 'x.cache')).existsSync(), isTrue);
        expect(
          File(p.join(workspaceDir.path, 'new.txt')).existsSync(),
          isFalse,
        );
      },
    );

    test('concurrent captures for one run are serialized', () async {
      await createRun(id: 'run-lock', wsPath: workspaceDir.path);
      await File(p.join(workspaceDir.path, 'a.txt')).writeAsString('a\n');
      final results = await Future.wait([
        for (var i = 0; i < 4; i++)
          snapshotService.captureSnapshot(
            runId: 'run-lock',
            targetFolder: workspaceDir.path,
          ),
      ]);
      expect(results, everyElement(isA<Success<Snapshot>>()));
    });
  });

  group('WorkspacePreparationService & RunService.deleteRun cleanup', () {
    test(
      'keeps a run worktree and its branch on deleteRun, leaving uncommitted '
      'work untouched',
      () async {
        await runGit(['init', workspaceDir.path]);
        await runGit(['-C', workspaceDir.path, 'config', 'user.name', 'User']);
        await runGit([
          '-C',
          workspaceDir.path,
          'config',
          'user.email',
          'user@example.com',
        ]);
        await File(p.join(workspaceDir.path, 'base.txt'))
            .writeAsString('committed\n');
        await runGit(['-C', workspaceDir.path, 'add', 'base.txt']);
        await runGit(['-C', workspaceDir.path, 'commit', '-m', 'base']);

        // Uncommitted user work in original workspace.
        await File(p.join(workspaceDir.path, 'dirty.txt'))
            .writeAsString('uncommitted\n');

        final worktreePath = p.join(tempRoot.path, 'wt-run-wt');
        await runGit([
          '-C',
          workspaceDir.path,
          'worktree',
          'add',
          '-b',
          'hive/run-wt',
          worktreePath,
          'HEAD',
        ]);
        final prepared = PreparedWorkspace(
          targetFolder: worktreePath,
          isolationMode: WorkspaceIsolationMode.worktree,
          worktreePath: worktreePath,
          worktreeBranch: 'hive/run-wt',
        );

        expect(prepared.isolationMode, WorkspaceIsolationMode.worktree);
        expect(prepared.worktreeBranch, 'hive/run-wt');
        expect(prepared.worktreePath, isNotNull);
        expect(Directory(prepared.worktreePath!).existsSync(), isTrue);
        // Uncommitted file is not in the worktree, and stays in user workspace.
        expect(
          File(p.join(prepared.worktreePath!, 'dirty.txt')).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(workspaceDir.path, 'dirty.txt')).existsSync(),
          isTrue,
        );

        await createRun(
          id: 'run-wt',
          wsPath: workspaceDir.path,
          status: RunStatus.succeeded,
          isolationMode: prepared.isolationMode,
          worktreePath: prepared.worktreePath,
          worktreeBranch: prepared.worktreeBranch,
        );

        // Capture a snapshot in the worktree.
        await snapshotService.captureSnapshot(
          runId: 'run-wt',
          targetFolder: prepared.targetFolder,
        );
        expect(
          Directory(snapshotService.shadowRepoPath('run-wt')).existsSync(),
          isTrue,
        );

        // Delete run: the shadow repo goes, the worktree stays (ADR 0025).
        final delRes = await runService.deleteRun('run-wt');
        expect(delRes, isA<Success<void>>());
        expect(
          Directory(snapshotService.shadowRepoPath('run-wt')).existsSync(),
          isFalse,
        );
        expect(Directory(prepared.worktreePath!).existsSync(), isTrue);
        final branches = (await git.runChecked([
          '-C',
          workspaceDir.path,
          'branch',
          '--list',
          'hive/run-wt',
        ]) as Success<String>).value;
        expect(branches.trim(), isNotEmpty);
      },
    );
  });
}
