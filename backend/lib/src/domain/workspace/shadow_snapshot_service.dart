import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/snapshot_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/snapshot_service.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Manages per-run shadow git repositories, snapshot capture, diffs, and
/// workspace rollback ("step back").
///
/// Behavior notes:
///
/// - Every shadow git command ignores user-level git configuration that could
///   interfere with unattended snapshots (commit signing, hooks, fsmonitor,
///   global excludes) and enables long paths; commits pass `--no-verify`.
/// - The shadow repository honors `.gitignore` files found inside the
///   workspace, so files ignored by the user's own repository are never
///   captured and are **preserved** (neither overwritten nor deleted) on
///   restore, exactly like files excluded through `.hiveignore`.
/// - A nested git repository inside the workspace is recorded as a gitlink
///   (embedded repository); its contents are not captured or restored.
/// - Capture and restore for the same run are serialized by a per-run lock.
/// - Exclusions and the size limit used by the latest capture are persisted in
///   the shadow repository, so a restore (and its safety snapshot) applies the
///   same rules unless explicit overrides are passed.
final class ShadowSnapshotService implements SnapshotService {
  /// Creates a shadow snapshot service.
  new({
    required this._git,
    required this._runs,
    required this._snapshots,
    required this._events,
    required this._snapshotsDir,
    required this._pathContext,
  });

  /// Default per-file size limit (50 MB).
  static const int defaultMaxFileSizeBytes = 50 * 1024 * 1024;

  static final _log = Logger('workspace.snapshots');
  static const _optionsFileName = 'hive-snapshot-options.json';
  static const _noHooksDirName = 'hive-no-hooks';

  final Map<String, Future<void>> _runLocks = {};
  final Map<String, List<String>> _runExclusions = {};
  final GitClient _git;
  final RunRepository _runs;
  final SnapshotRepository _snapshots;
  final RunEventRepository _events;
  final String _snapshotsDir;
  final p.Context _pathContext;

  /// Registers per-run extra exclusion patterns (for example from
  /// `StartRunRequest.ignorePatterns`) applied to every snapshot captured or
  /// restored for [runId].
  void configureRunExclusions(String runId, List<String> exclusions) {
    final cleaned = exclusions
        .map((pattern) => pattern.trim())
        .where((pattern) => pattern.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) {
      _runExclusions.remove(runId);
    } else {
      _runExclusions[runId] = cleaned;
    }
  }

  /// Absolute path to the shadow git repository for [runId].
  String shadowRepoPath(String runId) =>
      _pathContext.join(_snapshotsDir, runId);

  /// Captures a workspace snapshot for [runId] in [workspaceDir].
  ///
  /// [extraExclusions] and [maxFileSizeBytes] (`null` or `<= 0` disables the
  /// guard) are persisted so [restoreSnapshot] applies the same rules.
  @override
  Future<Result<Snapshot>> captureSnapshot({
    required String runId,
    required String workspaceDir,
    String? nodeId,
    SnapshotKind kind = SnapshotKind.preNode,
    List<String> extraExclusions = const [],
    int? maxFileSizeBytes = defaultMaxFileSizeBytes,
  }) => _withRunLock(
    runId,
    () => _captureLocked(
      runId: runId,
      workspaceDir: workspaceDir,
      nodeId: nodeId,
      kind: kind,
      options: _CaptureOptions(
        extraExclusions: extraExclusions,
        maxFileSizeBytes: maxFileSizeBytes,
      ),
    ),
  );

  Future<Result<Snapshot>> _captureLocked({
    required String runId,
    required String workspaceDir,
    required _CaptureOptions options,
    required SnapshotKind kind,
    String? nodeId,
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
    await _clearStaleIndexLock(shadowDir);
    final configuredExclusions = _runExclusions[runId] ?? const <String>[];
    final effectiveOptions = configuredExclusions.isEmpty
        ? options
        : _CaptureOptions(
            extraExclusions: <String>{
              ...configuredExclusions,
              ...options.extraExclusions,
            }.toList(growable: false),
            maxFileSizeBytes: options.maxFileSizeBytes,
          );
    await File(_pathContext.join(shadowDir, _optionsFileName))
        .writeAsString(jsonEncode(effectiveOptions.toJson()));

    final excludeFile = File(_pathContext.join(shadowDir, 'info', 'exclude'));
    final baseExclusions = await _buildExclusions(
      workspaceDir: workspaceDir,
      extraExclusions: effectiveOptions.extraExclusions,
    );
    await excludeFile.parent.create(recursive: true);
    await excludeFile.writeAsString(baseExclusions);

    // Find files above the size limit (untracked or tracked-and-grown). The
    // exclude file only hides untracked paths, so tracked ones are also
    // removed from the index after staging.
    final maxFileSizeBytes = options.maxFileSizeBytes;
    var oversized = const <({String path, int sizeBytes})>[];
    if (maxFileSizeBytes != null && maxFileSizeBytes > 0) {
      oversized = await _findOversizedFiles(
        shadowDir: shadowDir,
        workspaceDir: workspaceDir,
        maxFileSizeBytes: maxFileSizeBytes,
      );
      if (oversized.isNotEmpty) {
        final extraBuffer = StringBuffer(baseExclusions);
        for (final entry in oversized) {
          extraBuffer.writeln(_escapeExcludePath(entry.path));
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

    final addResult = await _git.runChecked(
      _shadowArgs(shadowDir, workspaceDir, const ['add', '-A']),
      timeout: GitClient.longTimeout,
      failureContext: 'Staging workspace files for snapshot',
    );
    if (addResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    final unstageResult = await _unstageOversized(
      shadowDir: shadowDir,
      workspaceDir: workspaceDir,
      paths: [for (final entry in oversized) entry.path],
    );
    if (unstageResult case FailureResult<void>(:final failure)) {
      return FailureResult(failure);
    }

    final headCheck = await _git.run(
      _shadowArgs(shadowDir, null, const ['rev-parse', '--verify', 'HEAD']),
    );
    final hasPrevCommit =
        headCheck.launchError == null &&
        !headCheck.timedOut &&
        headCheck.exitCode == 0 &&
        headCheck.stdout.trim().isNotEmpty;

    final snapshotId = randomId();
    late final String commitHash;
    var addedCount = 0;
    var modifiedCount = 0;
    var deletedCount = 0;

    if (hasPrevCommit) {
      final prevHash = headCheck.stdout.trim();
      // Exit 0 = nothing staged, 1 = changes staged; any other code is a
      // failure that must not be mistaken for "changed".
      final diffQuiet = await _git.runAllowingExitCodes(
        _shadowArgs(shadowDir, workspaceDir, const [
          'diff',
          '--cached',
          '--quiet',
        ]),
        allowedExitCodes: const {0, 1},
        timeout: GitClient.longTimeout,
        failureContext: 'Checking for staged snapshot changes',
      );
      if (diffQuiet case FailureResult<ProcessRunResult>(:final failure)) {
        return FailureResult(failure);
      }
      final changed =
          (diffQuiet as Success<ProcessRunResult>).value.exitCode == 1;
      if (!changed) {
        // No changes relative to previous commit: reuse commitHash.
        commitHash = prevHash;
      } else {
        final diffStatus = await _git.runChecked(
          _shadowArgs(shadowDir, workspaceDir, const [
            'diff',
            '--cached',
            '--name-status',
            '-z',
          ]),
          timeout: GitClient.longTimeout,
          failureContext: 'Inspecting staged snapshot diff',
        );
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

        final commitResult = await _commit(shadowDir, kind);
        if (commitResult case FailureResult<String>(:final failure)) {
          return FailureResult(failure);
        }
        commitHash = (commitResult as Success<String>).value;
      }
    } else {
      final commitResult = await _commit(shadowDir, kind, allowEmpty: true);
      if (commitResult case FailureResult<String>(:final failure)) {
        return FailureResult(failure);
      }
      commitHash = (commitResult as Success<String>).value;

      final treeDiff = await _git.runChecked(
        _shadowArgs(shadowDir, null, [
          'diff-tree',
          '--no-commit-id',
          '--name-status',
          '-r',
          '--root',
          '-z',
          commitHash,
        ]),
        timeout: GitClient.longTimeout,
        failureContext: 'Counting files in initial snapshot',
      );
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

    // Pin every snapshot so `reset --hard` can never leave it unreachable
    // (and so it survives garbage collection).
    final pinResult = await _git.runChecked(
      _shadowArgs(shadowDir, null, [
        'update-ref',
        'refs/hive/snap/$snapshotId',
        commitHash,
      ]),
      failureContext: 'Pinning snapshot commit',
    );
    if (pinResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    final snapshot = Snapshot(
      id: snapshotId,
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
  @override
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
    final diffResult = await _git.runChecked(
      _shadowArgs(shadowDir, null, [
        'diff-tree',
        '--no-commit-id',
        '--name-status',
        '-r',
        '--root',
        '-z',
        snapshot.commitHash,
      ]),
      timeout: GitClient.longTimeout,
      failureContext: 'Computing diff for snapshot "$snapshotId"',
    );
    if (diffResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    final files = _parseNameStatusZ((diffResult as Success<String>).value);
    return Success(SnapshotDiff(snapshotId: snapshotId, files: files));
  }

  /// Restores the workspace of [runId] to [snapshotId] after taking an
  /// automatic `safety_pre_restore` snapshot.
  ///
  /// The safety snapshot and the final clean use the exclusions and size limit
  /// of the latest capture (persisted in the shadow repository) unless
  /// [extraExclusions] / [maxFileSizeBytes] are given explicitly. Files
  /// ignored by `.hiveignore`, `.gitignore`, the exclusions, or the size limit
  /// are preserved.
  ///
  /// Rejects with [ConflictFailure] when the run is currently `running`. The
  /// status is checked inside the per-run lock and re-checked right before
  /// files are rewritten.
  @override
  Future<Result<RestoreSnapshotResponse>> restoreSnapshot(
    String runId,
    String snapshotId, {
    List<String>? extraExclusions,
    int? maxFileSizeBytes,
  }) => _withRunLock(
    runId,
    () => _restoreLocked(
      runId,
      snapshotId,
      extraExclusions: extraExclusions,
      maxFileSizeBytes: maxFileSizeBytes,
    ),
  );

  Future<Result<RestoreSnapshotResponse>> _restoreLocked(
    String runId,
    String snapshotId, {
    List<String>? extraExclusions,
    int? maxFileSizeBytes,
  }) async {
    final runResult = await _runs.getById(runId);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }
    final run = (runResult as Success<Run>).value;

    if (run.status.isExecutingProcesses) {
      return FailureResult(
        ConflictFailure(
          'Cannot restore snapshot while run "$runId" is '
          '${run.status.name}.',
        ),
      );
    }

    final snapResult = await _snapshots.getById(runId, snapshotId);
    if (snapResult case FailureResult<Snapshot>(:final failure)) {
      return FailureResult(failure);
    }
    final targetSnapshot = (snapResult as Success<Snapshot>).value;

    final shadowDir = shadowRepoPath(runId);
    final stored = await _readOptions(shadowDir);
    final options = _CaptureOptions(
      extraExclusions: extraExclusions ?? stored.extraExclusions,
      maxFileSizeBytes: maxFileSizeBytes ?? stored.maxFileSizeBytes,
    );

    final targetFolder = run.worktreePath ?? run.workspaceRoot;
    final safetyResult = await _captureLocked(
      runId: runId,
      workspaceDir: targetFolder,
      kind: SnapshotKind.safetyPreRestore,
      options: options,
    );
    if (safetyResult case FailureResult<Snapshot>(:final failure)) {
      return FailureResult(failure);
    }
    final safetySnapshot = (safetyResult as Success<Snapshot>).value;

    // The safety capture can take a while; make sure the run did not start
    // executing processes in the meantime before rewriting files.
    final recheck = await _runs.getById(runId);
    if (recheck case Success<Run>(:final value)
        when value.status.isExecutingProcesses) {
      return FailureResult(
        ConflictFailure(
          'Cannot restore snapshot while run "$runId" is '
          '${value.status.name}.',
        ),
      );
    }

    final resetResult = await _git.runChecked(
      _shadowArgs(shadowDir, targetFolder, [
        'reset',
        '--hard',
        targetSnapshot.commitHash,
      ]),
      timeout: GitClient.longTimeout,
      failureContext: 'Restoring tracked files to snapshot "$snapshotId"',
    );
    if (resetResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }

    // Remove untracked files created after targetSnapshot while preserving
    // .git/ and excluded files (no -x flag).
    final cleanResult = await _git.runChecked(
      _shadowArgs(shadowDir, targetFolder, const ['clean', '-fd']),
      timeout: GitClient.longTimeout,
      failureContext: 'Cleaning untracked files during snapshot restore',
    );
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

  /// Deletes the shadow git repository for [runId] if it exists, logging (not
  /// swallowing) any failure.
  Future<void> deleteShadowRepository(String runId) =>
      _withRunLock(runId, () async {
        final dir = Directory(shadowRepoPath(runId));
        if (!dir.existsSync()) return;
        try {
          await dir.delete(recursive: true);
        } on FileSystemException catch (error) {
          _log.warning(
            LogEvent(
              'workspace.shadow_repo_delete_failed',
              fields: {'runId': runId, 'error': error.message},
            ),
          );
        }
      });

  Future<T> _withRunLock<T>(String runId, Future<T> Function() action) async {
    final previous = _runLocks[runId] ?? Future<void>.value();
    final released = Completer<void>();
    final tail = previous.then((_) => released.future);
    _runLocks[runId] = tail;
    await previous;
    try {
      return await action();
    } finally {
      released.complete();
      if (identical(_runLocks[runId], tail)) {
        unawaited(_runLocks.remove(runId));
      }
    }
  }

  /// Builds a shadow-repository git command line that ignores user-level git
  /// configuration which could break unattended snapshots.
  List<String> _shadowArgs(
    String shadowDir,
    String? workspaceDir,
    List<String> command,
  ) => [
    '--git-dir=$shadowDir',
    if (workspaceDir != null) '--work-tree=$workspaceDir',
    '-c',
    'commit.gpgsign=false',
    '-c',
    'tag.gpgsign=false',
    '-c',
    'core.hooksPath=${_pathContext.join(shadowDir, _noHooksDirName)}',
    '-c',
    'core.fsmonitor=false',
    '-c',
    'core.excludesFile=',
    '-c',
    'core.longpaths=true',
    '-c',
    'core.quotePath=false',
    ...command,
  ];

  /// Commits the staged tree and returns the new `HEAD` hash.
  Future<Result<String>> _commit(
    String shadowDir,
    SnapshotKind kind, {
    bool allowEmpty = false,
  }) async {
    final commitResult = await _git.runChecked(
      _shadowArgs(shadowDir, null, [
        'commit',
        '--no-verify',
        '--no-gpg-sign',
        if (allowEmpty) '--allow-empty',
        '-m',
        'snapshot: ${kind.wireName}',
      ]),
      timeout: GitClient.longTimeout,
      failureContext: 'Committing workspace snapshot',
    );
    if (commitResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }
    final head = await _git.runChecked(
      _shadowArgs(shadowDir, null, const ['rev-parse', 'HEAD']),
      failureContext: 'Reading snapshot commit hash',
    );
    return head.map((value) => value.trim());
  }

  /// A killed (timed-out) git process can leave `index.lock` behind. Capture
  /// and restore are serialized per run, so any lock found here is stale.
  Future<void> _clearStaleIndexLock(String shadowDir) async {
    final lock = File(_pathContext.join(shadowDir, 'index.lock'));
    if (!lock.existsSync()) return;
    try {
      await lock.delete();
    } on FileSystemException catch (error) {
      _log.warning(
        LogEvent(
          'workspace.index_lock_delete_failed',
          fields: {'error': error.message},
        ),
      );
    }
  }

  Future<_CaptureOptions> _readOptions(String shadowDir) async {
    final file = File(_pathContext.join(shadowDir, _optionsFileName));
    if (!file.existsSync()) return const _CaptureOptions();
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is Map<String, Object?>) return _CaptureOptions.fromJson(json);
    } on FormatException {
      // Fall through to defaults.
    }
    return const _CaptureOptions();
  }

  /// Removes oversized paths from the index (they may be tracked from an
  /// earlier snapshot, where the untracked-only exclude file has no effect).
  Future<Result<void>> _unstageOversized({
    required String shadowDir,
    required String workspaceDir,
    required List<String> paths,
  }) async {
    const chunkSize = 100;
    for (var i = 0; i < paths.length; i += chunkSize) {
      final end = i + chunkSize > paths.length ? paths.length : i + chunkSize;
      final result = await _git.runChecked(
        _shadowArgs(shadowDir, workspaceDir, [
          '--literal-pathspecs',
          'rm',
          '--cached',
          '--ignore-unmatch',
          '-q',
          '--',
          ...paths.sublist(i, end),
        ]),
        timeout: GitClient.longTimeout,
        failureContext: 'Unstaging oversized files',
      );
      if (result case FailureResult<String>(:final failure)) {
        return FailureResult(failure);
      }
    }
    return const Success<void>(null);
  }

  /// Escapes [path] as an anchored gitignore entry: glob characters,
  /// backslashes and trailing spaces are literal; the leading `/` also makes
  /// a leading `#` or `!` literal.
  String _escapeExcludePath(String path) {
    final escaped = path
        .replaceAllMapped(RegExp(r'[\\\[\]*?]'), (m) => '\\${m[0]}')
        .replaceFirstMapped(
          RegExp(r' +$'),
          (m) => m[0]!.replaceAll(' ', r'\ '),
        );
    return '/$escaped';
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
      ['config', 'core.longpaths', 'true'],
      ['config', 'core.excludesFile', ''],
      ['config', 'commit.gpgsign', 'false'],
      ['config', 'core.fsmonitor', 'false'],
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
    final lsResult = await _git.run(
      _shadowArgs(shadowDir, workspaceDir, const [
        'ls-files',
        '--others',
        '--modified',
        '--exclude-standard',
        '-z',
      ]),
      timeout: GitClient.longTimeout,
    );
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

/// Exclusions and size limit applied to a capture; persisted per run so
/// restore applies the same rules.
final class _CaptureOptions {
  const new({
    this.extraExclusions = const [],
    this.maxFileSizeBytes = ShadowSnapshotService.defaultMaxFileSizeBytes,
  });

  factory fromJson(Map<String, Object?> json) {
    final exclusions = json['extraExclusions'];
    final limit = json['maxFileSizeBytes'];
    return _CaptureOptions(
      extraExclusions: exclusions is List
          ? exclusions.whereType<String>().toList()
          : const [],
      maxFileSizeBytes: limit is int ? limit : null,
    );
  }

  final List<String> extraExclusions;
  final int? maxFileSizeBytes;

  Map<String, Object?> toJson() => {
    'extraExclusions': extraExclusions,
    'maxFileSizeBytes': maxFileSizeBytes,
  };
}
