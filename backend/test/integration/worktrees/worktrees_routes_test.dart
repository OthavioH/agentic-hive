@Timeout(Duration(seconds: 90))
library;

import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';

Future<void> git(String dir, List<String> args) async {
  final result = await Process.run('git', [
    '-c',
    'user.name=Test',
    '-c',
    'user.email=test@example.com',
    ...args,
  ], workingDirectory: dir);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

void main() {
  late Directory repo;
  late Backend backend;
  late SocketHttpClient http;
  late Workspace workspace;
  late String dataDir;

  Future<Workspace> register(Directory dir) async {
    final response = await http.post(
      '/api/v1/workspaces',
      body: jsonEncode(CreateWorkspaceRequest(rootPath: dir.path).toJson()),
    );
    expect(response.statusCode, 201);
    return Workspace.fromJson(response.json);
  }

  Future<SocketResponse> create(
    String name, {
    String? branch,
    String? baseBranch,
  }) => http.post(
    '/api/v1/workspaces/${workspace.id}/worktrees',
    body: jsonEncode(
      CreateWorktreeRequest(
        name: name,
        branch: branch,
        baseBranch: baseBranch,
      ).toJson(),
    ),
  );

  Future<List<Worktree>> list() async {
    final response = await http.get(
      '/api/v1/workspaces/${workspace.id}/worktrees',
    );
    expect(response.statusCode, 200);
    return WorktreeListResponse.fromJson(response.json).items;
  }

  setUp(() async {
    dataDir = (await createTempDir()).path;
    repo = await createTempDir();
    await git(repo.path, ['init', '-b', 'main']);
    File(p.join(repo.path, 'a.txt')).writeAsStringSync('a');
    await git(repo.path, ['add', '.']);
    await git(repo.path, ['commit', '-m', 'init']);
    backend = await startBackend(dataDir);
    http = SocketHttpClient(backend.socketPath);
    workspace = await register(repo);
  });

  tearDown(() => http.close());

  test('lists the primary checkout with its branch first', () async {
    final items = await list();

    expect(items, hasLength(1));
    expect(items.single.isPrimary, isTrue);
    expect(items.single.id, primaryWorktreeId);
    expect(items.single.branch, 'main');
    expect(items.single.hasUncommittedChanges, isFalse);
  });

  test('creates a worktree on a new branch under the app data folder, from '
      'the primary current branch by default', () async {
    final response = await create('feat-a', branch: 'feature/a');

    expect(response.statusCode, 201);
    final created = Worktree.fromJson(response.json);
    expect(created.name, 'feat-a');
    expect(created.branch, 'feature/a');
    expect(created.isPrimary, isFalse);
    expect(
      p.canonicalize(created.path),
      p.canonicalize(p.join(dataDir, 'worktrees', workspace.id, 'feat-a')),
    );
    expect(File(p.join(created.path, 'a.txt')).existsSync(), isTrue);

    final items = await list();
    expect(items.map((w) => w.id), [primaryWorktreeId, 'feat-a']);
  });

  test('the branch defaults to the worktree name and a base branch can be '
      'chosen', () async {
    await git(repo.path, ['branch', 'develop']);

    final response = await create('x', baseBranch: 'develop');

    expect(response.statusCode, 201);
    expect(Worktree.fromJson(response.json).branch, 'x');
  });

  test('flags uncommitted changes in a worktree', () async {
    final created = Worktree.fromJson((await create('dirty')).json);
    File(p.join(created.path, 'new.txt')).writeAsStringSync('x');

    final items = await list();

    expect(
      items.firstWhere((w) => w.id == 'dirty').hasUncommittedChanges,
      isTrue,
    );
    expect(items.firstWhere((w) => w.isPrimary).hasUncommittedChanges, isFalse);
  });

  test('rejects bad names, duplicate names, existing branches and unknown '
      'base branches', () async {
    expect((await create('../evil')).statusCode, 400);
    expect((await create(primaryWorktreeId)).statusCode, 400);
    expect((await create('ok', baseBranch: 'nope')).statusCode, 400);
    expect((await create('main')).statusCode, 409);
    expect((await create('one')).statusCode, 201);
    expect((await create('one', branch: 'other')).statusCode, 409);
  });

  test('removes a worktree and deletes its merged branch', () async {
    final created = Worktree.fromJson((await create('gone')).json);

    final response = await http.delete(
      '/api/v1/workspaces/${workspace.id}/worktrees/gone',
    );

    expect(response.statusCode, 200);
    final body = RemoveWorktreeResponse.fromJson(response.json);
    expect(body.deleted, isTrue);
    expect(body.branchDeleted, isTrue);
    expect(Directory(created.path).existsSync(), isFalse);
    expect((await list()).map((w) => w.id), ['primary']);
    expect(Directory(repo.path).existsSync(), isTrue);
  });

  test('keeps an unmerged branch and says so', () async {
    final created = Worktree.fromJson((await create('wip')).json);
    File(p.join(created.path, 'b.txt')).writeAsStringSync('b');
    await git(created.path, ['add', '.']);
    await git(created.path, ['commit', '-m', 'work']);

    final response = await http.delete(
      '/api/v1/workspaces/${workspace.id}/worktrees/wip',
    );

    expect(response.statusCode, 200);
    final body = RemoveWorktreeResponse.fromJson(response.json);
    expect(body.deleted, isTrue);
    expect(body.branchDeleted, isFalse);
    expect(body.notice, contains('wip'));
  });

  test('refuses to remove a dirty worktree unless forced', () async {
    final created = Worktree.fromJson((await create('dirty2')).json);
    File(p.join(created.path, 'new.txt')).writeAsStringSync('x');

    final refused = await http.delete(
      '/api/v1/workspaces/${workspace.id}/worktrees/dirty2',
    );
    expect(refused.statusCode, 409);
    expect(Directory(created.path).existsSync(), isTrue);

    final forced = await http.delete(
      '/api/v1/workspaces/${workspace.id}/worktrees/dirty2?force=true',
    );
    expect(forced.statusCode, 200);
    expect(Directory(created.path).existsSync(), isFalse);
  });

  test('cannot remove the primary checkout or an unknown worktree', () async {
    final base = '/api/v1/workspaces/${workspace.id}/worktrees';

    expect((await http.delete('$base/primary')).statusCode, 400);
    expect((await http.delete('$base/missing')).statusCode, 404);
    expect(Directory(repo.path).existsSync(), isTrue);
  });

  test(
    'does not list or remove worktrees outside the app data folder',
    () async {
      final outside = Directory(
        p.join((await createTempDir()).path, 'outside'),
      );
      await git(repo.path, ['worktree', 'add', '-b', 'ext', outside.path]);

      expect((await list()).map((w) => w.id), ['primary']);
      final response = await http.delete(
        '/api/v1/workspaces/${workspace.id}/worktrees/outside',
      );
      expect(response.statusCode, 404);
      expect(outside.existsSync(), isTrue);
    },
  );

  test(
    'lists worktrees left on disk by old runs under their workspace',
    () async {
      final old = p.join(dataDir, 'worktrees', 'old-run-id');
      await git(repo.path, ['worktree', 'add', '-b', 'hive/old-run-id', old]);

      final items = await list();

      expect(items.map((w) => w.id), ['primary', 'old-run-id']);
      expect(items.last.branch, 'hive/old-run-id');
    },
  );

  test('non-git workspaces expose no worktrees', () async {
    final plain = await createTempDir();
    final plainWorkspace = await register(plain);

    final listed = await http.get(
      '/api/v1/workspaces/${plainWorkspace.id}/worktrees',
    );
    expect(listed.statusCode, 200);
    expect(WorktreeListResponse.fromJson(listed.json).items, isEmpty);

    final created = await http.post(
      '/api/v1/workspaces/${plainWorkspace.id}/worktrees',
      body: jsonEncode(const CreateWorktreeRequest(name: 'x').toJson()),
    );
    expect(created.statusCode, 400);
  });

  test('unknown workspace is 404', () async {
    final response = await http.get('/api/v1/workspaces/nope/worktrees');
    expect(response.statusCode, 404);
  });

  test('returns 409 without git output when a worktree folder remains after '
      'git remove fails', () async {
    final created = Worktree.fromJson((await create('pinned')).json);
    await git(repo.path, ['worktree', 'lock', created.path]);
    addTearDown(() async {
      await Process.run('git', [
        '-C',
        repo.path,
        'worktree',
        'unlock',
        created.path,
      ]);
    });

    for (final path in [
      '/api/v1/workspaces/${workspace.id}/worktrees/pinned',
      '/api/v1/workspaces/${workspace.id}/worktrees/pinned?force=true',
    ]) {
      final response = await http.delete(path);
      expect(response.statusCode, 409);
      final error = response.json['error']! as Map<String, Object?>;
      expect(error['code'], 'conflict');
      final message = error['message']! as String;
      expect(message, contains('in use or could not be deleted'));
      expect(message, isNot(contains('locked')));
      expect(message, isNot(contains('fatal')));
      expect(message, isNot(contains('cannot')));
      expect(Directory(created.path).existsSync(), isTrue);
    }
  });

  test('returns 200 and prunes when the worktree folder was already deleted '
      'on disk', () async {
    final created = Worktree.fromJson((await create('vanish')).json);
    await Directory(created.path).delete(recursive: true);

    final response = await http.delete(
      '/api/v1/workspaces/${workspace.id}/worktrees/vanish',
    );

    expect(response.statusCode, 200);
    final body = RemoveWorktreeResponse.fromJson(response.json);
    expect(body.deleted, isTrue);
    expect(body.branchDeleted, isTrue);

    final listed = await Process.run('git', [
      '-C',
      repo.path,
      'worktree',
      'list',
      '--porcelain',
    ]);
    expect(listed.stdout as String, isNot(contains('vanish')));
  });
}
