import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/create_workspace.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/list_workspaces.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/list_worktrees.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/rename_workspace.dart';
import 'package:agentic_hive_frontend/domain/workspace/use_cases/unregister_workspace.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWorkspaceRepository implements WorkspaceRepository {
  List<Workspace> workspaces = <Workspace>[];
  String? lastRootPath;
  String? lastName;
  String? lastId;

  @override
  Future<Result<List<Workspace>>> listWorkspaces() async => Success(workspaces);

  @override
  Future<Result<Workspace>> createWorkspace({
    required String rootPath,
    String? name,
  }) async {
    lastRootPath = rootPath;
    lastName = name;
    final ws = Workspace(
      id: 'ws-new',
      name: name ?? 'repo',
      rootPath: rootPath,
      isGit: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    return Success(ws);
  }

  @override
  Future<Result<Workspace>> renameWorkspace(
    String id, {
    required String name,
  }) async {
    lastId = id;
    lastName = name;
    return Success(
      Workspace(
        id: id,
        name: name,
        rootPath: '/tmp/repo',
        isGit: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
  }

  @override
  Future<Result<void>> unregisterWorkspace(String id) async {
    lastId = id;
    return const Success(null);
  }

  @override
  Future<Result<List<Worktree>>> listWorktrees(String workspaceId) async {
    lastId = workspaceId;
    return const Success(<Worktree>[]);
  }

  @override
  Future<Result<RemoveWorktreeResponse>> removeWorktree(
    String workspaceId,
    String worktreeId, {
    bool force = false,
  }) async {
    lastId = worktreeId;
    return Success(
      RemoveWorktreeResponse(
        id: worktreeId,
        deleted: true,
        branchDeleted: true,
      ),
    );
  }

  @override
  Future<Result<WorkspaceCapabilities>> getCapabilities({String? path}) =>
      throw UnimplementedError();

  @override
  Future<Result<SnapshotDiff>> getSnapshotDiff(
    String runId,
    String snapshotId,
  ) => throw UnimplementedError();

  @override
  Future<Result<List<Snapshot>>> listSnapshots(String runId) =>
      throw UnimplementedError();

  @override
  Future<Result<RestoreSnapshotResponse>> restoreSnapshot(
    String runId,
    String snapshotId,
  ) => throw UnimplementedError();
}

void main() {
  test(
    'workspace registry use cases delegate to WorkspaceRepository',
    () async {
      final repo = _FakeWorkspaceRepository();
      final ws = Workspace(
        id: 'ws-1',
        name: 'One',
        rootPath: '/tmp/one',
        isGit: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      repo.workspaces = <Workspace>[ws];

      final listed = await ListWorkspaces(repo)();
      expect(listed.valueOrNull, <Workspace>[ws]);

      final created = await CreateWorkspace(repo)(
        rootPath: '/tmp/two',
        name: 'Two',
      );
      expect(repo.lastRootPath, '/tmp/two');
      expect(repo.lastName, 'Two');
      expect(created.valueOrNull?.name, 'Two');

      final renamed = await RenameWorkspace(repo)('ws-1', name: 'One Renamed');
      expect(repo.lastId, 'ws-1');
      expect(renamed.valueOrNull?.name, 'One Renamed');

      final removed = await UnregisterWorkspace(repo)('ws-1');
      expect(removed.isSuccess, isTrue);

      final worktrees = await ListWorktrees(repo)('ws-1');
      expect(repo.lastId, 'ws-1');
      expect(worktrees.valueOrNull, isEmpty);
    },
  );
}
