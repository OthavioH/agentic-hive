import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/active_run_lookup.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/canonical_folder.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// The HEAD commit and cleanliness of a git folder.
final class FolderHead {
  /// Creates a [FolderHead].
  const new({required this.commit, required this.hasUncommittedChanges});

  /// Full SHA-1 commit hash of `HEAD`.
  final String commit;

  /// Whether `git status --porcelain` reported any changes.
  final bool hasUncommittedChanges;
}

/// Creates, lists and removes the worktrees of a git [Workspace] (ADR 0025).
///
/// Git is the source of truth: the list comes from `git worktree list`, so
/// worktrees left on disk by old runs appear without any migration. Only
/// worktrees inside the app's worktrees folder are managed here (listed and
/// removable); the primary checkout is listed first and never removable.
final class WorktreeService {
  /// Creates a worktree service.
  ///
  /// New worktrees go to `<worktreesDir>/<workspace id>/<name>`.
  new({
    required this._git,
    required this._activeRuns,
    required this._worktreesDir,
    p.Context? pathContext,
  }) : _path = pathContext ?? p.context;

  static final _log = Logger('worktrees');
  static final _validName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  final GitClient _git;
  final ActiveRunLookup _activeRuns;
  final String _worktreesDir;
  final p.Context _path;

  /// Lists the primary checkout and the managed worktrees of [workspace].
  ///
  /// A non-git workspace has no worktrees.
  Future<Result<List<Worktree>>> list(Workspace workspace) async {
    if (!workspace.isGit) return const Success([]);
    final entries = await _gitEntries(workspace);
    if (entries case FailureResult<List<_Entry>>(:final failure)) {
      return FailureResult(failure);
    }
    final items = <Worktree>[];
    for (final entry in entries.valueOrNull!) {
      final isPrimary = items.isEmpty;
      if (!isPrimary && !_isManaged(entry.path)) continue;
      if (!Directory(entry.path).existsSync()) continue;
      final dirty = await _hasUncommittedChanges(entry.path);
      if (dirty case FailureResult<bool>(:final failure)) {
        return FailureResult(failure);
      }
      final name = _path.basename(entry.path);
      items.add(
        Worktree(
          id: isPrimary ? primaryWorktreeId : name,
          name: isPrimary ? _path.basename(workspace.rootPath) : name,
          path: entry.path,
          isPrimary: isPrimary,
          hasUncommittedChanges: dirty.valueOrNull!,
          branch: entry.branch,
        ),
      );
    }
    return Success(items);
  }

  /// Creates a worktree in [workspace] on a new branch.
  Future<Result<Worktree>> create(
    Workspace workspace,
    CreateWorktreeRequest request,
  ) async {
    if (!workspace.isGit) {
      return const FailureResult(
        ValidationFailure('Worktrees need a git workspace.'),
      );
    }
    final name = request.name.trim();
    if (!_validName.hasMatch(name) || name == primaryWorktreeId) {
      return FailureResult(
        ValidationFailure(
          'Worktree name "$name" is invalid: use letters, digits, ".", "_" '
          'and "-", starting with a letter or digit ("$primaryWorktreeId" is '
          'reserved).',
        ),
      );
    }
    final branch = (request.branch?.trim().isNotEmpty ?? false)
        ? request.branch!.trim()
        : name;
    final branchCheck = await _git.runAllowingExitCodes(
      ['check-ref-format', '--branch', branch],
      allowedExitCodes: {0, 1, 128},
    );
    if (branchCheck case FailureResult<ProcessRunResult>(:final failure)) {
      return FailureResult(failure);
    }
    if (branchCheck.valueOrNull!.exitCode != 0) {
      return FailureResult(
        ValidationFailure('"$branch" is not a valid branch name.'),
      );
    }

    final base = await _resolveBase(workspace, request.baseBranch);
    if (base case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    final exists = await _branchExists(workspace.rootPath, branch);
    if (exists case FailureResult<bool>(:final failure)) {
      return FailureResult(failure);
    }
    if (exists.valueOrNull!) {
      return FailureResult(ConflictFailure('Branch "$branch" already exists.'));
    }

    final target = _path.join(_worktreesDir, workspace.id, name);
    if (Directory(target).existsSync() || File(target).existsSync()) {
      return FailureResult(
        ConflictFailure('A worktree named "$name" already exists.'),
      );
    }
    await Directory(_path.dirname(target)).create(recursive: true);

    final added = await _git.runChecked([
      '-C',
      workspace.rootPath,
      'worktree',
      'add',
      '-b',
      branch,
      target,
      base.valueOrNull!,
    ], failureContext: 'Creating worktree "$name"');
    if (added case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }
    return Success(
      Worktree(
        id: name,
        name: name,
        path: _path.normalize(target),
        isPrimary: false,
        hasUncommittedChanges: false,
        branch: branch,
      ),
    );
  }

  /// Removes worktree [id] of [workspace].
  ///
  /// Refused while a run is active in it, and for uncommitted changes unless
  /// [force]. Success is judged by whether the folder is gone after
  /// `git worktree remove`: it is idempotent for a registered worktree whose
  /// folder is already deleted, while a folder that remains returns a
  /// [ConflictFailure]. The branch is deleted only when merged
  /// (`git branch -d`), otherwise kept with a notice. Nothing outside the
  /// worktree is deleted.
  Future<Result<RemoveWorktreeResponse>> remove(
    Workspace workspace,
    String id, {
    bool force = false,
  }) async {
    if (id == primaryWorktreeId) {
      return const FailureResult(
        ValidationFailure('The primary checkout cannot be removed.'),
      );
    }
    final entries = await _gitEntries(workspace);
    if (entries case FailureResult<List<_Entry>>(:final failure)) {
      return FailureResult(failure);
    }
    final entry = entries.valueOrNull!
        .skip(1)
        .where((e) => _isManaged(e.path) && _path.basename(e.path) == id)
        .firstOrNull;
    final String targetPath;
    if (entry != null) {
      targetPath = entry.path;
    } else {
      if (!_validName.hasMatch(id)) {
        return FailureResult(NotFoundFailure('Worktree "$id" was not found.'));
      }
      final leftover = _path.join(_worktreesDir, workspace.id, id);
      if (!_isManaged(leftover) || !Directory(leftover).existsSync()) {
        return FailureResult(NotFoundFailure('Worktree "$id" was not found.'));
      }
      targetPath = leftover;
    }

    final active = await _activeRuns.activeTargetFolders(workspace.id);
    if (active case FailureResult<Set<String>>(:final failure)) {
      return FailureResult(failure);
    }
    final key = canonicalFolder(targetPath, _path);
    if (active.valueOrNull!.any(
      (folder) => canonicalFolder(folder, _path) == key,
    )) {
      return FailureResult(
        ConflictFailure('A run is active in worktree "$id".'),
      );
    }
    if (entry == null) {
      if (!force) {
        return FailureResult(
          ConflictFailure(
            'Worktree "$id" has uncommitted changes; confirm to discard them.',
          ),
        );
      }
      try {
        await Directory(targetPath).delete(recursive: true);
      } on FileSystemException catch (e) {
        _log.warning(
          LogEvent(
            'worktrees.remove_failed',
            fields: {'workspaceId': workspace.id, 'worktreeId': id},
          ),
          e.toString(),
        );
        return FailureResult(
          ConflictFailure(
            'Some files in worktree "$id" are in use or could not be '
            'deleted. Close programs using it and try again.',
          ),
        );
      }
    } else {
      if (Directory(targetPath).existsSync() && !force) {
        final dirty = await _hasUncommittedChanges(targetPath);
        if (dirty case FailureResult<bool>(:final failure)) {
          return FailureResult(failure);
        }
        if (dirty.valueOrNull!) {
          return FailureResult(
            ConflictFailure(
              'Worktree "$id" has uncommitted changes; confirm to discard '
              'them.',
            ),
          );
        }
      }

      final removal = await _git.run([
        '-C',
        workspace.rootPath,
        'worktree',
        'remove',
        if (force) '--force',
        targetPath,
      ]);
      if (removal.exitCode != 0) {
        _log.warning(
          LogEvent(
            'worktrees.remove_failed',
            fields: {
              'workspaceId': workspace.id,
              'worktreeId': id,
              'exitCode': removal.exitCode,
              if (removal.timedOut) 'timedOut': true,
              if (removal.launchError != null)
                'launchError': removal.launchError.toString(),
            },
          ),
          removal.stderr.trim(),
        );
        if (Directory(targetPath).existsSync()) {
          return FailureResult(
            ConflictFailure(
              'Some files in worktree "$id" are in use or could not be '
              'deleted. Close programs using it and try again.',
            ),
          );
        }
      }
    }

    final pruned = await _git.run([
      '-C',
      workspace.rootPath,
      'worktree',
      'prune',
    ]);
    if (pruned.exitCode != 0) {
      _log.warning(
        LogEvent(
          'worktrees.prune_failed',
          fields: {
            'workspaceId': workspace.id,
            'worktreeId': id,
            'exitCode': pruned.exitCode,
            if (pruned.timedOut) 'timedOut': true,
            if (pruned.launchError != null)
              'launchError': pruned.launchError.toString(),
          },
        ),
        pruned.stderr.trim(),
      );
    }

    if (entry == null) {
      return Success(
        RemoveWorktreeResponse(
          id: id,
          deleted: true,
          branchDeleted: false,
          notice:
              'The worktree folder was removed, but its branch could not be '
              'determined because git no longer tracked it.',
        ),
      );
    }
    final branch = entry.branch;
    if (branch == null) {
      return Success(
        RemoveWorktreeResponse(id: id, deleted: true, branchDeleted: false),
      );
    }
    final deleted = await _git.run([
      '-C',
      workspace.rootPath,
      'branch',
      '-d',
      branch,
    ]);
    if (deleted.exitCode == 0) {
      return Success(
        RemoveWorktreeResponse(id: id, deleted: true, branchDeleted: true),
      );
    }
    return Success(
      RemoveWorktreeResponse(
        id: id,
        deleted: true,
        branchDeleted: false,
        notice:
            'Branch "$branch" was kept because it is not merged. Delete it '
            'yourself when you no longer need it.',
      ),
    );
  }

  Future<Result<String>> _resolveBase(
    Workspace workspace,
    String? requested,
  ) async {
    final wanted = requested?.trim();
    if (wanted == null || wanted.isEmpty) {
      final head = await _git.runAllowingExitCodes(
        ['-C', workspace.rootPath, 'symbolic-ref', '--short', 'HEAD'],
        allowedExitCodes: {0, 128},
      );
      if (head case FailureResult<ProcessRunResult>(:final failure)) {
        return FailureResult(failure);
      }
      final run = head.valueOrNull!;
      if (run.exitCode != 0 || run.stdout.trim().isEmpty) {
        return const FailureResult(
          ValidationFailure(
            'The primary checkout has no current branch; choose a base '
            'branch.',
          ),
        );
      }
      return Success(run.stdout.trim());
    }
    final verified = await _git.runAllowingExitCodes(
      [
        '-C',
        workspace.rootPath,
        'rev-parse',
        '--verify',
        '--quiet',
        '$wanted^{commit}',
      ],
      allowedExitCodes: {0, 1},
    );
    if (verified case FailureResult<ProcessRunResult>(:final failure)) {
      return FailureResult(failure);
    }
    if (verified.valueOrNull!.exitCode != 0) {
      return FailureResult(
        ValidationFailure('Base branch "$wanted" does not exist.'),
      );
    }
    return Success(wanted);
  }

  Future<Result<bool>> _branchExists(String root, String branch) async {
    final result = await _git.runAllowingExitCodes(
      ['-C', root, 'rev-parse', '--verify', '--quiet', 'refs/heads/$branch'],
      allowedExitCodes: {0, 1},
    );
    return result.map((run) => run.exitCode == 0);
  }

  Future<Result<bool>> _hasUncommittedChanges(String folder) async {
    final status = await _git.runChecked([
      '-C',
      folder,
      'status',
      '--porcelain',
    ], failureContext: 'Reading the status of "$folder"');
    return status.map((out) => out.trim().isNotEmpty);
  }

  /// The HEAD commit and cleanliness of git folder [folder].
  Future<Result<FolderHead>> inspectHead(String folder) async {
    final head = await _git.runChecked([
      '-C',
      folder,
      'rev-parse',
      'HEAD',
    ], failureContext: 'Reading HEAD of "$folder"');
    if (head case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final dirty = await _hasUncommittedChanges(folder);
    if (dirty case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    return Success(
      FolderHead(
        commit: head.valueOrNull!.trim(),
        hasUncommittedChanges: dirty.valueOrNull!,
      ),
    );
  }

  Future<Result<List<_Entry>>> _gitEntries(Workspace workspace) async {
    final output = await _git.runChecked([
      '-C',
      workspace.rootPath,
      'worktree',
      'list',
      '--porcelain',
    ], failureContext: 'Listing worktrees');
    return output.map((text) {
      final entries = <_Entry>[];
      String? path;
      String? branch;
      void flush() {
        if (path != null) entries.add(_Entry(_path.normalize(path!), branch));
        path = null;
        branch = null;
      }

      for (final line in text.split('\n').map((l) => l.trimRight())) {
        if (line.isEmpty) {
          flush();
        } else if (line.startsWith('worktree ')) {
          flush();
          path = line.substring('worktree '.length);
        } else if (line.startsWith('branch ')) {
          const prefix = 'refs/heads/';
          final ref = line.substring('branch '.length);
          branch = ref.startsWith(prefix) ? ref.substring(prefix.length) : ref;
        }
      }
      flush();
      return entries;
    });
  }

  bool _isManaged(String folder) {
    final base = canonicalFolder(_worktreesDir, _path);
    return _path.isWithin(base, canonicalFolder(folder, _path));
  }
}

final class _Entry {
  const new(this.path, this.branch);

  final String path;
  final String? branch;
}
