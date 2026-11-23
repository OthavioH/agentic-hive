import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/graph_engine.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_log_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/domain/workspace/shadow_snapshot_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
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
    this._workflowValidator,
    this._workspaces,
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
  final WorkflowValidator? _workflowValidator;
  final WorkspaceService? _workspaces;
  final GraphEngine? _engine;
  final RunLogStore? _logStore;
  final p.Context _pathContext;
  final String Function() _generateId;
  final DateTime Function() _now;

  final Map<String, Future<void>> _activeExecutions = <String, Future<void>>{};

  /// Synchronously reserved canonical workspace paths for in-flight `direct`
  /// run starts/resumes before the database status is persisted.
  final Set<String> _reservedDirectWorkspaces = <String>{};

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

  /// Validates [request], enforces the `direct`-mode workspace concurrency
  /// guard, creates the [Run], and starts `GraphEngine` execution
  /// asynchronously.
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
    final ownerWorkspaceId = found.valueOrNull!.id;
    final workspacePath = found.valueOrNull!.rootPath;

    final workflows = _workflows;
    final engine = _engine;
    final workspacePreparation = _workspacePreparation;
    if (workflows == null || engine == null || workspacePreparation == null) {
      return const FailureResult(
        UnexpectedFailure('Run execution dependencies are not configured.'),
      );
    }

    final requestedMode =
        request.workspaceIsolationMode ?? WorkspaceIsolationMode.worktree;
    final normalizedWorkspace = _canonicalizeWorkspace(workspacePath);
    var reservedDirect = false;
    if (requestedMode == WorkspaceIsolationMode.direct) {
      if (!_reservedDirectWorkspaces.add(normalizedWorkspace)) {
        return FailureResult(
          ConflictFailure(
            'An active direct-mode run is already starting or executing on '
            'workspace "$normalizedWorkspace".',
          ),
        );
      }
      reservedDirect = true;
    }

    var createdInDb = false;
    try {
      final workflowResult = await workflows.getById(workflowId);
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

      if (requestedMode == WorkspaceIsolationMode.direct) {
        final conflict = await _checkDirectWorkspaceConflict(
          normalizedWorkspace,
        );
        if (conflict != null) return FailureResult(conflict);
      }

      final runId = _generateId();
      final preparedResult = await workspacePreparation.prepare(
        runId: runId,
        workspacePath: workspacePath,
        requestedMode: requestedMode,
      );
      if (preparedResult case FailureResult<PreparedWorkspace>(
        :final failure,
      )) {
        return FailureResult(failure);
      }
      final prepared = preparedResult.valueOrNull!;

      if (prepared.isolationMode == WorkspaceIsolationMode.direct &&
          !reservedDirect) {
        if (!_reservedDirectWorkspaces.add(normalizedWorkspace)) {
          return FailureResult(
            ConflictFailure(
              'An active direct-mode run is already starting or executing on '
              'workspace "$normalizedWorkspace".',
            ),
          );
        }
        reservedDirect = true;
        final conflict = await _checkDirectWorkspaceConflict(
          normalizedWorkspace,
        );
        if (conflict != null) return FailureResult(conflict);
      }

      final ignorePatterns = request.ignorePatterns;
      if (ignorePatterns != null && ignorePatterns.isNotEmpty) {
        _snapshots?.configureRunExclusions(runId, ignorePatterns);
      }

      final run = Run(
        id: runId,
        workflowId: workflow.id,
        workflowName: workflow.name,
        workflowDefinition: workflow,
        workspacePath: workspacePath,
        workspaceId: ownerWorkspaceId,
        status: RunStatus.running,
        startedAt: _now().toUtc(),
        isolationMode: prepared.isolationMode,
        worktreePath: prepared.worktreePath,
        worktreeBranch: prepared.worktreeBranch,
      );

      final createResult = await _runs.create(run);
      if (createResult case FailureResult<Run>(:final failure)) {
        _snapshots?.configureRunExclusions(runId, const []);
        if (prepared.isolationMode == WorkspaceIsolationMode.worktree &&
            prepared.worktreePath != null) {
          await workspacePreparation.cleanupWorktree(
            workspacePath: workspacePath,
            worktreePath: prepared.worktreePath!,
            branchName: prepared.worktreeBranch,
          );
        }
        return FailureResult(failure);
      }
      createdInDb = true;

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
      if (reservedDirect) {
        // Once the run row is persisted as `running` (or if setup failed),
        // the DB status check owns the guard after this point.
        _reservedDirectWorkspaces.remove(normalizedWorkspace);
      }
      if (!createdInDb) {
        // Nothing persisted.
      }
    }
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
      if (run.isolationMode == WorkspaceIsolationMode.direct &&
          !engine.isExecuting(id)) {
        normalizedWorkspace = _canonicalizeWorkspace(run.workspacePath);
        if (!_reservedDirectWorkspaces.add(normalizedWorkspace)) {
          return FailureResult(
            ConflictFailure(
              'An active direct-mode run is already starting or executing on '
              'workspace "$normalizedWorkspace".',
            ),
          );
        }
        reservedDirect = true;
        final conflict = await _checkDirectWorkspaceConflict(
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
              _reservedDirectWorkspaces.remove(normalizedWorkspace);
            }
          },
        );
      }
      return Success(resumedRun);
    } finally {
      if (!launched && reservedDirect && normalizedWorkspace != null) {
        _reservedDirectWorkspaces.remove(normalizedWorkspace);
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

      if (run.isolationMode == WorkspaceIsolationMode.direct) {
        normalizedWorkspace = _canonicalizeWorkspace(run.workspacePath);
        if (!_reservedDirectWorkspaces.add(normalizedWorkspace)) {
          return FailureResult(
            ConflictFailure(
              'An active direct-mode run is already starting or executing on '
              'workspace "$normalizedWorkspace".',
            ),
          );
        }
        reservedDirect = true;
        final conflict = await _checkDirectWorkspaceConflict(
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
            _reservedDirectWorkspaces.remove(normalizedWorkspace);
          }
        },
      );
      return Success(run);
    } finally {
      if (!launched) {
        _resumingRunIds.remove(id);
        if (reservedDirect && normalizedWorkspace != null) {
          _reservedDirectWorkspaces.remove(normalizedWorkspace);
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

  String _canonicalizeWorkspace(String workspacePath) {
    try {
      final dir = Directory(workspacePath);
      if (dir.existsSync()) {
        return _pathContext.canonicalize(dir.resolveSymbolicLinksSync());
      }
    } on FileSystemException {
      // Fall back to path canonicalization below.
    }
    return _pathContext.canonicalize(workspacePath);
  }

  Future<ConflictFailure?> _checkDirectWorkspaceConflict(
    String normalizedWorkspace, {
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
        if (active.isolationMode != WorkspaceIsolationMode.direct) continue;
        if (_canonicalizeWorkspace(active.workspacePath) ==
            normalizedWorkspace) {
          return ConflictFailure(
            'An active direct-mode run ("${active.id}") is already executing '
            'on workspace "$normalizedWorkspace".',
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
  /// events, and snapshots) and cleans up its shadow repository, log files,
  /// and any associated worktree.
  ///
  /// Returns [ConflictFailure] when the run is active (`running`, `paused`,
  /// or `cancelling`).
  Future<Result<void>> deleteRun(String id) async {
    final existingResult = await _runs.getById(id);
    final existing = switch (existingResult) {
      Success<Run>(:final value) => value,
      FailureResult<Run>() => null,
    };

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
    if (existing != null &&
        _workspacePreparation != null &&
        existing.isolationMode == WorkspaceIsolationMode.worktree &&
        existing.worktreePath != null) {
      await _workspacePreparation.cleanupWorktree(
        workspacePath: existing.workspacePath,
        worktreePath: existing.worktreePath!,
        branchName: existing.worktreeBranch,
      );
    }

    return deleteResult;
  }
}
