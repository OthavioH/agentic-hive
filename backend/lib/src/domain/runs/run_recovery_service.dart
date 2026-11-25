import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_attachment_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';

/// Resolved state required to resume a [Run] from its latest [Checkpoint] (or
/// from its workflow entry node if no checkpoint exists yet).
final class ResumePoint {
  /// Creates a resume point.
  const new({
    required this.run,
    required this.workflow,
    required this.latestCheckpoint,
    required this.pendingNodeIds,
    required this.attemptsByEdge,
    required this.circuitBreakerCount,
    required this.nodeOutputs,
  });

  /// The run being resumed.
  final Run run;

  /// Frozen workflow definition snapshot stored on [run].
  final Workflow workflow;

  /// Latest persisted checkpoint, or `null` if none was saved yet.
  final Checkpoint? latestCheckpoint;

  /// Node IDs ready to execute next.
  final List<String> pendingNodeIds;

  /// Retry counts per edge ID.
  final Map<String, int> attemptsByEdge;

  /// Consecutive infrastructure failure count.
  final int circuitBreakerCount;

  /// Outputs recorded by completed nodes.
  final Map<String, JsonMap> nodeOutputs;
}

/// Handles startup orphan-run recovery and checkpoint resume resolution.
final class RunRecoveryService {
  /// Creates a recovery service.
  new({
    required this._runs,
    required this._checkpoints,
    this._attachments,
    String Function()? generateId,
    DateTime Function()? now,
  }) : _generateId = generateId ?? randomId,
       _now = now ?? _utcNow;

  static final _log = Logger('run_recovery');

  static DateTime _utcNow() => DateTime.now().toUtc();

  final RunRepository _runs;
  final CheckpointRepository _checkpoints;
  final RunAttachmentStore? _attachments;
  final String Function() _generateId;
  final DateTime Function() _now;

  /// Transitions any runs left in [RunStatus.running] from a previous backend
  /// process into [RunStatus.interrupted] (appending `run.interrupted`), and
  /// any runs left in [RunStatus.cancelling] into
  /// [RunStatus.cancellationUncertain] (appending
  /// `run.cancellation_uncertain`), each in a single transaction.
  ///
  /// After recovery settles statuses, sweeps orphaned or ended run attachment
  /// folders on a best-effort basis (ADR 0030).
  ///
  /// Per-run failures are logged and skipped so one bad row does not block
  /// backend startup. Runs in [RunStatus.paused] are left untouched.
  Future<Result<int>> recoverOrphanedRuns() async {
    final runningResult = await _runs.listByStatus(RunStatus.running);
    if (runningResult case FailureResult<List<Run>>(:final failure)) {
      return FailureResult(failure);
    }
    final cancellingResult = await _runs.listByStatus(RunStatus.cancelling);
    if (cancellingResult case FailureResult<List<Run>>(:final failure)) {
      return FailureResult(failure);
    }

    var recovered = 0;
    for (final run in runningResult.valueOrNull!) {
      final recoveryResult = await _runs.markInterruptedWithEvent(
        run.id,
        eventId: _generateId(),
        createdAt: _now().toUtc(),
        payload: const {'reason': 'backend_restarted'},
      );
      if (recoveryResult case FailureResult<Run>(:final failure)) {
        _log.warning(
          LogEvent(
            'runs.orphan_recovery_failed',
            fields: {'runId': run.id, 'error': failure.message},
          ),
        );
        continue;
      }
      recovered++;
    }

    for (final run in cancellingResult.valueOrNull!) {
      final recoveryResult = await _runs.markCancellationUncertainWithEvent(
        run.id,
        eventId: _generateId(),
        createdAt: _now().toUtc(),
        payload: const {'reason': 'backend_restarted'},
      );
      if (recoveryResult case FailureResult<Run>(:final failure)) {
        _log.warning(
          LogEvent(
            'runs.cancelling_recovery_failed',
            fields: {'runId': run.id, 'error': failure.message},
          ),
        );
        continue;
      }
      recovered++;
    }

    if (recovered > 0) {
      _log.info(
        LogEvent('runs.orphaned_recovered', fields: {'count': recovered}),
      );
    }
    await _sweepAttachments();
    return Success(recovered);
  }

  Future<void> _sweepAttachments() async {
    final attachments = _attachments;
    if (attachments == null) return;

    final listResult = await attachments.listRunIds();
    if (listResult case FailureResult<List<String>>(:final failure)) {
      _log.warning(
        LogEvent(
          'runs.attachments_sweep_failed',
          fields: {'error': failure.message},
        ),
      );
      return;
    }

    final ids = listResult.valueOrNull!;
    if (ids.isEmpty) return;

    final foundResult = await _runs.getByIds(ids);
    if (foundResult case FailureResult<Map<String, Run>>(:final failure)) {
      _log.warning(
        LogEvent(
          'runs.attachments_sweep_failed',
          fields: {'error': failure.message},
        ),
      );
      return;
    }

    final found = foundResult.valueOrNull!;
    for (final id in ids) {
      final run = found[id];
      if (run == null || attachmentDeletingStatuses.contains(run.status)) {
        await attachments.deleteRunBestEffort(id);
      }
    }
  }

  /// Resolves the [ResumePoint] for [runId] using its frozen workflow
  /// definition and latest [Checkpoint].
  Future<Result<ResumePoint>> resolveResumePoint(String runId) async {
    final runResult = await _runs.getById(runId);
    if (runResult case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }
    final run = runResult.valueOrNull!;

    final checkpointResult = await _checkpoints.getLatestForRun(runId);
    if (checkpointResult case FailureResult<Checkpoint?>(:final failure)) {
      return FailureResult(failure);
    }
    final latest = checkpointResult.valueOrNull;

    final workflow = run.workflowDefinition;
    if (latest != null) {
      return Success(
        ResumePoint(
          run: run,
          workflow: workflow,
          latestCheckpoint: latest,
          pendingNodeIds: latest.pendingNodeIds,
          attemptsByEdge: latest.attemptsByEdge,
          circuitBreakerCount: latest.circuitBreakerCount,
          nodeOutputs: latest.nodeOutputs,
        ),
      );
    }

    final entryNodeId = workflow.entryNodeId;
    return Success(
      ResumePoint(
        run: run,
        workflow: workflow,
        latestCheckpoint: null,
        pendingNodeIds: entryNodeId == null
            ? const <String>[]
            : <String>[entryNodeId],
        attemptsByEdge: const <String, int>{},
        circuitBreakerCount: 0,
        nodeOutputs: const <String, JsonMap>{},
      ),
    );
  }
}
