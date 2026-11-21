import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
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
    required this._events,
    String Function()? generateId,
    DateTime Function()? now,
  }) : _generateId = generateId ?? randomId,
       _now = now ?? _utcNow;

  static final _log = Logger('run_recovery');

  static DateTime _utcNow() => DateTime.now().toUtc();

  final RunRepository _runs;
  final CheckpointRepository _checkpoints;
  final RunEventRepository _events;
  final String Function() _generateId;
  final DateTime Function() _now;

  /// Transitions any runs left in [RunStatus.running] from a previous backend
  /// process into [RunStatus.interrupted] and appends a `run.interrupted`
  /// event for each.
  ///
  /// Runs in [RunStatus.paused] are left untouched.
  Future<Result<int>> recoverOrphanedRuns() async {
    final runningResult = await _runs.listByStatus(RunStatus.running);
    if (runningResult case FailureResult<List<Run>>(:final failure)) {
      return FailureResult(failure);
    }

    final orphaned = runningResult.valueOrNull!;
    var recovered = 0;
    for (final run in orphaned) {
      final updateResult = await _runs.updateStatus(
        run.id,
        status: RunStatus.interrupted,
      );
      if (updateResult case FailureResult<Run>(:final failure)) {
        return FailureResult(failure);
      }

      final eventResult = await _events.append(
        id: _generateId(),
        runId: run.id,
        type: RunEventType.runInterrupted,
        payload: const {'reason': 'backend_restarted'},
        createdAt: _now().toUtc(),
      );
      if (eventResult case FailureResult<RunEvent>(:final failure)) {
        return FailureResult(failure);
      }
      recovered++;
    }

    if (recovered > 0) {
      _log.info(
        LogEvent('runs.orphaned_recovered', fields: {'count': recovered}),
      );
    }
    return Success(recovered);
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
