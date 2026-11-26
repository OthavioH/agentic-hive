import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/worktree_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Claims [folder] for the starting run; returns the conflict when it is busy.
typedef FolderClaim = Future<ConflictFailure?> Function(String folder);

/// Resolves, claims and prepares the target folder of a starting run
/// (ADR 0025).
abstract base class RunTargetPreparer {
  /// Creates a run target preparer.
  const new();

  /// Maps [target] to the [RunTargetPreparer] that handles it.
  factory forTarget(
    RunTarget target, {
    required WorktreeService? worktrees,
    required WorkspacePreparationService workspacePreparation,
  }) => switch (target) {
    RunTargetPrimary() => const PrimaryCheckoutPreparer(),
    RunTargetWorktree(:final worktreeId) => ExistingWorktreePreparer(
      worktreeId: worktreeId,
      worktrees: worktrees,
    ),
    RunTargetNewWorktree(:final name, :final branch, :final baseBranch) =>
      NewWorktreePreparer(
        name: name,
        branch: branch,
        baseBranch: baseBranch,
        worktrees: worktrees,
        workspacePreparation: workspacePreparation,
      ),
  };

  /// Resolves the target folder for [runId] in [workspace] and claims it
  /// through [claim].
  ///
  /// Cleans up anything it created when it fails.
  Future<Result<PreparedWorkspace>> prepare({
    required Workspace workspace,
    required String runId,
    required FolderClaim claim,
  });

  /// Undoes what a successful [prepare] created when starting the run fails
  /// later.
  Future<void> discard(Workspace workspace, PreparedWorkspace prepared) async {}
}

/// Prepares a run target pointing at the [Workspace]'s primary checkout.
final class PrimaryCheckoutPreparer extends RunTargetPreparer {
  /// Creates a primary-checkout preparer.
  const new();

  @override
  Future<Result<PreparedWorkspace>> prepare({
    required Workspace workspace,
    required String runId,
    required FolderClaim claim,
  }) async {
    final conflict = await claim(workspace.rootPath);
    if (conflict != null) return FailureResult(conflict);
    return Success(
      PreparedWorkspace(
        targetFolder: workspace.rootPath,
        isolationMode: WorkspaceIsolationMode.direct,
      ),
    );
  }
}

/// Prepares a run target pointing at an existing worktree of the [Workspace].
///
/// When the target identifies the primary checkout, it delegates to
/// [PrimaryCheckoutPreparer].
final class ExistingWorktreePreparer extends RunTargetPreparer {
  /// Creates an existing-worktree preparer.
  const new({required this._worktreeId, required this._worktrees});

  final String _worktreeId;
  final WorktreeService? _worktrees;

  @override
  Future<Result<PreparedWorkspace>> prepare({
    required Workspace workspace,
    required String runId,
    required FolderClaim claim,
  }) async {
    final worktrees = _worktrees;
    if (worktrees == null) {
      return const FailureResult(
        UnexpectedFailure('Worktree service is not configured.'),
      );
    }
    final listed = await worktrees.list(workspace);
    if (listed case FailureResult<List<Worktree>>(:final failure)) {
      return FailureResult(failure);
    }
    final existing = listed.valueOrNull!
        .where((w) => w.id == _worktreeId)
        .firstOrNull;
    if (existing == null) {
      return FailureResult(
        NotFoundFailure('Worktree "$_worktreeId" was not found.'),
      );
    }
    if (existing.isBroken) {
      return FailureResult(
        ConflictFailure(
          'Worktree "$_worktreeId" is broken: git cannot read it. '
          'Remove it and create a new one.',
        ),
      );
    }
    if (existing.isPrimary) {
      return await const PrimaryCheckoutPreparer().prepare(
        workspace: workspace,
        runId: runId,
        claim: claim,
      );
    }
    final conflict = await claim(existing.path);
    if (conflict != null) return FailureResult(conflict);
    return Success(
      PreparedWorkspace(
        targetFolder: existing.path,
        isolationMode: WorkspaceIsolationMode.worktree,
        worktreePath: existing.path,
        worktreeBranch: existing.branch,
      ),
    );
  }
}

/// Creates and prepares a new worktree in the [Workspace] for a starting run.
final class NewWorktreePreparer extends RunTargetPreparer {
  /// Creates a new-worktree preparer.
  const new({
    required this._worktrees,
    required this._workspacePreparation,
    this._name,
    this._branch,
    this._baseBranch,
  });

  final String? _name;
  final String? _branch;
  final String? _baseBranch;
  final WorktreeService? _worktrees;
  final WorkspacePreparationService _workspacePreparation;

  @override
  Future<Result<PreparedWorkspace>> prepare({
    required Workspace workspace,
    required String runId,
    required FolderClaim claim,
  }) async {
    final worktrees = _worktrees;
    if (worktrees == null) {
      return const FailureResult(
        UnexpectedFailure('Worktree service is not configured.'),
      );
    }
    final created = await worktrees.create(
      workspace,
      CreateWorktreeRequest(
        name: _nonBlank(_name) ?? runId,
        branch: _nonBlank(_branch) ?? 'hive/$runId',
        baseBranch: _baseBranch,
      ),
    );
    if (created case FailureResult<Worktree>(:final failure)) {
      return FailureResult(failure);
    }
    final worktree = created.valueOrNull!;
    final conflict = await claim(worktree.path);
    if (conflict != null) {
      await _workspacePreparation.cleanupWorktree(
        workspaceRoot: workspace.rootPath,
        worktreePath: worktree.path,
        branchName: worktree.branch,
      );
      return FailureResult(conflict);
    }
    return Success(
      PreparedWorkspace(
        targetFolder: worktree.path,
        isolationMode: WorkspaceIsolationMode.worktree,
        worktreePath: worktree.path,
        worktreeBranch: worktree.branch,
      ),
    );
  }

  @override
  Future<void> discard(Workspace workspace, PreparedWorkspace prepared) async {
    final worktreePath = prepared.worktreePath;
    if (worktreePath == null) return;
    await _workspacePreparation.cleanupWorktree(
      workspaceRoot: workspace.rootPath,
      worktreePath: worktreePath,
      branchName: prepared.worktreeBranch,
    );
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
