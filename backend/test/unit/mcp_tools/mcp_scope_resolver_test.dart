import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _FakeWorkspaces implements WorkspaceRepository {
  new({List<Workspace>? items, this.listFailure})
    : _items = items ?? <Workspace>[];

  final List<Workspace> _items;
  final Failure? listFailure;

  @override
  Future<Result<List<Workspace>>> list() async =>
      listFailure != null ? FailureResult(listFailure!) : Success(_items);

  @override
  Future<Result<Workspace>> getById(String id) async =>
      throw UnimplementedError();

  @override
  Future<Result<Workspace>> create(Workspace workspace) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> delete(String id) async => throw UnimplementedError();

  @override
  Future<Result<Workspace>> rename(
    String id, {
    required String name,
    required DateTime updatedAt,
  }) async => throw UnimplementedError();
}

Workspace _ws(String id, String name, String rootPath) => Workspace(
  id: id,
  name: name,
  rootPath: rootPath,
  isGit: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late Directory tempDir;
  late Directory wsDir;
  late Directory nestedDir;
  late Directory otherDir;
  late Directory worktreesDir;
  late McpScopeResolver resolver;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hive_scope_test_');
    wsDir = Directory(p.join(tempDir.path, 'ws-a'))..createSync();
    nestedDir = Directory(p.join(wsDir.path, 'sub', 'nested'))
      ..createSync(recursive: true);
    otherDir = Directory(p.join(tempDir.path, 'outside'))..createSync();
    worktreesDir = Directory(p.join(tempDir.path, 'worktrees'))..createSync();

    resolver = McpScopeResolver(
      workspaces: _FakeWorkspaces(
        items: [
          _ws('ws-a', 'Workspace A', wsDir.path),
          _ws('ws-nested', 'Nested', nestedDir.path),
        ],
      ),
      worktreesDir: worktreesDir.path,
      path: p.context,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('explicit global token is case-insensitive', () async {
    final result = await resolver.resolve(workspace: 'GlObAl', cwd: wsDir.path);
    final scope = (result as Success<McpScope>).value;
    expect(scope, isA<GlobalMcpScope>());
    expect(scope.workspaceId, isNull);
    expect(scope.source, McpScopeSource.argument);
  });

  test('explicit workspace id', () async {
    final result = await resolver.resolve(
      workspace: 'ws-a',
      cwd: otherDir.path,
    );
    final scope = (result as Success<McpScope>).value;
    expect(scope, isA<WorkspaceMcpScope>());
    expect(scope.workspaceId, 'ws-a');
    expect(scope.source, McpScopeSource.argument);
  });

  test('explicit root path, non-normalized', () async {
    final nonNormalized = p.join(wsDir.path, '.');
    final result = await resolver.resolve(
      workspace: nonNormalized,
      cwd: otherDir.path,
    );
    final scope = (result as Success<McpScope>).value;
    expect(scope, isA<WorkspaceMcpScope>());
    expect(scope.workspaceId, 'ws-a');
    expect(scope.source, McpScopeSource.argument);
  });

  test('explicit path inside a root is unknown', () async {
    final inside = Directory(p.join(wsDir.path, 'sub'))..createSync();
    final result = await resolver.resolve(workspace: inside.path);
    expect(result, isA<FailureResult<McpScope>>());
    final failure = (result as FailureResult<McpScope>).failure;
    expect(failure, isA<NotFoundFailure>());
    expect(
      failure.message,
      'Unknown workspace "${inside.path}": pass the workspace root path or id '
      '(see list_workspaces).',
    );
  });

  test('unknown id gives the next-step message', () async {
    final result = await resolver.resolve(workspace: 'nope');
    expect(result, isA<FailureResult<McpScope>>());
    final failure = (result as FailureResult<McpScope>).failure;
    expect(failure, isA<NotFoundFailure>());
    expect(
      failure.message,
      'Unknown workspace "nope": pass the workspace root path or id '
      '(see list_workspaces).',
    );
  });

  test('unknown absolute path gives the same message', () async {
    final result = await resolver.resolve(workspace: otherDir.path);
    expect(result, isA<FailureResult<McpScope>>());
    final failure = (result as FailureResult<McpScope>).failure;
    expect(failure, isA<NotFoundFailure>());
    expect(
      failure.message,
      'Unknown workspace "${otherDir.path}": '
      'pass the workspace root path or id '
      '(see list_workspaces).',
    );
  });

  test('blank workspace is treated as omitted', () async {
    final result = await resolver.resolve(workspace: '   ', cwd: wsDir.path);
    final scope = (result as Success<McpScope>).value;
    expect(scope.workspaceId, 'ws-a');
    expect(scope.source, McpScopeSource.currentDirectory);
  });

  test('cwd equal to a root', () async {
    final result = await resolver.resolve(cwd: wsDir.path);
    final scope = (result as Success<McpScope>).value;
    expect(scope.workspaceId, 'ws-a');
    expect(scope.source, McpScopeSource.currentDirectory);
  });

  test('cwd inside a root', () async {
    final sub = Directory(p.join(wsDir.path, 'only-in-a'))..createSync();
    final result = await resolver.resolve(cwd: sub.path);
    final scope = (result as Success<McpScope>).value;
    expect(scope.workspaceId, 'ws-a');
    expect(scope.source, McpScopeSource.currentDirectory);
  });

  test('nested workspaces pick the deepest root', () async {
    final deepSub = Directory(p.join(nestedDir.path, 'deep'))..createSync();
    final result = await resolver.resolve(cwd: deepSub.path);
    final scope = (result as Success<McpScope>).value;
    expect(scope.workspaceId, 'ws-nested');
    expect(scope.source, McpScopeSource.currentDirectory);
  });

  test('cwd inside a worktree of a workspace', () async {
    final wtSub = Directory(p.join(worktreesDir.path, 'ws-a', 'wt', 'sub'))
      ..createSync(recursive: true);
    final result = await resolver.resolve(cwd: wtSub.path);
    final scope = (result as Success<McpScope>).value;
    expect(scope.workspaceId, 'ws-a');
    expect(scope.source, McpScopeSource.worktree);
  });

  test(
    'cwd in worktrees of an unknown workspace falls back to Global',
    () async {
      final wtUnknown = Directory(p.join(worktreesDir.path, 'unknown-ws', 'wt'))
        ..createSync(recursive: true);
      final result = await resolver.resolve(cwd: wtUnknown.path);
      final scope = (result as Success<McpScope>).value;
      expect(scope, isA<GlobalMcpScope>());
      expect(scope.source, McpScopeSource.fallback);
    },
  );

  test('cwd outside every workspace falls back to Global', () async {
    final result = await resolver.resolve(cwd: otherDir.path);
    final scope = (result as Success<McpScope>).value;
    expect(scope, isA<GlobalMcpScope>());
    expect(scope.source, McpScopeSource.fallback);
  });

  test('no cwd falls back to Global', () async {
    final result = await resolver.resolve();
    final scope = (result as Success<McpScope>).value;
    expect(scope, isA<GlobalMcpScope>());
    expect(scope.source, McpScopeSource.fallback);
  });

  test('repository failure is returned', () async {
    final failing = McpScopeResolver(
      workspaces: _FakeWorkspaces(
        listFailure: const UnexpectedFailure('db down'),
      ),
      worktreesDir: worktreesDir.path,
      path: p.context,
    );
    final result = await failing.resolve(workspace: 'ws-a');
    expect(result, isA<FailureResult<McpScope>>());
    expect((result as FailureResult<McpScope>).failure.message, 'db down');
  });
}
