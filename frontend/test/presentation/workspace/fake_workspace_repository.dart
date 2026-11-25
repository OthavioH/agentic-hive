import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Test double for [WorkspaceRepository] with controllable responses.
final class FakeWorkspaceRepository implements WorkspaceRepository {
  new({
    List<Workspace>? workspaces,
    List<Snapshot>? snapshots,
    this.capabilities = const Success<WorkspaceCapabilities>(
      WorkspaceCapabilities(
        gitAvailable: true,
        isGitRepo: true,
        hasCommits: true,
        gitVersion: '2.50.0',
      ),
    ),
  }) : workspaces = workspaces ?? <Workspace>[],
       snapshots = snapshots ?? <Snapshot>[];

  List<Workspace> workspaces;
  Map<String, List<Worktree>> worktreesByWorkspaceId =
      <String, List<Worktree>>{};
  Failure? listWorkspacesFailure;
  Failure? listWorktreesFailure;
  Result<Workspace>? createWorkspaceResult;
  Result<Workspace>? renameWorkspaceResult;
  Result<void>? unregisterWorkspaceResult;
  Result<RemoveWorktreeResponse>? removeWorktreeResult;
  Result<RemoveWorktreeResponse> Function(
    String workspaceId,
    String worktreeId, {
    required bool force,
  })?
  onRemoveWorktree;

  List<Snapshot> snapshots;
  Result<WorkspaceCapabilities> capabilities;
  Result<SnapshotDiff>? diffResult;
  Result<RestoreSnapshotResponse>? restoreResult;

  /// When set, `listSnapshots` waits for it, keeping the panel loading.
  Completer<void>? listGate;

  /// When set, `listWorkspaces` waits for it, keeping the tree loading.
  Completer<void>? listWorkspacesGate;
  Failure? listFailure;

  final List<String> restoreCalls = <String>[];
  final List<String> diffCalls = <String>[];
  final List<String?> capabilityPaths = <String?>[];
  final List<({String rootPath, String? name})> createCalls =
      <({String rootPath, String? name})>[];
  final List<({String id, String name})> renameCalls =
      <({String id, String name})>[];
  final List<String> unregisterCalls = <String>[];
  final List<({String workspaceId, String worktreeId, bool force})>
  removeWorktreeCalls =
      <({String workspaceId, String worktreeId, bool force})>[];

  @override
  Future<Result<List<Workspace>>> listWorkspaces() async {
    await listWorkspacesGate?.future;
    final failure = listWorkspacesFailure;
    if (failure != null) return FailureResult<List<Workspace>>(failure);
    return Success<List<Workspace>>(List<Workspace>.of(workspaces));
  }

  @override
  Future<Result<Workspace>> createWorkspace({
    required String rootPath,
    String? name,
  }) async {
    createCalls.add((rootPath: rootPath, name: name));
    final override = createWorkspaceResult;
    if (override != null) {
      if (override case Success<Workspace>(:final value)) {
        workspaces = <Workspace>[...workspaces, value];
      }
      return override;
    }
    final resolvedName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : rootPath.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;
    final created = makeWorkspace(
      id: 'ws-${workspaces.length + 1}',
      name: resolvedName,
      rootPath: rootPath,
    );
    workspaces = <Workspace>[...workspaces, created];
    return Success<Workspace>(created);
  }

  @override
  Future<Result<Workspace>> renameWorkspace(
    String id, {
    required String name,
  }) async {
    renameCalls.add((id: id, name: name));
    final override = renameWorkspaceResult;
    if (override != null) {
      if (override case Success<Workspace>(:final value)) {
        workspaces = <Workspace>[
          for (final w in workspaces)
            if (w.id == id) value else w,
        ];
      }
      return override;
    }
    final idx = workspaces.indexWhere((w) => w.id == id);
    if (idx < 0) {
      return const FailureResult<Workspace>(NotFoundFailure('Not found'));
    }
    final updated = workspaces[idx].copyWith(name: name);
    workspaces = <Workspace>[
      for (final w in workspaces)
        if (w.id == id) updated else w,
    ];
    return Success<Workspace>(updated);
  }

  @override
  Future<Result<void>> unregisterWorkspace(String id) async {
    unregisterCalls.add(id);
    final override = unregisterWorkspaceResult;
    if (override != null) {
      if (override.isSuccess) {
        workspaces = workspaces.where((w) => w.id != id).toList();
      }
      return override;
    }
    workspaces = workspaces.where((w) => w.id != id).toList();
    return const Success<void>(null);
  }

  @override
  Future<Result<List<Worktree>>> listWorktrees(String workspaceId) async {
    final failure = listWorktreesFailure;
    if (failure != null) return FailureResult<List<Worktree>>(failure);
    return Success<List<Worktree>>(
      List<Worktree>.of(
        worktreesByWorkspaceId[workspaceId] ?? const <Worktree>[],
      ),
    );
  }

  @override
  Future<Result<RemoveWorktreeResponse>> removeWorktree(
    String workspaceId,
    String worktreeId, {
    bool force = false,
  }) async {
    removeWorktreeCalls.add((
      workspaceId: workspaceId,
      worktreeId: worktreeId,
      force: force,
    ));
    final handler = onRemoveWorktree;
    if (handler != null) {
      final result = handler(workspaceId, worktreeId, force: force);
      if (result.isSuccess) {
        worktreesByWorkspaceId[workspaceId] =
            (worktreesByWorkspaceId[workspaceId] ?? const <Worktree>[])
                .where((w) => w.id != worktreeId)
                .toList();
      }
      return result;
    }
    final override = removeWorktreeResult;
    if (override != null) {
      if (override.isSuccess) {
        worktreesByWorkspaceId[workspaceId] =
            (worktreesByWorkspaceId[workspaceId] ?? const <Worktree>[])
                .where((w) => w.id != worktreeId)
                .toList();
      }
      return override;
    }
    worktreesByWorkspaceId[workspaceId] =
        (worktreesByWorkspaceId[workspaceId] ?? const <Worktree>[])
            .where((w) => w.id != worktreeId)
            .toList();
    return Success<RemoveWorktreeResponse>(
      RemoveWorktreeResponse(
        id: worktreeId,
        deleted: true,
        branchDeleted: true,
      ),
    );
  }

  @override
  Future<Result<WorkspaceCapabilities>> getCapabilities({String? path}) async {
    capabilityPaths.add(path);
    return capabilities;
  }

  @override
  Future<Result<List<Snapshot>>> listSnapshots(String runId) async {
    await listGate?.future;
    final failure = listFailure;
    if (failure != null) return FailureResult<List<Snapshot>>(failure);
    return Success<List<Snapshot>>(List<Snapshot>.of(snapshots));
  }

  @override
  Future<Result<SnapshotDiff>> getSnapshotDiff(
    String runId,
    String snapshotId,
  ) async {
    diffCalls.add(snapshotId);
    return diffResult ??
        Success<SnapshotDiff>(
          SnapshotDiff(
            snapshotId: snapshotId,
            files: const <SnapshotFileChange>[
              SnapshotFileChange(
                path: 'lib/a.dart',
                changeType: SnapshotChangeType.added,
              ),
              SnapshotFileChange(
                path: 'README.md',
                changeType: SnapshotChangeType.modified,
              ),
              SnapshotFileChange(
                path: 'old.txt',
                changeType: SnapshotChangeType.deleted,
              ),
            ],
          ),
        );
  }

  @override
  Future<Result<RestoreSnapshotResponse>> restoreSnapshot(
    String runId,
    String snapshotId,
  ) async {
    restoreCalls.add(snapshotId);
    return restoreResult ??
        Success<RestoreSnapshotResponse>(
          RestoreSnapshotResponse(
            restoredSnapshotId: snapshotId,
            safetySnapshot: makeSnapshot(
              id: 'snap-safety',
              kind: SnapshotKind.safetyPreRestore,
            ),
          ),
        );
  }
}

/// Builds a [Workspace] for tests.
Workspace makeWorkspace({
  String id = 'ws-1',
  String name = 'Workspace One',
  String rootPath = '/tmp/ws-1',
  bool isGit = true,
  int activeRunCount = 0,
}) => Workspace(
  id: id,
  name: name,
  rootPath: rootPath,
  isGit: isGit,
  createdAt: DateTime.utc(2026, 11, 22, 10),
  updatedAt: DateTime.utc(2026, 11, 22, 10),
  activeRunCount: activeRunCount,
);

/// Builds a [Worktree] for tests.
Worktree makeWorktree({
  String id = 'primary',
  String name = 'primary',
  String path = '/tmp/ws-1',
  bool isPrimary = true,
  bool hasUncommittedChanges = false,
  String? branch = 'main',
}) => Worktree(
  id: id,
  name: name,
  path: path,
  isPrimary: isPrimary,
  hasUncommittedChanges: hasUncommittedChanges,
  branch: branch,
);

/// Builds a [Snapshot] for tests.
Snapshot makeSnapshot({
  String id = 'snap-1',
  String runId = 'run-1',
  String? nodeId = 'node-build',
  SnapshotKind kind = SnapshotKind.preNode,
  int added = 2,
  int modified = 3,
  int deleted = 1,
}) => Snapshot(
  id: id,
  runId: runId,
  nodeId: nodeId,
  commitHash: 'abc$id',
  kind: kind,
  addedCount: added,
  modifiedCount: modified,
  deletedCount: deleted,
  createdAt: DateTime.utc(2026, 11, 21, 4, 30),
);
