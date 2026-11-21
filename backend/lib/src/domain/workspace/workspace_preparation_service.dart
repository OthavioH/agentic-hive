import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Result of preparing a run's workspace (either direct or isolated worktree).
final class PreparedWorkspace {
  /// Creates a prepared workspace description.
  const new({
    required this.effectiveWorkspacePath,
    required this.isolationMode,
    this.worktreePath,
    this.worktreeBranch,
    this.warningMessage,
  });

  /// Directory where nodes and snapshots should operate.
  final String effectiveWorkspacePath;

  /// Effective isolation mode applied to the run.
  final WorkspaceIsolationMode isolationMode;

  /// Path to the created worktree when [isolationMode] is `worktree`.
  final String? worktreePath;

  /// Branch name (`hive/<runId>`) when [isolationMode] is `worktree`.
  final String? worktreeBranch;

  /// Optional warning (for example unborn `HEAD` fallback to direct mode).
  final String? warningMessage;
}

/// Prepares and cleans up per-run git worktrees when `worktree` isolation is
/// requested.
final class WorkspacePreparationService {
  /// Creates a workspace preparation service.
  const new({
    required this._git,
    required this._worktreesDir,
    required this._pathContext,
    this._events,
  });

  final GitClient _git;
  final String _worktreesDir;
  final p.Context _pathContext;
  final RunEventRepository? _events;

  /// Prepares the workspace for [runId] at [workspacePath].
  ///
  /// When [requestedMode] is [WorkspaceIsolationMode.worktree] and
  /// [workspacePath] is a git repository with a valid `HEAD`, creates
  /// `<worktreesDir>/<runId>` on branch `hive/<runId>` from `HEAD`.
  ///
  /// Falls back to [WorkspaceIsolationMode.direct] for non-git folders or
  /// repositories with an unborn `HEAD` (recording a `snapshot.warning` event
  /// when [recordWarningEvent] is true and [_events] is configured).
  Future<Result<PreparedWorkspace>> prepare({
    required String runId,
    required String workspacePath,
    WorkspaceIsolationMode requestedMode = WorkspaceIsolationMode.worktree,
    bool recordWarningEvent = false,
  }) async {
    if (!Directory(workspacePath).existsSync()) {
      return FailureResult(
        ValidationFailure('Workspace path "$workspacePath" does not exist.'),
      );
    }

    if (requestedMode == WorkspaceIsolationMode.direct) {
      return Success(
        PreparedWorkspace(
          effectiveWorkspacePath: workspacePath,
          isolationMode: WorkspaceIsolationMode.direct,
        ),
      );
    }

    final versionResult = await _git.run(const ['--version']);
    if (versionResult.launchError != null) {
      return FailureResult(
        ValidationFailure(
          'Git is not available: ${versionResult.launchError}. '
          'Install git and ensure it is on PATH.',
        ),
      );
    }

    final insideResult = await _git.run([
      '-C',
      workspacePath,
      'rev-parse',
      '--is-inside-work-tree',
    ]);
    final isGitRepo =
        insideResult.launchError == null &&
        !insideResult.timedOut &&
        insideResult.exitCode == 0 &&
        insideResult.stdout.trim() == 'true';

    if (!isGitRepo) {
      return Success(
        PreparedWorkspace(
          effectiveWorkspacePath: workspacePath,
          isolationMode: WorkspaceIsolationMode.direct,
        ),
      );
    }

    final headResult = await _git.run([
      '-C',
      workspacePath,
      'rev-parse',
      '--verify',
      'HEAD',
    ]);
    final hasCommits =
        headResult.launchError == null &&
        !headResult.timedOut &&
        headResult.exitCode == 0 &&
        headResult.stdout.trim().isNotEmpty;

    if (!hasCommits) {
      const warning =
          'Git repository has an unborn HEAD (no commits); '
          'falling back to direct workspace mode.';
      if (recordWarningEvent && _events != null) {
        await _events.append(
          id: randomId(),
          runId: runId,
          type: RunEventType.snapshotWarning,
          payload: const {'reason': 'unborn_head', 'message': warning},
          createdAt: DateTime.now().toUtc(),
        );
      }
      return Success(
        PreparedWorkspace(
          effectiveWorkspacePath: workspacePath,
          isolationMode: WorkspaceIsolationMode.direct,
          warningMessage: warning,
        ),
      );
    }

    final worktreePath = _pathContext.join(_worktreesDir, runId);
    final branchName = 'hive/$runId';
    await Directory(_worktreesDir).create(recursive: true);

    final addResult = await _git.runChecked([
      '-C',
      workspacePath,
      'worktree',
      'add',
      '-b',
      branchName,
      worktreePath,
      'HEAD',
    ], failureContext: 'Creating git worktree for run "$runId"');
    if (addResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    return Success(
      PreparedWorkspace(
        effectiveWorkspacePath: worktreePath,
        isolationMode: WorkspaceIsolationMode.worktree,
        worktreePath: worktreePath,
        worktreeBranch: branchName,
      ),
    );
  }

  /// Removes and prunes any worktree created for a run.
  Future<void> cleanupWorktree({
    required String workspacePath,
    required String worktreePath,
  }) async {
    if (Directory(workspacePath).existsSync()) {
      await _git.run([
        '-C',
        workspacePath,
        'worktree',
        'remove',
        '--force',
        worktreePath,
      ]);
      await _git.run(['-C', workspacePath, 'worktree', 'prune']);
    }

    final dir = Directory(worktreePath);
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup when directory is already removed or locked.
      }
    }
  }
}
