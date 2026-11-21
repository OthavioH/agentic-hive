import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/snapshot_repository.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Manages per-run shadow git repositories, snapshot capture, diffs, and
/// workspace rollback ("step back").
final class ShadowSnapshotService {
  /// Creates a shadow snapshot service.
  const new({
    required this._git,
    required this._runs,
    required this._snapshots,
    required this._events,
    required this._snapshotsDir,
    required this._pathContext,
  });

  /// Default per-file size limit (50 MB).
  static const int defaultMaxFileSizeBytes = 50 * 1024 * 1024;

  final GitClient _git;
  final RunRepository _runs;
  final SnapshotRepository _snapshots;
  final RunEventRepository _events;
  final String _snapshotsDir;
  final p.Context _pathContext;

  /// Absolute path to the shadow git repository for [runId].
  String shadowRepoPath(String runId) =>
      _pathContext.join(_snapshotsDir, runId);

  /// Captures a workspace snapshot for [runId] in [workspaceDir].
  Future<Result<Snapshot>> captureSnapshot({
    required String runId,
    required String workspaceDir,
    String? nodeId,
    SnapshotKind kind = SnapshotKind.preNode,
    List<String> extraExclusions = const [],
    int? maxFileSizeBytes = defaultMaxFileSizeBytes,
  }) async {
    if (!Directory(workspaceDir).existsSync()) {
      return FailureResult(
        ValidationFailure(
          'Workspace directory "$workspaceDir" does not exist.',
        ),
      );
    }

    final shadowDir = shadowRepoPath(runId);
    final initResult = await _ensureShadowRepoInitialized(shadowDir);
    if (initResult case FailureResult<void>(:final failure)) {
      return FailureResult(failure);
    }

    final excludeFile = File(_pathContext.join(shadowDir, 'info', 'exclude'));
    final baseExclusions = await _buildExclusions(
      workspaceDir: workspaceDir,
      extraExclusions: extraExclusions,
    );
    await excludeFile.parent.create(recursive: true);
    await excludeFile.writeAsString(baseExclusions);

    // Check per-file size limit against non-excluded untracked/modified files.
    if (maxFileSizeBytes != null && maxFileSizeBytes > 0) {
      final oversized = await _findOversizedFiles(
        shadowDir: shadowDir,
        workspaceDir: workspaceDir,
        maxFileSizeBytes: maxFileSizeBytes,
      );
      if (oversized.isNotEmpty) {
        final extraBuffer = StringBuffer(baseExclusions);
        for (final entry in oversized) {
          extraBuffer.writeln('/${entry.path}');
          await _events.append(
            id: randomId(),
            runId: runId,
            nodeId: nodeId,
            type: RunEventType.snapshotWarning,
            payload: {
              'reason': 'file_size_limit',
              'path': entry.path,
              'sizeBytes': entry.sizeBytes,
              'limitBytes': maxFileSizeBytes,
            },
            createdAt: DateTime.now().toUtc(),
          );
        }
        await excludeFile.writeAsString(extraBuffer.toString());
      }
    }

    final addResult = await _git.runChecked([
      '--git-dir=$shadowDir',
      '--work-tree=$workspaceDir',
      'add',
      '-A',
    ], failureContext: 'Staging workspace files for snapshot');
    if (addResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    final headCheck = await _git.run([
      '--git-dir=$shadowDir',
      'rev-parse',
      '--verify',
      'HEAD',
    ]);
    final hasPrevCommit =
        headCheck.launchError == null &&
        !headCheck.timedOut &&
        headCheck.exitCode == 0 &&
        headCheck.stdout.trim().isNotEmpty;

    late final String commitHash;
    var addedCount = 0;
    var modifiedCount = 0;
    var deletedCount = 0;

    if (hasPrevCommit) {
      final prevHash = headCheck.stdout.trim();
      final diffQuiet = await _git.run([
        '--git-dir=$shadowDir',
        '--work-tree=$workspaceDir',
        'diff',
        '--cached',
        '--quiet',
      ]);
      if (diffQuiet.exitCode == 0) {
        // No changes relative to previous commit: reuse commitHash.
        commitHash = prevHash;
      } else {
        final diffStatus = await _git.runChecked([
          '--git-dir=$shadowDir',
          '--work-tree=$workspaceDir',
          '-c',
          'core.quotePath=false',
          'diff',
          '--cached',
          '--name-status',
          '-z',
        ], failureContext: 'Inspecting staged snapshot diff');
        if (diffStatus case FailureResult<String>(:final failure)) {
          return FailureResult(failure);
        }
        final changes = _parseNameStatusZ(
          (diffStatus as Success<String>).value,
        );
        for (final change in changes) {
          switch (change.changeType) {
            case SnapshotChangeType.added:
              addedCount++;
            case SnapshotChangeType.modified:
              modifiedCount++;
            case SnapshotChangeType.deleted:
              deletedCount++;
          }
        }

        final commitResult = await _git.runChecked([
          '--git-dir=$shadowDir',
          'commit',
          '-m',
          'snapshot: ${kind.wireName}',
        ], failureContext: 'Committing workspace snapshot');
        if (commitResult case FailureResult<String>(:final failure)) {
          return FailureResult(failure);
        }

        final newHead = await _git.runChecked([
          '--git-dir=$shadowDir',
          'rev-parse',
          'HEAD',
        ], failureContext: 'Reading snapshot commit hash');
        if (newHead case FailureResult<String>(:final failure)) {
          return FailureResult(failure);
        }
        commitHash = (newHead as Success<String>).value.trim();
      }
    } else {
      final commitResult = await _git.runChecked([
        '--git-dir=$shadowDir',
        'commit',
        '--allow-empty',
        '-m',
        'snapshot: ${kind.wireName}',
      ], failureContext: 'Creating initial workspace snapshot');
      if (commitResult case FailureResult<String>(:final failure)) {
        return FailureResult(failure);
      }

      final newHead = await _git.runChecked([
        '--git-dir=$shadowDir',
        'rev-parse',
        'HEAD',
      ], failureContext: 'Reading initial snapshot commit hash');
      if (newHead case FailureResult<String>(:final failure)) {
        return FailureResult(failure);
      }
      commitHash = (newHead as Success<String>).value.trim();

      final treeDiff = await _git.runChecked([
        '--git-dir=$shadowDir',
        '-c',
        'core.quotePath=false',
        'diff-tree',
        '--no-commit-id',
        '--name-status',
        '-r',
        '--root',
        '-z',
        commitHash,
      ], failureContext: 'Counting files in initial snapshot');
      if (treeDiff case FailureResult<String>(:final failure)) {
        return FailureResult(failure);
      }
      final changes = _parseNameStatusZ((treeDiff as Success<String>).value);
      for (final change in changes) {
        switch (change.changeType) {
          case SnapshotChangeType.added:
            addedCount++;
          case SnapshotChangeType.modified:
            modifiedCount++;
          case SnapshotChangeType.deleted:
            deletedCount++;
        }
      }
    }

    final snapshot = Snapshot(
      id: randomId(),
      runId: runId,
      nodeId: nodeId,
      commitHash: commitHash,
      kind: kind,
      addedCount: addedCount,
      modifiedCount: modifiedCount,
      deletedCount: deletedCount,
      createdAt: DateTime.now().toUtc(),
    );

    final createResult = await _snapshots.create(snapshot);
    if (createResult case FailureResult<Snapshot>(:final failure)) {
      return FailureResult(failure);
    }

    await _events.append(
      id: randomId(),
      runId: runId,
      nodeId: nodeId,
      type: RunEventType.snapshotCaptured,
      payload: {
        'snapshotId': snapshot.id,
        'commitHash': snapshot.commitHash,
        'kind': snapshot.kind.wireName,
        'addedCount': snapshot.addedCount,
        'modifiedCount': snapshot.modifiedCount,
        'deletedCount': snapshot.deletedCount,
      },
      createdAt: snapshot.createdAt,
    );

    return Success(snapshot);
  }

  /// Lists all snapshots for [runId] in chronological order.
  Future<Result<RunSnapshotsResponse>> listSnapshots(String runId) async {
    final runResult = await _runs.getById(runId);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    final listResult = await _snapshots.listForRun(runId);
    return listResult.map((items) => RunSnapshotsResponse(items: items));
  }

  /// Computes the file diff for [snapshotId] of [runId] on demand from the
  /// shadow repository.
  Future<Result<SnapshotDiff>> getSnapshotDiff(
    String runId,
    String snapshotId,
  ) async {
    final runResult = await _runs.getById(runId);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    final snapResult = await _snapshots.getById(runId, snapshotId);
    if (snapResult case FailureResult<Snapshot>(:final failure)) {
      return FailureResult(failure);
    }
    final snapshot = (snapResult as Success<Snapshot>).value;

    if (snapshot.addedCount == 0 &&
        snapshot.modifiedCount == 0 &&
        snapshot.deletedCount == 0) {
      return Success(SnapshotDiff(snapshotId: snapshotId, files: const []));
    }

    final shadowDir = shadowRepoPath(runId);
    final diffResult = await _git.runChecked([
      '--git-dir=$shadowDir',
      '-c',
      'core.quotePath=false',
      'diff-tree',
      '--no-commit-id',
      '--name-status',
      '-r',
      '--root',
      '-z',
      snapshot.commitHash,
    ], failureContext: 'Computing diff for snapshot "$snapshotId"');
    if (diffResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    final files = _parseNameStatusZ((diffResult as Success<String>).value);
    return Success(SnapshotDiff(snapshotId: snapshotId, files: files));
  }

  /// Restores the workspace of [runId] to [snapshotId] after taking an
  /// automatic `safety_pre_restore` snapshot.
  ///
  /// Rejects with [ConflictFailure] when the run is currently `running`.
  Future<Result<RestoreSnapshotResponse>> restoreSnapshot(
    String runId,
    String snapshotId, {
    List<String> extraExclusions = const [],
    int? maxFileSizeBytes = defaultMaxFileSizeBytes,
  }) async {
    final runResult = await _runs.getById(runId);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }
    final run = (runResult as Success<Run>).value;

    if (run.status == RunStatus.running) {
      return FailureResult(
        ConflictFailure(
          'Cannot restore snapshot while run "$runId" is running.',
        ),
      );
    }

    final snapResult = await _snapshots.getById(runId, snapshotId);
    if (snapResult case FailureResult<Snapshot>(:final failure)) {
      return FailureResult(failure);
    }
    final targetSnapshot = (snapResult as Success<Snapshot>).value;

    final workspaceDir = run.worktreePath ?? run.workspacePath;
    final safetyResult = await captureSnapshot(
      runId: runId,
      workspaceDir: workspaceDir,
      kind: SnapshotKind.safetyPreRestore,
      extraExclusions: extraExclusions,
      maxFileSizeBytes: maxFileSizeBytes,
    );
    if (safetyResult case FailureResult<Snapshot>(:final failure)) {
      return FailureResult(failure);
    }
    final safetySnapshot = (safetyResult as Success<Snapshot>).value;

    final shadowDir = shadowRepoPath(runId);
    // Pin the safety commit so reset --hard cannot leave it unreachable.
    await _git.run([
      '--git-dir=$shadowDir',
      'update-ref',
      'refs/hive/safety/${safetySnapshot.id}',
      safetySnapshot.commitHash,
    ]);

    final resetResult = await _git.runChecked([
      '--git-dir=$shadowDir',
      '--work-tree=$workspaceDir',
      'reset',
      '--hard',
      targetSnapshot.commitHash,
    ], failureContext: 'Restoring tracked files to snapshot "$snapshotId"');
    if (resetResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    // Remove untracked files created after targetSnapshot while preserving
    // .git/ and excluded files (no -x flag).
    final cleanResult = await _git.runChecked([
      '--git-dir=$shadowDir',
      '--work-tree=$workspaceDir',
      'clean',
      '-fd',
    ], failureContext: 'Cleaning untracked files during snapshot restore');
    if (cleanResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    await _events.append(
      id: randomId(),
      runId: runId,
      nodeId: targetSnapshot.nodeId,
      type: RunEventType.snapshotRestored,
      payload: {
        'restoredSnapshotId': targetSnapshot.id,
        'safetySnapshotId': safetySnapshot.id,
        'commitHash': targetSnapshot.commitHash,
      },
      createdAt: DateTime.now().toUtc(),
    );

    return Success(
      RestoreSnapshotResponse(
        restoredSnapshotId: targetSnapshot.id,
        safetySnapshot: safetySnapshot,
      ),
    );
  }

  /// Deletes the shadow git repository for [runId] if it exists.
  Future<void> deleteShadowRepository(String runId) async {
    final dir = Directory(shadowRepoPath(runId));
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup.
      }
    }
  }

  Future<Result<void>> _ensureShadowRepoInitialized(String shadowDir) async {
    final headFile = File(_pathContext.join(shadowDir, 'HEAD'));
    if (headFile.existsSync()) return const Success<void>(null);

    await Directory(shadowDir).create(recursive: true);

    final initResult = await _git.runChecked([
      'init',
      '--bare',
      shadowDir,
    ], failureContext: 'Initializing shadow repository');
    if (initResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    for (final setting in const [
      ['config', 'core.bare', 'false'],
      ['config', 'user.name', 'Agentic Hive'],
      ['config', 'user.email', 'hive@local'],
      ['config', 'core.autocrlf', 'false'],
      ['config', 'core.quotePath', 'false'],
    ]) {
      final cfgResult = await _git.runChecked([
        '--git-dir=$shadowDir',
        ...setting,
      ], failureContext: 'Configuring shadow repository');
      if (cfgResult case FailureResult<String>(:final failure)) {
        return FailureResult(failure);
      }
    }

    return const Success<void>(null);
  }

  Future<String> _buildExclusions({
    required String workspaceDir,
    required List<String> extraExclusions,
  }) async {
    final buffer = StringBuffer()
      ..writeln('.git/')
      ..writeln('.git');

    final hiveIgnore = File(_pathContext.join(workspaceDir, '.hiveignore'));
    if (hiveIgnore.existsSync()) {
      final content = await hiveIgnore.readAsString();
      if (content.isNotEmpty) {
        buffer.writeln(content.trimRight());
      }
    }

    for (final pattern in extraExclusions) {
      if (pattern.trim().isNotEmpty) {
        buffer.writeln(pattern.trim());
      }
    }

    return buffer.toString();
  }

  Future<List<({String path, int sizeBytes})>> _findOversizedFiles({
    required String shadowDir,
    required String workspaceDir,
    required int maxFileSizeBytes,
  }) async {
    final lsResult = await _git.run([
      '--git-dir=$shadowDir',
      '--work-tree=$workspaceDir',
      '-c',
      'core.quotePath=false',
      'ls-files',
      '--others',
      '--modified',
      '--exclude-standard',
      '-z',
    ]);
    if (lsResult.launchError != null ||
        lsResult.timedOut ||
        lsResult.exitCode != 0) {
      return const [];
    }

    final oversized = <({String path, int sizeBytes})>[];
    final entries = lsResult.stdout.split('\x00');
    for (final relPath in entries) {
      if (relPath.isEmpty) continue;
      final localPath = _pathContext.joinAll([
        workspaceDir,
        ...relPath.split('/'),
      ]);
      final type = FileSystemEntity.typeSync(localPath, followLinks: false);
      if (type != FileSystemEntityType.file) continue;
      final size = File(localPath).lengthSync();
      if (size > maxFileSizeBytes) {
        oversized.add((path: relPath, sizeBytes: size));
      }
    }
    return oversized;
  }

  List<SnapshotFileChange> _parseNameStatusZ(String stdout) {
    if (stdout.isEmpty) return const [];
    final tokens = stdout.split('\x00');
    final changes = <SnapshotFileChange>[];
    var i = 0;
    while (i < tokens.length) {
      final status = tokens[i++];
      if (status.isEmpty) continue;
      final code = status[0];
      if (code == 'R' || code == 'C') {
        if (i + 1 >= tokens.length) break;
        i++; // skip old path
        final newPath = tokens[i++];
        changes.add(
          SnapshotFileChange(
            path: newPath,
            changeType: SnapshotChangeType.modified,
          ),
        );
      } else {
        if (i >= tokens.length) break;
        final path = tokens[i++];
        final changeType = switch (code) {
          'A' => SnapshotChangeType.added,
          'D' => SnapshotChangeType.deleted,
          _ => SnapshotChangeType.modified,
        };
        changes.add(SnapshotFileChange(path: path, changeType: changeType));
      }
    }
    return changes;
  }
}
