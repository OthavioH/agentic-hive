import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/graph_engine.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_log_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/domain/settings/execution_settings_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/shadow_snapshot_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/worktree_service.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/canonical_folder.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Domain service / coordinator for starting, querying, resuming, cancelling,
/// and deleting [Run]s, [Checkpoint]s, [RunEvent]s, and node logs.
final class RunService {
  /// Creates a run service.
  new({
    required this._runs,
    required this._checkpoints,
    required this._events,
    this._snapshots,
    this._workspacePreparation,
    this._workflows,
    this._workspaceWorkflows,
    this._workflowValidator,
    this._workspaces,
    this._worktrees,
    this._executionSettings,
    this._engine,
    this._logStore,
    p.Context? pathContext,
    String Function()? generateId,
    DateTime Function()? now,
  }) : _pathContext = pathContext ?? p.context,
       _generateId = generateId ?? randomId,
       _now = now ?? _utcNow;

  /// Default page size when querying run events without an explicit limit.
  static const int defaultEventsLimit = 200;

  /// Maximum page size allowed when querying run events.
  static const int maxEventsLimit = 1000;

  static final _log = Logger('run_service');

  static DateTime _utcNow() => DateTime.now().toUtc();

  final RunRepository _runs;
  final CheckpointRepository _checkpoints;
  final RunEventRepository _events;
  final ShadowSnapshotService? _snapshots;
  final WorkspacePreparationService? _workspacePreparation;
  final WorkflowRepository? _workflows;
  final WorkspaceWorkflowRepository? _workspaceWorkflows;
  final WorkflowValidator? _workflowValidator;
  final WorkspaceService? _workspaces;
  final WorktreeService? _worktrees;
  final ExecutionSettingsService? _executionSettings;
  final GraphEngine? _engine;
  final RunLogStore? _logStore;
  final p.Context _pathContext;
  final String Function() _generateId;
  final DateTime Function() _now;

  final Map<String, Future<void>> _activeExecutions = <String, Future<void>>{};

  /// Synchronously reserved canonical target folders (the primary checkout or
  /// a worktree) for in-flight run starts/resumes before the database status
  /// is persisted. At most one run is active per folder (ADR 0022).
  final Set<String> _reservedFolders = <String>{};

  /// Synchronously claimed run IDs currently entering [resumeRun] so concurrent
  /// duplicate resume requests receive `409 Conflict`.
  final Set<String> _resumingRunIds = <String>{};

  /// Waits for any in-flight background run executions launched by [startRun]
  /// or [resumeRun] to settle.
  Future<void> waitForActiveExecutions() async {
    while (_activeExecutions.isNotEmpty) {
      await Future.wait(_activeExecutions.values.toList(growable: false));
    }
  }

  /// Cancels any active in-flight run executions and waits for them to settle
  /// before backend shutdown closes the log store and database.
  Future<void> dispose() async {
    final engine = _engine;
    if (engine != null && _activeExecutions.isNotEmpty) {
      final activeIds = _activeExecutions.keys.toList(growable: false);
      for (final runId in activeIds) {
        try {
          await engine.cancel(runId);
        } on Object {
          // Best-effort cancellation on shutdown.
        }
      }
    }
    await waitForActiveExecutions();
  }

  /// Resolves [workflowId] for a run: workspace-scoped workflows of the run's
  /// workspace first, then global ones (ADR 0022). Workspace workflow ids are
  /// file slugs and global ids are random, so a hit in either is unambiguous.
  Future<Result<Workflow>> _resolveWorkflow(
    WorkflowRepository globalWorkflows,
    String workflowId,
    String? workspaceRoot,
  ) async {
    final scoped = _workspaceWorkflows;
    if (scoped != null && workspaceRoot != null) {
      final inWorkspace = await scoped.getById(workspaceRoot, workflowId);
      if (inWorkspace is Success<Workflow>) return inWorkspace;
    }
    return await globalWorkflows.getById(workflowId);
  }

  /// Validates [request], resolves where the run executes (the primary
  /// checkout, an existing worktree or a new worktree), enforces the
  /// one-active-run-per-folder guard, creates the [Run], and starts
  /// `GraphEngine` execution asynchronously.
  Future<Result<Run>> startRun(StartRunRequest request) async {
    final workflowId = request.workflowId.trim();
    if (workflowId.isEmpty) {
      return const FailureResult(
        ValidationFailure('Field "workflowId" must not be blank.'),
      );
    }
    final workspaceId = request.workspaceId.trim();
    if (workspaceId.isEmpty) {
      return const FailureResult(
        ValidationFailure('Field "workspaceId" must not be blank.'),
      );
    }
    final workspaceService = _workspaces;
    if (workspaceService == null) {
      return const FailureResult(
        UnexpectedFailure('Workspace registry is not configured.'),
      );
    }
    final found = await workspaceService.get(workspaceId);
    if (found case FailureResult<Workspace>(:final failure)) {
      return FailureResult(failure);
    }
    final workspace = found.valueOrNull!;
    final workspacePath = workspace.rootPath;
    final workspaceRoot = workspacePath;

    final workflows = _workflows;
    final engine = _engine;
    final workspacePreparation = _workspacePreparation;
    if (workflows == null || engine == null || workspacePreparation == null) {
      return const FailureResult(
        UnexpectedFailure('Run execution dependencies are not configured.'),
      );
    }

    // No target means the primary checkout (ADR 0022).
    final target = request.target ?? const RunTarget.primary();
    var ignorePatterns = request.ignorePatterns;
    final executionSettings = _executionSettings;
    if (executionSettings != null && ignorePatterns == null) {
      final effective = await executionSettings.effectiveFor(workspace.id);
      if (effective case FailureResult<EffectiveExecutionSettings>(
        :final failure,
      )) {
        return FailureResult(failure);
      }
      ignorePatterns = effective.valueOrNull!.ignorePatterns;
    }

    String? reservedFolder;
    String? createdWorktreePath;
    String? createdWorktreeBranch;

    // Claims [folder] for this run, or reports the conflicting active run.
    Future<ConflictFailure?> claim(String folder) async {
      final key = canonicalFolder(folder, _pathContext);
      if (!_reservedFolders.add(key)) {
        return ConflictFailure(
          'An active run is already starting or executing in "$key".',
        );
      }
      reservedFolder = key;
      return await _checkFolderConflict(key);
    }

    try {
      final workflowResult = await _resolveWorkflow(
        workflows,
        workflowId,
        workspaceRoot,
      );
      if (workflowResult case FailureResult<Workflow>(:final failure)) {
        return FailureResult(failure);
      }
      final workflow = workflowResult.valueOrNull!;

      if (_workflowValidator != null) {
        final validation = _workflowValidator.validate(workflow);
        if (!validation.isValid) {
          final message = validation.issues
              .where((i) => i.severity == WorkflowValidationSeverity.error)
              .map((i) => i.message)
              .join('; ');
          return FailureResult(
            ValidationFailure(
              'Workflow "${workflow.name}" is invalid: $message',
            ),
          );
        }
      }

      final runId = _generateId();
      final PreparedWorkspace prepared;
      switch (target) {
        case RunTargetPrimary():
          final conflict = await claim(workspacePath);
          if (conflict != null) return FailureResult(conflict);
          prepared = PreparedWorkspace(
            effectiveWorkspacePath: workspacePath,
            isolationMode: WorkspaceIsolationMode.direct,
          );
        case RunTargetWorktree(:final worktreeId):
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
              .where((w) => w.id == worktreeId)
              .firstOrNull;
          if (existing == null) {
            return FailureResult(
              NotFoundFailure('Worktree "$worktreeId" was not found.'),
            );
          }
          final conflict = await claim(
            existing.isPrimary ? workspacePath : existing.path,
          );
          if (conflict != null) return FailureResult(conflict);
          prepared = existing.isPrimary
              ? PreparedWorkspace(
                  effectiveWorkspacePath: workspacePath,
                  isolationMode: WorkspaceIsolationMode.direct,
                )
              : PreparedWorkspace(
                  effectiveWorkspacePath: existing.path,
                  isolationMode: WorkspaceIsolationMode.worktree,
                  worktreePath: existing.path,
                  worktreeBranch: existing.branch,
                );
        case RunTargetNewWorktree(
          :final name,
          :final branch,
          :final baseBranch,
        ):
          final worktrees = _worktrees;
          if (worktrees == null) {
            return const FailureResult(
              UnexpectedFailure('Worktree service is not configured.'),
            );
          }
          final created = await worktrees.create(
            workspace,
            CreateWorktreeRequest(
              name: _nonBlank(name) ?? runId,
              branch: _nonBlank(branch) ?? 'hive/$runId',
              baseBranch: baseBranch,
            ),
          );
          if (created case FailureResult<Worktree>(:final failure)) {
            return FailureResult(failure);
          }
          final worktree = created.valueOrNull!;
          createdWorktreePath = worktree.path;
          createdWorktreeBranch = worktree.branch;
          final conflict = await claim(worktree.path);
          if (conflict != null) {
            await workspacePreparation.cleanupWorktree(
              workspacePath: workspacePath,
              worktreePath: worktree.path,
              branchName: worktree.branch,
            );
            return FailureResult(conflict);
          }
          prepared = PreparedWorkspace(
            effectiveWorkspacePath: worktree.path,
            isolationMode: WorkspaceIsolationMode.worktree,
            worktreePath: worktree.path,
            worktreeBranch: worktree.branch,
          );
      }

      if (ignorePatterns != null && ignorePatterns.isNotEmpty) {
        _snapshots?.configureRunExclusions(runId, ignorePatterns);
      }

      final run = Run(
        id: runId,
        workflowId: workflow.id,
        workflowName: workflow.name,
        workflowDefinition: workflow,
        workspacePath: workspacePath,
        workspaceId: workspace.id,
        status: RunStatus.running,
        startedAt: _now().toUtc(),
        isolationMode: prepared.isolationMode,
        worktreePath: prepared.worktreePath,
        worktreeBranch: prepared.worktreeBranch,
      );

      final createResult = await _runs.create(run);
      if (createResult case FailureResult<Run>(:final failure)) {
        _snapshots?.configureRunExclusions(runId, const []);
        if (createdWorktreePath != null) {
          await workspacePreparation.cleanupWorktree(
            workspacePath: workspacePath,
            worktreePath: createdWorktreePath,
            branchName: createdWorktreeBranch,
          );
        }
        return FailureResult(failure);
      }

      if (prepared.warningMessage != null) {
        await _events.append(
          id: _generateId(),
          runId: runId,
          type: RunEventType.snapshotWarning,
          payload: <String, Object?>{'message': prepared.warningMessage},
          createdAt: _now().toUtc(),
        );
      }

      _launchBackground(runId, () => engine.start(runId));
      return Success(run);
    } finally {
      final reserved = reservedFolder;
      if (reserved != null) {
        // Once the run row is persisted as `running` (or if setup failed),
        // the DB status check owns the guard after this point.
        _reservedFolders.remove(reserved);
      }
    }
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Initiates cancellation for an active run or retries cancellation for a
  /// `cancellationUncertain` run.
  Future<Result<Run>> cancelRun(String id) async {
    final engine = _engine;
    if (engine == null) {
      return const FailureResult(
        UnexpectedFailure('GraphEngine is not configured.'),
      );
    }
    return await engine.cancel(id);
  }

  /// Resumes an `interrupted` run from its latest checkpoint.
  ///
  /// Returns [ConflictFailure] (`409 Conflict`) when the run is `paused`, is
  /// already being resumed, or is in any status other than `interrupted`.
  Future<Result<Run>> resumeRun(String id) =>
      _resumeWithStatus(id, expectedStatus: RunStatus.interrupted);

  /// Resumes a `paused` run with [input] (either an [ApprovalDecisionInput]
  /// or a post-restart [HumanAnswerInput]), or queues [input] into an active
  /// execution of [id] when another paused branch of the same run was just
  /// answered.
  Future<Result<Run>> resumePausedRun(
    String id, {
    required ResumeInput input,
  }) async {
    final engine = _engine;
    if (engine == null) {
      return const FailureResult(
        UnexpectedFailure('GraphEngine is not configured.'),
      );
    }

    final runResult = await _runs.getById(id);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }
    final run = runResult.valueOrNull!;

    var reservedDirect = false;
    String? normalizedWorkspace;
    var launched = false;
    try {
      if (!engine.isExecuting(id)) {
        normalizedWorkspace = canonicalFolder(_runFolder(run), _pathContext);
        if (!_reservedFolders.add(normalizedWorkspace)) {
          return FailureResult(
            ConflictFailure(
              'An active run is already starting or executing in '
              '"$normalizedWorkspace".',
            ),
          );
        }
        reservedDirect = true;
        final conflict = await _checkFolderConflict(
          normalizedWorkspace,
          excludeRunId: id,
        );
        if (conflict != null) return FailureResult(conflict);
      }

      final started = await engine.beginPausedResume(id, input: input);
      if (started case FailureResult<({Run run, Future<Result<Run>> done})>(
        :final failure,
      )) {
        return FailureResult(failure);
      }
      final (run: resumedRun, :done) = started.valueOrNull!;
      if (!_activeExecutions.containsKey(id)) {
        launched = true;
        _launchBackground(
          id,
          () => done,
          onSettled: () {
            if (reservedDirect && normalizedWorkspace != null) {
              _reservedFolders.remove(normalizedWorkspace);
            }
          },
        );
      }
      return Success(resumedRun);
    } finally {
      if (!launched && reservedDirect && normalizedWorkspace != null) {
        _reservedFolders.remove(normalizedWorkspace);
      }
    }
  }

  Future<Result<Run>> _resumeWithStatus(
    String id, {
    required RunStatus expectedStatus,
    ResumeInput? input,
  }) async {
    final engine = _engine;
    if (engine == null) {
      return const FailureResult(
        UnexpectedFailure('GraphEngine is not configured.'),
      );
    }

    if (!_resumingRunIds.add(id) || engine.isExecuting(id)) {
      return FailureResult(
        ConflictFailure('Run "$id" is already being resumed or executed.'),
      );
    }

    var reservedDirect = false;
    String? normalizedWorkspace;
    var launched = false;
    try {
      final runResult = await _runs.getById(id);
      if (runResult case FailureResult<Run>(:final failure)) {
        return FailureResult(failure);
      }
      final run = runResult.valueOrNull!;

      if (run.status != expectedStatus) {
        return FailureResult(
          ConflictFailure(
            'Run "$id" is ${run.status.name}; only ${expectedStatus.name} '
            'runs can be resumed.',
          ),
        );
      }

      {
        normalizedWorkspace = canonicalFolder(_runFolder(run), _pathContext);
        if (!_reservedFolders.add(normalizedWorkspace)) {
          return FailureResult(
            ConflictFailure(
              'An active run is already starting or executing in '
              '"$normalizedWorkspace".',
            ),
          );
        }
        reservedDirect = true;
        final conflict = await _checkFolderConflict(
          normalizedWorkspace,
          excludeRunId: id,
        );
        if (conflict != null) return FailureResult(conflict);
      }

      launched = true;
      _launchBackground(
        id,
        () => engine.resume(id, input: input),
        onSettled: () {
          _resumingRunIds.remove(id);
          if (reservedDirect && normalizedWorkspace != null) {
            _reservedFolders.remove(normalizedWorkspace);
          }
        },
      );
      return Success(run);
    } finally {
      if (!launched) {
        _resumingRunIds.remove(id);
        if (reservedDirect && normalizedWorkspace != null) {
          _reservedFolders.remove(normalizedWorkspace);
        }
      }
    }
  }

  /// Returns stored `stdout`/`stderr` logs for `(runId, nodeId)` for [attempt]
  /// (defaulting to the latest attempt).
  Future<Result<RunNodeLogsResponse>> getNodeLogs({
    required String runId,
    required String nodeId,
    int? attempt,
    int? tail,
  }) async {
    final runResult = await _runs.getById(runId);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    final logStore = _logStore;
    if (logStore == null) {
      return Success(
        RunNodeLogsResponse(
          runId: runId,
          nodeId: nodeId,
          attempt: attempt ?? 1,
        ),
      );
    }

    return await logStore.readLogs(
      runId: runId,
      nodeId: nodeId,
      attempt: attempt,
      tailLines: tail,
    );
  }

  void _launchBackground(
    String runId,
    Future<Result<Run>> Function() task, {
    void Function()? onSettled,
  }) {
    final future = () async {
      try {
        final result = await task();
        if (result case FailureResult<Run>(:final failure)) {
          await _handleBackgroundFailure(runId, failure.message);
        }
      } on Object catch (error, stackTrace) {
        _log.severe(
          LogEvent(
            'runs.background_execution_crashed',
            fields: {'runId': runId, 'error': '$error'},
          ),
          error,
          stackTrace,
        );
        await _handleBackgroundFailure(
          runId,
          'Background run execution crashed: $error',
        );
      }
    }();
    _activeExecutions[runId] = future;
    unawaited(
      future.whenComplete(() {
        onSettled?.call();
        if (identical(_activeExecutions[runId], future)) {
          unawaited(_activeExecutions.remove(runId));
        }
      }),
    );
  }

  Future<void> _handleBackgroundFailure(String runId, String message) async {
    _log.warning(
      LogEvent(
        'runs.background_execution_failed',
        fields: {'runId': runId, 'error': message},
      ),
    );
    final currentResult = await _runs.getById(runId);
    if (currentResult case Success<Run>(:final value)
        when value.status == RunStatus.running ||
            value.status == RunStatus.paused ||
            value.status == RunStatus.interrupted) {
      final now = _now().toUtc();
      await _runs.updateStatus(
        runId,
        status: RunStatus.failed,
        finishedAt: now,
        errorMessage: message,
      );
      await _events.append(
        id: _generateId(),
        runId: runId,
        type: RunEventType.runFailed,
        createdAt: now,
        payload: <String, Object?>{'reason': message},
      );
    }
  }

  /// The folder a run executes in: its worktree, or the workspace root.
  static String _runFolder(Run run) => run.worktreePath ?? run.workspacePath;

  Future<ConflictFailure?> _checkFolderConflict(
    String normalizedFolder, {
    String? excludeRunId,
  }) async {
    for (final status in const [
      RunStatus.running,
      RunStatus.paused,
      RunStatus.cancelling,
    ]) {
      final listResult = await _runs.listByStatus(status);
      if (listResult case FailureResult<List<Run>>()) continue;
      for (final active in listResult.valueOrNull!) {
        if (active.id == excludeRunId) continue;
        if (canonicalFolder(_runFolder(active), _pathContext) ==
            normalizedFolder) {
          return ConflictFailure(
            'An active run ("${active.id}") is already executing in '
            '"$normalizedFolder".',
          );
        }
      }
    }
    return null;
  }

  /// Lists runs ordered by `startedAt DESC` with optional filters.
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit <= 0) {
      return const FailureResult(
        ValidationFailure('Query parameter "limit" must be greater than 0.'),
      );
    }
    if (offset < 0) {
      return const FailureResult(
        ValidationFailure('Query parameter "offset" must be >= 0.'),
      );
    }

    final result = await _runs.list(
      status: status,
      workflowId: workflowId,
      limit: limit,
      offset: offset,
    );
    return result.map(
      (page) => RunsListResponse(items: page.items, total: page.total),
    );
  }

  /// Fetches a single run by [id].
  Future<Result<Run>> getRun(String id) => _runs.getById(id);

  /// Lists events for [runId] ordered by `sequence ASC`.
  Future<Result<RunEventsResponse>> getRunEvents(
    String runId, {
    int? afterSequence,
    int? limit,
  }) async {
    if (afterSequence != null && afterSequence < 0) {
      return const FailureResult(
        ValidationFailure('Query parameter "afterSequence" must be >= 0.'),
      );
    }
    if (limit != null && limit <= 0) {
      return const FailureResult(
        ValidationFailure('Query parameter "limit" must be greater than 0.'),
      );
    }

    final runResult = await _runs.getById(runId);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    final effectiveLimit = (limit ?? defaultEventsLimit).clamp(
      1,
      maxEventsLimit,
    );
    final eventsResult = await _events.listForRun(
      runId,
      afterSequence: afterSequence,
      limit: effectiveLimit,
    );
    return eventsResult.map(
      (page) =>
          RunEventsResponse(items: page.items, lastSequence: page.lastSequence),
    );
  }

  /// Lists checkpoints for [runId] ordered by `sequence ASC`, or only the
  /// latest checkpoint when [latest] is true.
  Future<Result<RunCheckpointsResponse>> getRunCheckpoints(
    String runId, {
    bool latest = false,
  }) async {
    final runResult = await _runs.getById(runId);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    if (latest) {
      final latestResult = await _checkpoints.getLatestForRun(runId);
      return latestResult.map(
        (checkpoint) => RunCheckpointsResponse(
          items: checkpoint == null ? const [] : [checkpoint],
        ),
      );
    }

    final listResult = await _checkpoints.listForRun(runId);
    return listResult.map((items) => RunCheckpointsResponse(items: items));
  }

  /// Atomically deletes a non-active run [id] (cascading its checkpoints,
  /// events, and snapshots) and cleans up its shadow repository and log files.
  /// Its worktree is kept: a worktree is removed only when the user asks
  /// (ADR 0022).
  ///
  /// Returns [ConflictFailure] when the run is active (`running`, `paused`,
  /// or `cancelling`).
  Future<Result<void>> deleteRun(String id) async {
    final deleteResult = await _runs.delete(id);
    if (deleteResult case FailureResult<void>()) {
      return deleteResult;
    }

    if (_snapshots != null) {
      _snapshots.configureRunExclusions(id, const []);
      await _snapshots.deleteShadowRepository(id);
    }
    if (_logStore != null) {
      await _logStore.deleteRunLogs(id);
    }
    return deleteResult;
  }
}
