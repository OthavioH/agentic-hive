import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/active_run_lookup.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/worktree_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _FakeLookup implements ActiveRunLookup {
  Set<String> folders = {};

  @override
  Future<Result<Set<String>>> activeTargetFolders(String workspaceId) async =>
      Success(folders);
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
}
