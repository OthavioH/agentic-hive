import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Test double for [WorkspaceRepository] with controllable responses.
final class FakeWorkspaceRepository implements WorkspaceRepository {
  new({
    List<Snapshot>? snapshots,
    this.capabilities = const Success<WorkspaceCapabilities>(
      WorkspaceCapabilities(
        gitAvailable: true,
        isGitRepo: true,
        hasCommits: true,
        gitVersion: '2.50.0',
      ),
    ),
  }) : snapshots = snapshots ?? <Snapshot>[];

  List<Snapshot> snapshots;
  Result<WorkspaceCapabilities> capabilities;
  Result<SnapshotDiff>? diffResult;
  Result<RestoreSnapshotResponse>? restoreResult;

  /// When set, `listSnapshots` waits for it, keeping the panel loading.
  Completer<void>? listGate;
  Failure? listFailure;

  final List<String> restoreCalls = <String>[];
  final List<String> diffCalls = <String>[];
  final List<String?> capabilityPaths = <String?>[];

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
