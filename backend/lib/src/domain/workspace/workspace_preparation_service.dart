import 'dart:io';

import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';

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

/// Cleans up worktrees created on the fly for a run (ADR 0025).
final class WorkspacePreparationService {
  /// Creates a workspace preparation service.
  const new({required this._git});

  static final _log = Logger('workspace.preparation');

  final GitClient _git;

  /// Removes and prunes any worktree created for a run, then deletes its
  /// `hive/<runId>` branch when that is safe (`git branch -d` refuses a branch
  /// with commits not merged into the repository's current `HEAD`, which is
  /// kept so the user can still review or merge the run's work).
  ///
  /// Failures are logged, never swallowed silently.
  Future<void> cleanupWorktree({
    required String workspacePath,
    required String worktreePath,
    String? branchName,
  }) async {
    final repoExists = Directory(workspacePath).existsSync();
    if (repoExists) {
      await _runLogged([
        '-C',
        workspacePath,
        'worktree',
        'remove',
        '--force',
        worktreePath,
      ], 'worktree_remove');
      await _runLogged([
        '-C',
        workspacePath,
        'worktree',
        'prune',
      ], 'worktree_prune');
    }

    final dir = Directory(worktreePath);
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException catch (error) {
        _log.warning(
          LogEvent(
            'workspace.worktree_dir_delete_failed',
            fields: {'error': error.message},
          ),
        );
      }
    }

    if (repoExists && branchName != null) {
      await _runLogged([
        '-C',
        workspacePath,
        'branch',
        '-d',
        branchName,
      ], 'branch_delete');
    }
  }

  Future<void> _runLogged(List<String> arguments, String step) async {
    final result = await _git.run(arguments);
    if (result.launchError != null || result.timedOut || result.exitCode != 0) {
      _log.warning(
        LogEvent(
          'workspace.cleanup_git_failed',
          fields: {
            'step': step,
            'exitCode': result.exitCode,
            'timedOut': result.timedOut,
            'error': result.launchError ?? result.stderr.trim(),
          },
        ),
      );
    }
  }
}
