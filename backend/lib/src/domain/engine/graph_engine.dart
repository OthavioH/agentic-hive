import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/engine/workflow_graph.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_attachment_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_canceller.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_log_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_recovery_service.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/snapshot_service.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';

const int _maxSummaryLength = 500;

/// A node that stopped the run until a human answers.
final class _PausedNode {
  const new({
    required this.nodeId,
    required this.kind,
    this.question,
    this.options = const <String>[],
    this.pauseId,
    this.live = false,
    this.proposalNodeId,
    this.proposal,
    this.proposalSchema,
  });

  /// Decodes a paused node from a `run.paused` event payload, accepting both
  /// the canonical [PauseKind] wire names and the legacy `'approval'` wire
  /// name written by F6–F10 checkpoints/events.
  factory fromJson(Object? json) {
    final map = json! as Map<Object?, Object?>;
    return _PausedNode(
      nodeId: map['nodeId']! as String,
      kind: PauseKind.fromName(map['kind']! as String),
      question: map['question'] as String?,
      options: (map['options'] as List<Object?>?)?.cast<String>() ?? const [],
      pauseId: map['pauseId'] as String?,
      live: map['live'] == true,
    );
  }

  final String nodeId;
  final PauseKind kind;
  final String? question;
  final String? proposalNodeId;
  final Object? proposal;
  final String? proposalSchema;
  final List<String> options;

  /// Id of the pending gateway request of a live `ask_human` pause.
  final String? pauseId;

  /// Whether the harness is still alive, waiting on the gateway (ADR 0019).
  final bool live;

  JsonMap toJson() => <String, Object?>{
    'nodeId': nodeId,
    'kind': kind.name,
    if (question != null) 'question': question,
    if (pauseId != null) 'pauseId': pauseId,
    if (live) 'live': true,
  };
}

final class _NodeCompletion {
  const new(this.nodeId, this.result);

  final String nodeId;
  final Result<NodeOutcome> result;
}

final class _ActiveNode {
  new({required this.nodeId, required this.attempt});

  final String nodeId;
  final int attempt;

  /// Assigned right after the node is registered as running, because a node
  /// can raise an `ask_human` request synchronously while it starts.
  late final Future<_NodeCompletion> future;
}

/// In-memory state of one run while the engine drives it. Nothing here
/// survives a pause: the checkpoint is the durable copy (ADR 0007).
final class _RunExecution {
  new({
    required this.run,
    required this.graph,
    required this.pending,
    required this.attemptsByEdge,
    required this.circuitBreakerCount,
    required this.nodeOutputs,
  });

  Run run;
  final WorkflowGraph graph;
  final List<String> pending;
  final Map<String, int> attemptsByEdge;
  int circuitBreakerCount;
  final Map<String, JsonMap> nodeOutputs;

  final Map<String, _ActiveNode> running = <String, _ActiveNode>{};

  /// Nodes paused by a checkpoint (ADR 0007): they are not running.
  final Map<String, _PausedNode> paused = <String, _PausedNode>{};

  /// Nodes whose harness is alive and waits for a human on the gateway
  /// (ADR 0019): they are still in [running].
  final Map<String, _PausedNode> livePaused = <String, _PausedNode>{};

  /// Gateway signals queued for the loop: `(request, answered)`.
  final List<(HumanPauseRequest, bool)> signals = <(HumanPauseRequest, bool)>[];

  /// Outputs of the predecessors that led to a pending node in its current
  /// traversal, so loops never see a previous iteration's outcome.
  final Map<String, Map<String, JsonMap>> traversals =
      <String, Map<String, JsonMap>>{};

  /// Whether the persisted status is `paused` while the engine still drives
  /// the run (live `ask_human` pause).
  bool statusPaused = false;

  final Map<String, int> executionsByNode = <String, int>{};

  /// Outcomes already decided by a human on resume; the node is not re-run.
  final Map<String, NodeOutcome> resolved = <String, NodeOutcome>{};

  /// Answers to inject into the next execution of an `ask_human` node.
  final Map<String, String> humanAnswers = <String, String>{};

  /// Post-restart `ask_human` answers that arrived while another node of this
  /// run was executing; activated (with snapshot rollback check) once running
  /// nodes drain.
  final List<HumanAnswerInput> queuedResumes = <HumanAnswerInput>[];

  /// Set synchronously when `_loop` exits so late resume inputs wait for the
  /// finishing checkpoint/status write instead of attaching to a closing loop.
  bool finishing = false;

  Completer<void> _wake = Completer<void>();

  /// Completes with the outcome of the pending `cancel` call(s).
  Completer<Result<Run>>? cancelCompleter;
  bool cancelRequested = false;
  String? failReason;

  /// Future that completes when the loop must look at new input.
  Future<void> get wakeFuture => _wake.future;

  /// Wakes the loop.
  void wakeUp() {
    if (!_wake.isCompleted) _wake.complete();
  }

  /// Re-arms the wake signal after the loop handled it.
  void resetWake() => _wake = Completer<void>();
}

/// Marker returned by the wait loop when it was woken without a completion.
final class _WakeUp {
  const new();
}

/// Executes a frozen workflow from its entry node to a terminal state, a
/// pause, or a cancellation (ADR 0001, 0003, 0004, 0006, 0007).
///
/// The engine talks to nodes only through `Node.execute`; it never inspects a
/// concrete node type and never assumes the workspace is code. Everything it
/// persists goes through the run, checkpoint and event repositories, and every
/// fallible call returns a `Result` (ADR 0017).
///
/// **Retries.** `WorkflowEdge.maxRetries` is the number of *allowed retries*
/// of that edge. Each traversal first checks whether the edge's counter in
/// `attemptsByEdge` has reached
/// `maxRetries` (the run fails, the edge is not traversed) and only then
/// increments the counter and emits `node.retried`. So `maxRetries: 2` lets
/// the edge be traversed twice and fails the run on the third attempt.
///
/// **Pauses.** A `human_approval` pause persists a checkpoint and releases
/// the run from memory (ADR 0007); `resume` resolves it directly. An
/// `ask_human` pause keeps the harness alive (ADR 0019): the engine marks the
/// run `paused`, never terminates the harness, and moves the run back to
/// `running` when the gateway reports the answer. Only after a backend restart
/// does `resume` with a `HumanAnswerInput` re-run the node.
final class GraphEngine implements RunCanceller {
  /// Creates a graph engine.
  ///
  /// [maxConcurrency] bounds how many nodes of one run execute at once.
  /// [circuitBreakerThreshold] is the number of consecutive infrastructure
  /// failures that fails the run. [cancelGracePeriod] bounds how long the
  /// engine waits for killed nodes to return after the process tree exited.
  new({
    required this._registry,
    required this._runs,
    required this._checkpoints,
    required this._events,
    required this._recovery,
    required this._snapshots,
    required this._pauseGateway,
    required this._processTreeKiller,
    this._pauses,
    this._logStore,
    this._attachments,
    this.maxConcurrency = defaultMaxConcurrency,
    this.circuitBreakerThreshold = defaultCircuitBreakerThreshold,
    this.cancelGracePeriod = const Duration(seconds: 10),
    String Function()? generateId,
    DateTime Function()? now,
  }) : _generateId = generateId ?? randomId,
       _now = now ?? _utcNow,
       assert(maxConcurrency >= 1, 'maxConcurrency must be at least 1'),
       assert(
         circuitBreakerThreshold >= 1,
         'circuitBreakerThreshold must be at least 1',
       );

  /// Default number of nodes of one run that may execute concurrently.
  static const int defaultMaxConcurrency = 4;

  /// Default number of consecutive infrastructure failures that trips the
  /// circuit breaker.
  static const int defaultCircuitBreakerThreshold = 3;

  static final _log = Logger('graph_engine');

  static DateTime _utcNow() => DateTime.now().toUtc();

  final NodeRegistry _registry;
  final RunRepository _runs;
  final CheckpointRepository _checkpoints;
  final RunEventRepository _events;
  final RunRecoveryService _recovery;
  final SnapshotService _snapshots;
  final HumanPauseGateway _pauseGateway;
  final ProcessTreeKiller _processTreeKiller;
  final PauseRepository? _pauses;
  final RunLogStore? _logStore;
  final RunAttachmentStore? _attachments;
  final String Function() _generateId;
  final DateTime Function() _now;

  /// Maximum number of nodes of one run executing at once.
  final int maxConcurrency;

  /// Consecutive infrastructure failures that trip the circuit breaker.
  final int circuitBreakerThreshold;

  /// How long to wait for killed nodes to return before abandoning them.
  final Duration cancelGracePeriod;

  final Set<String> _claimed = <String>{};
  final Map<String, _RunExecution> _active = <String, _RunExecution>{};
  final Map<String, Future<Result<Run>>> _activeFutures =
      <String, Future<Result<Run>>>{};
  final Map<String, Future<void>> _prepareLocks = <String, Future<void>>{};

  /// `cancel` calls that arrived while `start`/`resume` was still preparing
  /// the run; honoured as soon as the run is driven.
  final Map<String, Completer<Result<Run>>> _earlyCancels =
      <String, Completer<Result<Run>>>{};

  /// Whether the engine is currently driving [runId] in this process.
  bool isExecuting(String runId) => _claimed.contains(runId);

  /// Whether [runId] is currently stopping (failing or cancelling).
  bool isStopping(String runId) {
    final x = _active[runId];
    return x != null && (x.finishing || x.cancelRequested);
  }

  /// Starts the `running` run [runId] at its workflow's entry node and drives
  /// it until it succeeds, fails, is cancelled, or pauses.
  ///
  /// The returned future completes with the run in its final persisted state.
  Future<Result<Run>> start(String runId) => _exclusive(runId, () async {
    final pointResult = await _recovery.resolveResumePoint(runId);
    if (pointResult case FailureResult<ResumePoint>(:final failure)) {
      return FailureResult(failure);
    }
    final point = pointResult.valueOrNull!;

    if (point.run.status != RunStatus.running) {
      return FailureResult(
        ConflictFailure(
          'Run "$runId" is ${point.run.status.name}; only a running run '
          'can be started.',
        ),
      );
    }
    if (point.latestCheckpoint != null) {
      return FailureResult(
        ConflictFailure('Run "$runId" already started; resume it instead.'),
      );
    }

    final x = _newExecution(point, circuitBreakerCount: 0);
    await _emit(runId, RunEventType.runStarted);
    if (point.workflow.entryNodeId == null) {
      x.failReason = 'The workflow has no entry node.';
    }
    return await _drive(x);
  });

  /// Resumes the `paused` or `interrupted` run [runId] that no live engine
  /// drives (a run waiting on a live `ask_human` is answered through the
  /// `HumanPauseGateway`, ADR 0019).
  ///
  /// A `paused` run needs [input] for one paused node: an
  /// [ApprovalDecisionInput] resolves a `human_approval` node directly, a
  /// [HumanAnswerInput] re-runs the node that asked with the answer injected
  /// (the restart path of ADR 0019). Other paused nodes stay paused without
  /// being executed again and need their own `resume`. Resuming a `paused`
  /// run keeps `attemptsByEdge` and the circuit breaker count.
  ///
  /// Resuming an `interrupted` run rolls the workspace back before the
  /// interrupted nodes (skipped, with a `snapshot.warning`, when a completed
  /// node's work would be erased), resets the circuit breaker to `0` and
  /// keeps `attemptsByEdge`. [input] is not needed then.
  Future<Result<Run>> resume(String runId, {ResumeInput? input}) =>
      _exclusive(runId, () async {
        final pointResult = await _recovery.resolveResumePoint(runId);
        if (pointResult case FailureResult<ResumePoint>(:final failure)) {
          return FailureResult(failure);
        }
        final point = pointResult.valueOrNull!;
        final status = point.run.status;

        final _RunExecution x;
        switch (status) {
          case RunStatus.paused:
            final prepared = await _preparePausedResume(point, input);
            if (prepared case FailureResult<_RunExecution>(:final failure)) {
              return FailureResult(failure);
            }
            x = prepared.valueOrNull!;
          case RunStatus.interrupted:
            final prepared = await _prepareInterruptedResume(point);
            if (prepared case FailureResult<_RunExecution>(:final failure)) {
              return FailureResult(failure);
            }
            x = prepared.valueOrNull!;
          case RunStatus.running ||
              RunStatus.cancelling ||
              RunStatus.cancellationUncertain ||
              RunStatus.succeeded ||
              RunStatus.failed ||
              RunStatus.cancelled:
            return FailureResult(
              ConflictFailure(
                'Run "$runId" is ${status.name}; only a paused or '
                'interrupted run can be resumed.',
              ),
            );
        }

        final updated = await _runs.updateStatus(
          runId,
          status: RunStatus.running,
        );
        if (updated case FailureResult<Run>(:final failure)) {
          return FailureResult(failure);
        }
        x.run = updated.valueOrNull!;
        await _emit(
          runId,
          RunEventType.runResumed,
          payload: <String, Object?>{
            'from': status.name,
            if (input?.nodeId != null) 'nodeId': input!.nodeId,
          },
        );
        return await _drive(x);
      });

  /// Prepares a paused run resume (or applies [input] to an already-active
  /// execution of [runId] when another paused branch was just answered) and
  /// returns the updated [Run] plus the `done` future for the execution pass.
  ///
  /// Any preparation or pre-node snapshot rollback failure is returned before
  /// the run transitions to `running` or the background loop starts, so callers
  /// only mark the pause `answered` once this handoff succeeds.
  Future<Result<({Run run, Future<Result<Run>> done})>> beginPausedResume(
    String runId, {
    required ResumeInput input,
  }) => _withPrepareLock(runId, () async {
    final active = _active[runId];
    if (active != null && !active.finishing) {
      final applied = _applyLiveResumeInput(active, input);
      if (applied case FailureResult<void>(:final failure)) {
        return FailureResult(failure);
      }
      final existingFuture = _activeFutures[runId];
      if (existingFuture != null) {
        return Success((run: active.run, done: existingFuture));
      }
    }
    if (active != null && active.finishing) {
      final existingFuture = _activeFutures[runId];
      if (existingFuture != null) {
        await existingFuture;
      }
    }

    if (!_claim(runId)) {
      return FailureResult(
        ConflictFailure('Run "$runId" is already being executed or changed.'),
      );
    }
    try {
      final pointResult = await _recovery.resolveResumePoint(runId);
      if (pointResult case FailureResult<ResumePoint>(:final failure)) {
        _claimed.remove(runId);
        return FailureResult(failure);
      }
      final point = pointResult.valueOrNull!;
      if (point.run.status != RunStatus.paused) {
        _claimed.remove(runId);
        return FailureResult(
          ConflictFailure(
            'Run "$runId" is ${point.run.status.name}; only a paused run '
            'can be resumed with human input.',
          ),
        );
      }

      final prepared = await _preparePausedResume(point, input);
      if (prepared case FailureResult<_RunExecution>(:final failure)) {
        _claimed.remove(runId);
        return FailureResult(failure);
      }
      final x = prepared.valueOrNull!;

      final updated = await _runs.updateStatus(
        runId,
        status: RunStatus.running,
      );
      if (updated case FailureResult<Run>(:final failure)) {
        _claimed.remove(runId);
        return FailureResult(failure);
      }
      x.run = updated.valueOrNull!;
      await _emit(
        runId,
        RunEventType.runResumed,
        payload: <String, Object?>{
          'from': RunStatus.paused.name,
          if (input.nodeId != null) 'nodeId': input.nodeId,
        },
      );

      _active[runId] = x;
      final done = _driveClaimed(x);
      _activeFutures[runId] = done;
      return Success((run: x.run, done: done));
    } on Object {
      _claimed.remove(runId);
      rethrow;
    }
  });

  Future<T> _withPrepareLock<T>(
    String runId,
    Future<T> Function() action,
  ) async {
    while (_prepareLocks.containsKey(runId)) {
      await _prepareLocks[runId];
    }
    final completer = Completer<void>();
    _prepareLocks[runId] = completer.future;
    try {
      return await action();
    } finally {
      unawaited(_prepareLocks.remove(runId));
      completer.complete();
    }
  }

  Future<Result<Run>> _driveClaimed(_RunExecution x) async {
    final runId = x.run.id;
    Result<Run> result;
    try {
      result = await _drive(x);
    } finally {
      unawaited(_activeFutures.remove(runId));
      _claimed.remove(runId);
    }
    final queued = _earlyCancels.remove(runId);
    if (queued == null) return result;

    final settled = await _settleQueuedCancel(runId, result);
    queued.complete(settled);
    return result;
  }

  Result<void> _applyLiveResumeInput(_RunExecution x, ResumeInput input) {
    if (x.paused.isEmpty) {
      return const FailureResult(
        ValidationFailure('The run has no paused node to resume.'),
      );
    }
    final targetId =
        input.nodeId ?? (x.paused.length == 1 ? x.paused.keys.single : null);
    final target = targetId == null ? null : x.paused[targetId];
    if (target == null) {
      return FailureResult(
        ValidationFailure(
          targetId == null
              ? 'Several nodes are paused; name the node to resume.'
              : 'Node "$targetId" is not paused.',
        ),
      );
    }

    switch ((target.kind, input)) {
      case (PauseKind.humanApproval, final ApprovalDecisionInput approval):
        x.paused.remove(target.nodeId);
        x.resolved[target.nodeId] = approval.toOutcome();
        x.wakeUp();
        return const Success(null);
      case (PauseKind.askHuman, HumanAnswerInput(:final answer)):
        if (answer.trim().isEmpty) {
          return const FailureResult(
            ValidationFailure('The human answer must not be blank.'),
          );
        }
        x.paused.remove(target.nodeId);
        x.queuedResumes.add(
          HumanAnswerInput(nodeId: target.nodeId, answer: answer),
        );
        x.wakeUp();
        return const Success(null);
      case (PauseKind.humanApproval, _) || (PauseKind.askHuman, _):
        return FailureResult(
          ValidationFailure(
            'Node "${target.nodeId}" is waiting for '
            '${_waitingFor(target.kind)}.',
          ),
        );
    }
  }

  /// Cancels [runId].
  ///
  /// A run executing in this process transitions to [RunStatus.cancelling]
  /// (`run.cancelling`), aborts its active nodes, and reports `run.cancelled`
  /// only after the [ProcessTreeKiller] confirms that every process tree has
  /// exited and all active node futures have settled within
  /// [cancelGracePeriod]. When exit cannot be confirmed, the run transitions
  /// to [RunStatus.cancellationUncertain] (`run.cancellation_uncertain`) and
  /// `cancel` can be called again to retry the kill.
  ///
  /// A `cancel` that arrives while `start` or `resume` is still preparing the
  /// run is queued and applied as soon as the run is driven. A `paused` (or
  /// `interrupted`) run that no engine drives transitions to `cancelled`
  /// immediately.
  ///
  /// When the run reaches `succeeded` or `failed` before the cancellation took
  /// effect, the call returns a [ConflictFailure] naming that status instead
  /// of a misleading success.
  @override
  Future<Result<Run>> cancel(String runId) async {
    final executing = _active[runId];
    if (executing != null) {
      executing.cancelRequested = true;
      final waiter = executing.cancelCompleter ??= Completer<Result<Run>>();
      executing.wakeUp();
      return await waiter.future;
    }
    if (_claimed.contains(runId)) {
      return await (_earlyCancels[runId] ??= Completer<Result<Run>>()).future;
    }
    return await _exclusive(runId, () async {
      final runResult = await _runs.getById(runId);
      if (runResult case FailureResult<Run>(:final failure)) {
        return FailureResult(failure);
      }
      final run = runResult.valueOrNull!;
      switch (run.status) {
        case RunStatus.paused || RunStatus.interrupted:
          final childrenStopped = await _cancelChildRuns(runId);
          if (childrenStopped case FailureResult<void>(:final failure)) {
            return await _finishTerminal(
              runId,
              status: RunStatus.cancellationUncertain,
              eventType: RunEventType.runCancellationUncertain,
              payload: <String, Object?>{
                'from': run.status.name,
                'error': failure.message,
              },
              errorMessage:
                  'Could not confirm that all processes exited: '
                  '${failure.message}',
            );
          }
          _pauseGateway.cancelRun(runId);
          await _pauses?.cancelPendingForRun(runId, cancelledAt: _now());
          return await _finishTerminal(
            runId,
            status: RunStatus.cancelled,
            eventType: RunEventType.runCancelled,
            payload: <String, Object?>{'from': run.status.name},
          );
        case RunStatus.cancellationUncertain:
          return await _retryCancel(runId);
        case RunStatus.running || RunStatus.cancelling:
          return FailureResult(
            ConflictFailure(
              'Run "$runId" is marked ${run.status.name} but is not executing '
              'in this backend; wait for recovery.',
            ),
          );
        case RunStatus.succeeded || RunStatus.failed || RunStatus.cancelled:
          return FailureResult(
            ConflictFailure('Run "$runId" is already ${run.status.name}.'),
          );
      }
    });
  }

  /// Runs [body] while holding the claim on [runId], then settles any
  /// `cancel` that was queued during [body] but never reached the loop.
  Future<Result<Run>> _exclusive(
    String runId,
    Future<Result<Run>> Function() body,
  ) async {
    if (!_claim(runId)) return _alreadyExecuting(runId);
    Result<Run> result;
    try {
      result = await body();
    } finally {
      _claimed.remove(runId);
    }
    final queued = _earlyCancels.remove(runId);
    if (queued == null) return result;

    final settled = await _settleQueuedCancel(runId, result);
    queued.complete(settled);
    return result;
  }

  Future<Result<Run>> _settleQueuedCancel(
    String runId,
    Result<Run> result,
  ) async {
    switch (result) {
      case FailureResult<Run>():
        return result;
      case Success<Run>(:final value):
        if (value.status == RunStatus.cancelled ||
            value.status == RunStatus.cancellationUncertain) {
          return result;
        }
        if (value.status == RunStatus.paused ||
            value.status == RunStatus.interrupted) {
          return await cancel(runId);
        }
        return FailureResult(
          ConflictFailure(
            'Run "$runId" finished as ${value.status.name} before the '
            'cancellation took effect.',
          ),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Setup and resume preparation
  // ---------------------------------------------------------------------------

  bool _claim(String runId) => _claimed.add(runId);

  Result<Run> _alreadyExecuting(String runId) => FailureResult(
    ConflictFailure('Run "$runId" is already being executed or changed.'),
  );

  _RunExecution _newExecution(
    ResumePoint point, {
    required int circuitBreakerCount,
  }) => _RunExecution(
    run: point.run,
    graph: WorkflowGraph(point.workflow),
    pending: point.pendingNodeIds.toSet().toList(),
    attemptsByEdge: Map<String, int>.of(point.attemptsByEdge),
    circuitBreakerCount: circuitBreakerCount,
    nodeOutputs: Map<String, JsonMap>.of(point.nodeOutputs),
  );

  Future<Result<_RunExecution>> _preparePausedResume(
    ResumePoint point,
    ResumeInput? input,
  ) async {
    final pausedResult = await _loadPausedNodes(point.run.id);
    if (pausedResult case FailureResult<List<_PausedNode>>(:final failure)) {
      return FailureResult(failure);
    }
    final pausedNodes = pausedResult.valueOrNull!;
    final x = _newExecution(
      point,
      circuitBreakerCount: point.circuitBreakerCount,
    );

    if (pausedNodes.isEmpty) {
      if (input != null) {
        return const FailureResult(
          ValidationFailure('The run has no paused node to resume.'),
        );
      }
      return Success(x);
    }
    if (input == null) {
      return const FailureResult(
        ValidationFailure('A human decision or answer is required to resume.'),
      );
    }

    final targetId =
        input.nodeId ??
        (pausedNodes.length == 1 ? pausedNodes.single.nodeId : null);
    final target = pausedNodes.where((n) => n.nodeId == targetId).firstOrNull;
    if (target == null) {
      return FailureResult(
        ValidationFailure(
          targetId == null
              ? 'Several nodes are paused; name the node to resume.'
              : 'Node "$targetId" is not paused.',
        ),
      );
    }

    // Every other paused node keeps waiting for its own human; it is not
    // executed again.
    for (final other in pausedNodes) {
      if (other.nodeId != target.nodeId) x.paused[other.nodeId] = other;
    }

    switch ((target.kind, input)) {
      case (PauseKind.humanApproval, ApprovalDecisionInput()):
        final approval = input as ApprovalDecisionInput;
        x.resolved[target.nodeId] = approval.toOutcome();
      case (PauseKind.askHuman, HumanAnswerInput(:final answer)):
        if (answer.trim().isEmpty) {
          return const FailureResult(
            ValidationFailure('The human answer must not be blank.'),
          );
        }
        x.humanAnswers[target.nodeId] = answer;
        final rollback = await _rollbackBefore(point.run.id, <String>{
          target.nodeId,
        });
        if (rollback case FailureResult<void>(:final failure)) {
          return FailureResult(failure);
        }
      case (PauseKind.humanApproval, _) || (PauseKind.askHuman, _):
        return FailureResult(
          ValidationFailure(
            'Node "${target.nodeId}" is waiting for '
            '${_waitingFor(target.kind)}.',
          ),
        );
    }
    return Success(x);
  }

  String _waitingFor(PauseKind kind) => switch (kind) {
    PauseKind.humanApproval => 'an approval decision',
    PauseKind.askHuman => 'a human answer',
  };

  Future<Result<_RunExecution>> _prepareInterruptedResume(
    ResumePoint point,
  ) async {
    final rollbackNodeIds = <String>{};
    final nodesById = {
      for (final node in point.run.workflowDefinition.nodes) node.id: node,
    };
    for (final nodeId in point.pendingNodeIds) {
      if (nodesById[nodeId]?.type == NodeTypeId.fanOut) {
        final children = await _runs.listChildren(
          point.run.id,
          parentNodeId: nodeId,
        );
        if (children case FailureResult<List<Run>>(:final failure)) {
          return FailureResult(failure);
        }
        final hasLentChildren = children.valueOrNull!.any(
          (c) => c.isolationMode == WorkspaceIsolationMode.direct,
        );
        if (hasLentChildren) continue;
      }
      rollbackNodeIds.add(nodeId);
    }

    if (rollbackNodeIds.isNotEmpty) {
      final rollback = await _rollbackBefore(point.run.id, rollbackNodeIds);
      if (rollback case FailureResult<void>(:final failure)) {
        return FailureResult(failure);
      }
    }
    return Success(_newExecution(point, circuitBreakerCount: 0));
  }

  /// Rolls the workspace back to the state before the interrupted [nodeIds]
  /// started (ADR 0004, ADR 0007).
  ///
  /// Every node of one run shares a single workspace, so a snapshot is only
  /// restorable when no node outside [nodeIds] completed after it was taken:
  /// restoring would erase that node's work. Per node the latest pre-node
  /// snapshot is considered; among the restorable ones the earliest wins. When
  /// none is restorable the rollback is skipped and a `snapshot.warning`
  /// event says so. Does nothing when no node of [nodeIds] was snapshotted.
  Future<Result<void>> _rollbackBefore(
    String runId,
    Set<String> nodeIds,
  ) async {
    final listed = await _snapshots.listSnapshots(runId);
    if (listed case FailureResult<RunSnapshotsResponse>(:final failure)) {
      return FailureResult(failure);
    }
    final checkpoints = await _checkpoints.listForRun(runId);
    if (checkpoints case FailureResult<List<Checkpoint>>(:final failure)) {
      return FailureResult(failure);
    }

    final latestByNode = <String, Snapshot>{};
    for (final snapshot in listed.valueOrNull!.items) {
      final nodeId = snapshot.nodeId;
      if (snapshot.kind == SnapshotKind.preNode &&
          nodeId != null &&
          nodeIds.contains(nodeId)) {
        latestByNode[nodeId] = snapshot;
      }
    }
    if (latestByNode.isEmpty) return const Success(null);

    final completions = checkpoints.valueOrNull!
        .where(
          (c) =>
              c.completedNodeId != null && !nodeIds.contains(c.completedNodeId),
        )
        .toList(growable: false);
    final restorable = latestByNode.values
        .where(
          (snapshot) => !completions.any(
            (c) => !c.createdAt.isBefore(snapshot.createdAt),
          ),
        )
        .toList(growable: false);

    if (restorable.isEmpty) {
      await _emit(
        runId,
        RunEventType.snapshotWarning,
        payload: <String, Object?>{
          'reason': 'rollback_skipped',
          'nodeIds': nodeIds.toList(growable: false),
          'message':
              'Another node completed after the snapshot of the interrupted '
              'node; restoring it would erase that work.',
        },
      );
      return const Success(null);
    }

    final chosen = restorable.reduce(
      (a, b) => b.createdAt.isBefore(a.createdAt) ? b : a,
    );
    final restored = await _snapshots.restoreSnapshot(runId, chosen.id);
    return restored.map((_) {});
  }

  Future<Result<List<_PausedNode>>> _loadPausedNodes(String runId) async {
    RunEvent? lastPaused;
    int? after;
    while (true) {
      final page = await _events.listForRun(runId, afterSequence: after);
      if (page case FailureResult<({List<RunEvent> items, int lastSequence})>(
        :final failure,
      )) {
        return FailureResult(failure);
      }
      final value = page.valueOrNull!;
      if (value.items.isEmpty) break;
      for (final event in value.items) {
        if (event.type == RunEventType.runPaused) lastPaused = event;
      }
      after = value.lastSequence;
    }
    final raw = lastPaused?.payload['pausedNodes'];
    if (raw is List<Object?>) {
      return Success(raw.map(_PausedNode.fromJson).toList(growable: false));
    }
    final pausesRepo = _pauses;
    if (pausesRepo != null) {
      final pendingResult = await pausesRepo.listPendingForRun(runId);
      if (pendingResult case FailureResult<List<Pause>>(:final failure)) {
        return FailureResult(failure);
      }
      final pendingPauses = pendingResult.valueOrNull!;
      if (pendingPauses.isNotEmpty) {
        return Success(
          pendingPauses
              .map(
                (pause) => _PausedNode(
                  nodeId: pause.nodeId,
                  kind: pause.kind,
                  question: pause.question ?? pause.instructions,
                  options: pause.options,
                  pauseId: pause.id,
                ),
              )
              .toList(growable: false),
        );
      }
    }
    return const Success(<_PausedNode>[]);
  }

  // ---------------------------------------------------------------------------
  // Main loop
  // ---------------------------------------------------------------------------

  Future<Result<Run>> _drive(_RunExecution x) async {
    final runId = x.run.id;
    _active[runId] = x;
    final queuedCancel = _earlyCancels.remove(runId);
    if (queuedCancel != null) {
      x
        ..cancelRequested = true
        ..cancelCompleter = queuedCancel;
    }
    final subscriptions = <StreamSubscription<HumanPauseRequest>>[
      _pauseGateway.requests.where((request) => request.runId == runId).listen((
        request,
      ) {
        x.signals.add((request, false));
        x.wakeUp();
      }),
      _pauseGateway.answered.where((request) => request.runId == runId).listen((
        request,
      ) {
        x.signals.add((request, true));
        x.wakeUp();
      }),
    ];

    Result<Run> outcome;
    try {
      outcome = await _loop(x);
    } on Object catch (error, stackTrace) {
      _log.severe(
        LogEvent('graph_engine.crashed', fields: {'runId': runId}),
        error,
        stackTrace,
      );
      x.failReason = 'The graph engine crashed: $error';
      final failed = await _finishFailed(x);
      outcome = failed.isFailure
          ? failed
          : FailureResult(UnexpectedFailure(x.failReason!, cause: error));
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }

    // A cancel that raced the end of the run: apply it when the run is only
    // paused, otherwise say plainly that it came too late.
    final waiter = x.cancelCompleter;
    if (waiter != null && !waiter.isCompleted) {
      if (outcome case Success<Run>(:final value)
          when value.status == RunStatus.paused) {
        _pauseGateway.cancelRun(runId);
        await _pauses?.cancelPendingForRun(runId, cancelledAt: _now());
        outcome = await _finishTerminal(
          runId,
          status: RunStatus.cancelled,
          eventType: RunEventType.runCancelled,
          payload: const <String, Object?>{'from': 'paused'},
        );
      }
      waiter.complete(await _settleQueuedCancel(runId, outcome));
    }
    _active.remove(runId);
    return outcome;
  }

  Future<Result<Run>> _loop(_RunExecution x) async {
    while (true) {
      if (x.cancelRequested) {
        x.finishing = true;
        return await _finishCancelled(x);
      }

      await _handleSignals(x);
      if (x.running.isEmpty && x.queuedResumes.isNotEmpty) {
        await _activateQueuedResumes(x);
      }
      if (x.failReason == null) await _launchReady(x);
      if (x.cancelRequested) continue;
      if (x.failReason != null) {
        x.finishing = true;
        return await _finishFailed(x);
      }
      if (x.running.isEmpty) {
        if (x.queuedResumes.isNotEmpty) continue;
        x.finishing = true;
        break;
      }
      if (x.signals.isNotEmpty) continue;

      final event = await Future.any<Object>(<Future<Object>>[
        for (final active in x.running.values) active.future,
        x.wakeFuture.then((_) => const _WakeUp()),
      ]);
      if (event is _NodeCompletion) {
        await _onCompletion(x, event);
      } else {
        x.resetWake();
      }
    }

    if (x.paused.isNotEmpty) return await _finishPaused(x);
    if (x.pending.isNotEmpty) {
      x.failReason =
          'The scheduler stalled with pending nodes ${x.pending.join(', ')}.';
      return await _finishFailed(x);
    }
    return await _finishSucceeded(x);
  }

  Future<void> _activateQueuedResumes(_RunExecution x) async {
    while (x.queuedResumes.isNotEmpty) {
      final input = x.queuedResumes.removeAt(0);
      final nodeId = input.nodeId!;
      x.humanAnswers[nodeId] = input.answer;
      final rollback = await _rollbackBefore(x.run.id, <String>{nodeId});
      if (rollback case FailureResult<void>(:final failure)) {
        await _emit(
          x.run.id,
          RunEventType.nodeFailed,
          nodeId: nodeId,
          payload: <String, Object?>{
            'infrastructure': false,
            'message': failure.message,
          },
        );
        x.failReason =
            'Could not roll back workspace for node "${_labelOf(x, nodeId)}": '
            '${failure.message}';
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Live ask_human pauses (ADR 0019)
  // ---------------------------------------------------------------------------

  /// Applies the queued gateway signals.
  ///
  /// A question from a running harness pauses the run (checkpoint, `paused`
  /// status, `run.paused`) while the harness stays alive and the gateway holds
  /// its request open. The engine never terminates the harness for it. When
  /// the human answers through the gateway (F11), the run goes back to
  /// `running` and the harness continues in the same process.
  Future<void> _handleSignals(_RunExecution x) async {
    var entered = false;
    var left = false;
    while (x.signals.isNotEmpty) {
      final (request, answered) = x.signals.removeAt(0);
      final active = x.running[request.nodeId];
      if (active == null || active.attempt != request.attempt) continue;
      if (answered) {
        left = x.livePaused.remove(request.nodeId) != null || left;
      } else if (!x.livePaused.containsKey(request.nodeId)) {
        x.livePaused[request.nodeId] = _PausedNode(
          nodeId: request.nodeId,
          kind: PauseKind.askHuman,
          question: request.question,
          options: request.options,
          pauseId: request.pauseId,
          live: true,
        );
        entered = true;
      }
    }
    if (entered) await _enterLivePause(x);
    if (left) await _leaveLivePause(x);
  }

  Future<void> _enterLivePause(_RunExecution x) async {
    await _saveCheckpoint(x);
    if (x.failReason != null) return;
    if (!x.statusPaused) {
      final updated = await _runs.updateStatus(
        x.run.id,
        status: RunStatus.paused,
      );
      if (updated case FailureResult<Run>(:final failure)) {
        x.failReason = 'Could not mark the run paused: ${failure.message}';
        return;
      }
      x.statusPaused = true;
    }
    await _persistPauses(x, x.livePaused.values);
    if (x.failReason != null) return;
    await _emit(
      x.run.id,
      RunEventType.runPaused,
      payload: <String, Object?>{'pausedNodes': _pausedPayload(x)},
    );
  }

  Future<void> _leaveLivePause(_RunExecution x) async {
    if (!x.statusPaused || x.paused.isNotEmpty || x.livePaused.isNotEmpty) {
      return;
    }
    final updated = await _runs.updateStatus(
      x.run.id,
      status: RunStatus.running,
    );
    if (updated case FailureResult<Run>(:final failure)) {
      x.failReason = 'Could not mark the run running: ${failure.message}';
      return;
    }
    x.statusPaused = false;
    await _emit(
      x.run.id,
      RunEventType.runResumed,
      payload: const <String, Object?>{'from': 'paused', 'live': true},
    );
  }

  List<JsonMap> _pausedPayload(_RunExecution x) => [
    for (final node in x.paused.values) node.toJson(),
    for (final node in x.livePaused.values) node.toJson(),
  ];

  // ---------------------------------------------------------------------------
  // Launching: frontier, fan-in barrier, serialized snapshots
  // ---------------------------------------------------------------------------

  /// Whether the pending node at [index] must wait because a running node or
  /// another pending node can still reach it (fan-in barrier). Reachability
  /// ignores output labels, so a conditional branch that was not taken (and so
  /// is neither running nor pending) never blocks a merge.
  bool _isHeld(_RunExecution x, int index) {
    final id = x.pending[index];
    for (final runningId in x.running.keys) {
      if (x.graph.reaches(runningId, id)) return true;
    }
    for (var i = 0; i < x.pending.length; i++) {
      if (i == index) continue;
      final other = x.pending[i];
      if (!x.graph.reaches(other, id)) continue;
      // Nodes on a common cycle reach each other; queue order breaks the tie
      // so they cannot hold each other forever.
      if (!x.graph.reaches(id, other) || i < index) return true;
    }
    return false;
  }

  Future<void> _launchReady(_RunExecution x) async {
    final slots = maxConcurrency - x.running.length;
    if (slots <= 0 || x.pending.isEmpty) return;

    // While the run waits for a human no new work starts, except nodes whose
    // outcome or human answer was already supplied.
    final waiting =
        x.paused.isNotEmpty ||
        x.livePaused.isNotEmpty ||
        x.queuedResumes.isNotEmpty;
    final ready = <String>[];
    for (var i = 0; i < x.pending.length && ready.length < slots; i++) {
      final id = x.pending[i];
      if (x.paused.containsKey(id)) continue;
      if (x.queuedResumes.any((q) => q.nodeId == id)) continue;
      if (waiting &&
          !x.resolved.containsKey(id) &&
          !x.humanAnswers.containsKey(id)) {
        continue;
      }
      if (!_isHeld(x, i)) ready.add(id);
    }
    if (ready.isEmpty) return;

    final prepared = <(WorkflowNode, Node)>[];
    for (final id in ready) {
      final workflowNode = x.graph.node(id);
      if (workflowNode == null) {
        x.failReason = 'Node "$id" does not exist in the workflow.';
        return;
      }
      final created = _registry.create(workflowNode.type);
      if (created case FailureResult<Node>(:final failure)) {
        x.failReason =
            'Node "${workflowNode.label}" cannot run: ${failure.message}';
        return;
      }
      prepared.add((workflowNode, created.valueOrNull!));
    }
    x.pending.removeWhere(ready.contains);

    // Snapshots of one divergence are taken one after the other, never
    // concurrently, because every branch shares the run's single workspace and
    // shadow git repository (ADR 0004).
    for (final (workflowNode, _) in prepared) {
      if (x.resolved.containsKey(workflowNode.id)) continue;
      await _captureSnapshot(x, workflowNode.id);
      await _emit(
        x.run.id,
        RunEventType.nodeStarted,
        nodeId: workflowNode.id,
        payload: <String, Object?>{
          'attempt': (x.executionsByNode[workflowNode.id] ?? 0) + 1,
        },
      );
    }

    if (x.cancelRequested) {
      x.pending.insertAll(0, ready);
      return;
    }

    for (final (workflowNode, node) in prepared) {
      _startNode(x, workflowNode, node);
    }
  }

  Future<void> _captureSnapshot(_RunExecution x, String nodeId) async {
    final captured = await _snapshots.captureSnapshot(
      runId: x.run.id,
      targetFolder: _targetFolderOf(x.run),
      nodeId: nodeId,
    );
    if (captured case FailureResult<Snapshot>(:final failure)) {
      await _emit(
        x.run.id,
        RunEventType.snapshotWarning,
        nodeId: nodeId,
        payload: <String, Object?>{'message': failure.message},
      );
    }
  }

  String _targetFolderOf(Run run) =>
      run.isolationMode == WorkspaceIsolationMode.worktree &&
          run.worktreePath != null
      ? run.worktreePath!
      : run.workspaceRoot;

  void _startNode(_RunExecution x, WorkflowNode workflowNode, Node node) {
    final id = workflowNode.id;
    final attempt = (x.executionsByNode[id] ?? 0) + 1;
    final resolved = x.resolved.remove(id);

    final active = _ActiveNode(nodeId: id, attempt: attempt);
    x.running[id] = active;
    if (resolved != null) {
      active.future = Future<_NodeCompletion>.value(
        _NodeCompletion(id, Success(resolved)),
      );
    } else {
      x.executionsByNode[id] = attempt;
      active.future = _execute(
        node,
        NodeExecutionContext(
          runId: x.run.id,
          nodeId: id,
          nodeLabel: workflowNode.label,
          targetFolder: _targetFolderOf(x.run),
          workspaceRoot: x.run.workspaceRoot,
          workspaceId: x.run.workspaceId,
          attempt: attempt,
          availableOutputs: node.availableOutputs,
          config: workflowNode.config,
          inputs: _inputsFor(x, id),
          isolationMode: x.run.isolationMode,
          humanAnswer: x.humanAnswers.remove(id),
          runInput: id == x.run.workflowDefinition.entryNodeId
              ? x.run.input
              : null,
          runAttachments: _attachmentFilesOf(x.run),
          onOutput: _logStore == null
              ? null
              : (stream, line) => _recordNodeOutput(
                  runId: x.run.id,
                  nodeId: id,
                  attempt: attempt,
                  stream: stream,
                  chunk: line,
                ),
        ),
      );
    }
  }

  List<RunAttachmentFile> _attachmentFilesOf(Run run) {
    final store = _attachments;
    final list = run.attachments;
    if (store == null || list == null || list.isEmpty) return const [];
    return [
      for (final (i, a) in list.indexed)
        RunAttachmentFile(
          path: store.filePath(run.id, i, a),
          fileName: a.fileName,
        ),
    ];
  }

  void _recordNodeOutput({
    required String runId,
    required String nodeId,
    required int attempt,
    required String stream,
    required String chunk,
  }) {
    final store = _logStore;
    if (store == null) return;
    final outputStream = stream == 'stderr'
        ? RunOutputStream.stderr
        : RunOutputStream.stdout;
    unawaited(
      store.appendOutput(
        runId: runId,
        nodeId: nodeId,
        attempt: attempt,
        stream: outputStream,
        chunk: chunk,
        timestamp: _now(),
      ),
    );
  }

  Future<_NodeCompletion> _execute(
    Node node,
    NodeExecutionContext context,
  ) async {
    try {
      return _NodeCompletion(context.nodeId, await node.execute(context));
    } on Object catch (error) {
      return _NodeCompletion(
        context.nodeId,
        FailureResult(
          UnexpectedFailure(
            'Node "${context.nodeId}" threw: $error',
            cause: error,
          ),
        ),
      );
    }
  }

  /// Accumulated outputs of every completed node plus the outcomes of the
  /// immediate predecessors of the current traversal into [nodeId].
  ///
  /// After a resume the traversal is not in memory; the predecessors are then
  /// derived from the outputs whose label matches an incoming edge.
  Map<String, Object?> _inputsFor(_RunExecution x, String nodeId) {
    final predecessors = <String, Object?>{};
    final traversal = x.traversals[nodeId];
    if (traversal != null) {
      predecessors.addAll(traversal);
    } else {
      for (final edge in x.graph.incoming(nodeId)) {
        final output = x.nodeOutputs[edge.sourceNodeId];
        if (output != null && output['outputLabel'] == edge.sourceOutput) {
          predecessors[edge.sourceNodeId] = output;
        }
      }
    }
    return <String, Object?>{
      'nodeOutputs': Map<String, JsonMap>.of(x.nodeOutputs),
      'predecessors': predecessors,
    };
  }

  // ---------------------------------------------------------------------------
  // Completion handling
  // ---------------------------------------------------------------------------

  Future<void> _onCompletion(_RunExecution x, _NodeCompletion done) async {
    final active = x.running.remove(done.nodeId);
    final hadAnsweredSignal = x.signals.any(
      (s) => s.$1.nodeId == done.nodeId && s.$2,
    );
    x.signals.removeWhere((s) => s.$1.nodeId == done.nodeId);
    if (active != null) {
      _pauseGateway.cancelAttempt(
        runId: x.run.id,
        nodeId: done.nodeId,
        attempt: active.attempt,
      );
    }
    final wasLive = x.livePaused.remove(done.nodeId) != null;
    if (!hadAnsweredSignal) {
      await _pauses?.cancelPendingForNode(
        x.run.id,
        done.nodeId,
        cancelledAt: _now(),
      );
    }
    if (x.cancelRequested) return;
    if (wasLive) await _leaveLivePause(x);

    switch (done.result) {
      case Success<NodeOutcome>(:final value):
        await _onOutcome(x, done.nodeId, value);
      case FailureResult<NodeOutcome>(:final failure):
        await _onNodeFailure(x, done.nodeId, failure);
    }
  }

  Future<void> _onNodeFailure(
    _RunExecution x,
    String id,
    Failure failure,
  ) async {
    if (failure case PauseRequestedFailure(
      :final kind,
      :final question,
      :final proposalNodeId,
      :final proposal,
      :final proposalSchema,
    )) {
      x.paused[id] = _PausedNode(
        nodeId: id,
        kind: kind,
        question: question,
        proposalNodeId: proposalNodeId,
        proposal: proposal,
        proposalSchema: proposalSchema,
      );
      return;
    }

    if (failure is NodeExecutionFailure) {
      // Infrastructure failure: no outcome was reported. Retry the node in
      // place until a normal outcome arrives or the breaker trips.
      x.circuitBreakerCount++;
      await _emit(
        x.run.id,
        RunEventType.nodeFailed,
        nodeId: id,
        payload: <String, Object?>{
          'infrastructure': true,
          'message': failure.message,
          'circuitBreakerCount': x.circuitBreakerCount,
          if (failure.exitCode != null) 'exitCode': failure.exitCode,
        },
      );
      if (x.circuitBreakerCount >= circuitBreakerThreshold) {
        x.failReason =
            'Circuit breaker tripped after ${x.circuitBreakerCount} '
            'consecutive infrastructure failures: ${failure.message}';
      } else {
        x.pending.insert(0, id);
      }
      return;
    }

    // Authentication, validation or unexpected failures cannot be fixed by
    // running the node again.
    await _emit(
      x.run.id,
      RunEventType.nodeFailed,
      nodeId: id,
      payload: <String, Object?>{
        'infrastructure': false,
        'message': failure.message,
      },
    );
    x.failReason = 'Node "${_labelOf(x, id)}" failed: ${failure.message}';
  }

  Future<void> _onOutcome(
    _RunExecution x,
    String nodeId,
    NodeOutcome outcome,
  ) async {
    x.circuitBreakerCount = 0;
    x.traversals.remove(nodeId);
    final label = outcome.outputLabel;
    x.nodeOutputs[nodeId] = <String, Object?>{
      'outputLabel': label,
      'data': outcome.data,
      'artifacts': outcome.artifacts,
    };
    await _emit(
      x.run.id,
      RunEventType.nodeCompleted,
      nodeId: nodeId,
      payload: <String, Object?>{'outputLabel': label},
    );

    final outgoing = x.graph.outgoing(nodeId);
    final matching = outgoing
        .where((edge) => edge.sourceOutput == label)
        .toList(growable: false);

    if (matching.isEmpty) {
      final endsBranch = outgoing.isEmpty && _isPositive(label);
      if (!endsBranch) {
        x.failReason = _withSummary(
          outgoing.isEmpty
              ? 'Node "${_labelOf(x, nodeId)}" ended with "$label" and has no '
                    'outgoing edge.'
              : 'Node "${_labelOf(x, nodeId)}" emitted "$label" but no edge '
                    'leaves it for that output.',
          outcome,
        );
        return;
      }
    }

    for (final edge in matching) {
      final limit = edge.maxRetries;
      if (limit != null) {
        final attempts = x.attemptsByEdge[edge.id] ?? 0;
        if (attempts >= limit) {
          x.failReason =
              'Edge "${edge.id}" exceeded its limit of $limit retries.';
          return;
        }
        x.attemptsByEdge[edge.id] = attempts + 1;
        await _emit(
          x.run.id,
          RunEventType.nodeRetried,
          nodeId: edge.targetNodeId,
          edgeId: edge.id,
          payload: <String, Object?>{
            'attempt': attempts + 1,
            'maxRetries': limit,
          },
        );
      }
      (x.traversals[edge.targetNodeId] ??= <String, JsonMap>{})[nodeId] =
          x.nodeOutputs[nodeId]!;
      if (!x.pending.contains(edge.targetNodeId)) {
        x.pending.add(edge.targetNodeId);
      }
    }

    await _saveCheckpoint(x, completedNodeId: nodeId);
  }

  bool _isPositive(String label) =>
      label == NodeOutput.onSuccess || label == NodeOutput.approved;

  String _withSummary(String reason, NodeOutcome outcome) {
    final raw = outcome.data['summary'];
    if (raw is! String) return reason;
    final text = raw.trim();
    if (text.isEmpty) return reason;
    final shown = text.length > _maxSummaryLength
        ? '${text.substring(0, _maxSummaryLength)}…'
        : text;
    return '$reason Summary: $shown';
  }

  String _labelOf(_RunExecution x, String nodeId) =>
      x.graph.node(nodeId)?.label ?? nodeId;

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  /// Appends a checkpoint holding everything that must still run: paused
  /// nodes, nodes in flight and pending nodes.
  Future<void> _saveCheckpoint(
    _RunExecution x, {
    String? completedNodeId,
  }) async {
    final pendingIds = <String>{
      ...x.paused.keys,
      ...x.running.keys,
      ...x.pending,
    }.toList(growable: false);

    final saved = await _checkpoints.append(
      id: _generateId(),
      runId: x.run.id,
      pendingNodeIds: pendingIds,
      attemptsByEdge: Map<String, int>.of(x.attemptsByEdge),
      circuitBreakerCount: x.circuitBreakerCount,
      nodeOutputs: Map<String, JsonMap>.of(x.nodeOutputs),
      createdAt: _now(),
      completedNodeId: completedNodeId,
    );
    switch (saved) {
      case FailureResult<Checkpoint>(:final failure):
        x.failReason ??= 'Could not save a checkpoint: ${failure.message}';
      case Success<Checkpoint>(:final value):
        await _emit(
          x.run.id,
          RunEventType.checkpointSaved,
          nodeId: completedNodeId,
          payload: <String, Object?>{
            'checkpointId': value.id,
            'sequence': value.sequence,
          },
        );
    }
  }

  /// Appends an event. Events are an audit trail, so a failed append is
  /// logged instead of failing the run.
  Future<void> _emit(
    String runId,
    RunEventType type, {
    String? nodeId,
    String? edgeId,
    JsonMap payload = const <String, Object?>{},
  }) async {
    final appended = await _events.append(
      id: _generateId(),
      runId: runId,
      type: type,
      createdAt: _now(),
      nodeId: nodeId,
      edgeId: edgeId,
      payload: payload,
    );
    if (appended case FailureResult<RunEvent>(:final failure)) {
      _log.warning(
        LogEvent(
          'graph_engine.event_failed',
          fields: {
            'runId': runId,
            'type': type.wireName,
            'error': failure.message,
          },
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Finishing
  // ---------------------------------------------------------------------------

  /// Writes the final [status] first and the terminal event afterwards, so a
  /// failed status write never leaves a terminal event in the log for a run
  /// that is still `running`.
  Future<Result<Run>> _finishTerminal(
    String runId, {
    required RunStatus status,
    required RunEventType eventType,
    JsonMap payload = const <String, Object?>{},
    String? errorMessage,
  }) async {
    final updated = await _runs.updateStatus(
      runId,
      status: status,
      finishedAt: _now(),
      errorMessage: errorMessage,
    );
    if (updated case FailureResult<Run>(:final failure)) {
      _log.severe(
        LogEvent(
          'graph_engine.status_write_failed',
          fields: {
            'runId': runId,
            'status': status.name,
            'error': failure.message,
          },
        ),
      );
      return updated;
    }
    if (attachmentDeletingStatuses.contains(status)) {
      await _attachments?.deleteRunBestEffort(runId);
    }
    await _emit(runId, eventType, payload: payload);
    return updated;
  }

  Future<Result<Run>> _finishSucceeded(_RunExecution x) => _finishTerminal(
    x.run.id,
    status: RunStatus.succeeded,
    eventType: RunEventType.runSucceeded,
  );

  Future<Result<Run>> _finishPaused(_RunExecution x) async {
    await _saveCheckpoint(x);
    if (x.failReason != null) return await _finishFailed(x);

    final updated = await _runs.updateStatus(
      x.run.id,
      status: RunStatus.paused,
    );
    if (updated case FailureResult<Run>()) return updated;
    x.statusPaused = true;
    await _persistPauses(x, x.paused.values);
    if (x.failReason != null) return await _finishFailed(x);
    await _emit(
      x.run.id,
      RunEventType.runPaused,
      payload: <String, Object?>{'pausedNodes': _pausedPayload(x)},
    );
    return updated;
  }

  Future<void> _persistPauses(
    _RunExecution x,
    Iterable<_PausedNode> nodes,
  ) async {
    final pausesRepo = _pauses;
    if (pausesRepo == null) return;
    final existingResult = await pausesRepo.listPendingForRun(x.run.id);
    if (existingResult case FailureResult<List<Pause>>(:final failure)) {
      _log.warning(
        LogEvent(
          'graph_engine.pause_list_failed',
          fields: {'runId': x.run.id, 'error': failure.message},
        ),
      );
      await _failPausePersistence(x, nodes.firstOrNull?.nodeId, failure);
      return;
    }
    final existingByNodeId = <String, Pause>{
      for (final p in existingResult.valueOrNull!) p.nodeId: p,
    };

    for (final node in nodes) {
      if (existingByNodeId.containsKey(node.nodeId)) continue;
      final workflowNode = x.graph.node(node.nodeId);
      final nodeLabel = workflowNode?.label ?? node.nodeId;
      String? title;
      String? instructions;
      var allowFeedback = true;
      if (node.kind == PauseKind.humanApproval && workflowNode != null) {
        try {
          final config = HumanApprovalNodeConfig.fromJson(workflowNode.config);
          title = config.title;
          instructions = config.instructions;
          allowFeedback = config.allowFeedback;
        } on FormatException {
          instructions = node.question;
        }
      }

      final pause = Pause(
        id: node.pauseId ?? _generateId(),
        runId: x.run.id,
        nodeId: node.nodeId,
        kind: node.kind,
        status: PauseStatus.pending,
        workflowName: x.run.workflowName,
        nodeLabel: nodeLabel,
        title: title,
        instructions: node.kind == PauseKind.humanApproval
            ? (instructions ?? node.question)
            : null,
        allowFeedback: allowFeedback,
        question: node.kind == PauseKind.askHuman ? node.question : null,
        options: node.options,
        proposal: node.proposal,
        proposalSchema: node.proposal != null ? node.proposalSchema : null,
        proposalSource: node.proposal != null && node.proposalNodeId != null
            ? (x.graph.node(node.proposalNodeId!)?.label ?? node.proposalNodeId)
            : null,
        createdAt: _now(),
        parentRunId: x.run.parentRunId,
      );
      final created = await pausesRepo.create(pause);
      if (created case FailureResult<Pause>(:final failure)) {
        _log.warning(
          LogEvent(
            'graph_engine.pause_create_failed',
            fields: {
              'runId': x.run.id,
              'nodeId': node.nodeId,
              'error': failure.message,
            },
          ),
        );
        await _failPausePersistence(x, node.nodeId, failure);
        return;
      }
    }
  }

  Future<void> _failPausePersistence(
    _RunExecution x,
    String? nodeId,
    Failure failure,
  ) async {
    _pauseGateway.cancelRun(x.run.id);
    await _emit(
      x.run.id,
      RunEventType.nodeFailed,
      nodeId: nodeId,
      payload: <String, Object?>{
        'infrastructure': false,
        'message': 'Could not persist pause: ${failure.message}',
      },
    );
    final label = nodeId == null ? 'unknown' : _labelOf(x, nodeId);
    x.failReason =
        'Could not persist pause for node "$label": ${failure.message}';
  }

  /// Fail-fast: cancels active siblings, waits for their process trees to
  /// exit, then marks the run `failed`. When the exit cannot be confirmed the
  /// run still fails, with `kill_unconfirmed` in the `run.failed` payload and
  /// the error message, so leftover processes are never silent.
  Future<Result<Run>> _finishFailed(_RunExecution x) async {
    x.finishing = true;
    var reason = x.failReason ?? 'The run failed.';
    var killError = '';
    final childrenStopped = await _cancelChildRuns(x.run.id);
    final nodesStopped = await _stopRunningNodes(x);
    final childrenStoppedAfter = await _cancelChildRuns(x.run.id);
    final stopped = childrenStopped.isFailure
        ? childrenStopped
        : nodesStopped.isFailure
        ? nodesStopped
        : childrenStoppedAfter;
    if (stopped case FailureResult<void>(:final failure)) {
      killError = failure.message;
      reason = '$reason (process exit unconfirmed: $killError)';
      _log.warning(
        LogEvent(
          'graph_engine.kill_unconfirmed',
          fields: {'runId': x.run.id, 'error': killError},
        ),
      );
      x.running.clear();
    }
    _pauseGateway.cancelRun(x.run.id);
    await _pauses?.cancelPendingForRun(x.run.id, cancelledAt: _now());
    return await _finishTerminal(
      x.run.id,
      status: RunStatus.failed,
      eventType: RunEventType.runFailed,
      payload: <String, Object?>{
        'reason': reason,
        if (killError.isNotEmpty) 'kill_unconfirmed': true,
        if (killError.isNotEmpty) 'kill_error': killError,
      },
      errorMessage: reason,
    );
  }

  Future<Result<Run>> _finishCancelled(_RunExecution x) async {
    final fromStatus = x.statusPaused ? 'paused' : 'running';
    final cancelling = await _runs.updateStatus(
      x.run.id,
      status: RunStatus.cancelling,
    );
    if (cancelling case FailureResult<Run>()) return cancelling;
    x.run = cancelling.valueOrNull!;
    await _emit(
      x.run.id,
      RunEventType.runCancelling,
      payload: <String, Object?>{'from': fromStatus},
    );

    final childrenStopped = await _cancelChildRuns(x.run.id);
    final nodesStopped = await _stopRunningNodes(x);
    final stopped = childrenStopped.isFailure ? childrenStopped : nodesStopped;
    if (stopped case FailureResult<void>(:final failure)) {
      _log.warning(
        LogEvent(
          'graph_engine.cancel_kill_unconfirmed',
          fields: {'runId': x.run.id, 'error': failure.message},
        ),
      );
      _pauseGateway.cancelRun(x.run.id);
      x.running.clear();
      x.livePaused.clear();
      return await _finishTerminal(
        x.run.id,
        status: RunStatus.cancellationUncertain,
        eventType: RunEventType.runCancellationUncertain,
        payload: <String, Object?>{
          'from': fromStatus,
          'error': failure.message,
        },
        errorMessage:
            'Could not confirm that all processes exited: ${failure.message}',
      );
    }
    _pauseGateway.cancelRun(x.run.id);
    await _pauses?.cancelPendingForRun(x.run.id, cancelledAt: _now());
    return await _finishTerminal(
      x.run.id,
      status: RunStatus.cancelled,
      eventType: RunEventType.runCancelled,
      payload: <String, Object?>{'from': fromStatus},
    );
  }

  Future<Result<Run>> _retryCancel(String runId) async {
    final cancelling = await _runs.updateStatus(
      runId,
      status: RunStatus.cancelling,
      clearFinishedAt: true,
      clearErrorMessage: true,
    );
    if (cancelling case FailureResult<Run>()) return cancelling;
    await _emit(
      runId,
      RunEventType.runCancelling,
      payload: const <String, Object?>{
        'from': 'cancellationUncertain',
        'retry': true,
      },
    );

    final childrenStopped = await _cancelChildRuns(runId);
    if (childrenStopped case FailureResult<void>(:final failure)) {
      _log.warning(
        LogEvent(
          'graph_engine.retry_cancel_unconfirmed',
          fields: {'runId': runId, 'error': failure.message},
        ),
      );
      return await _finishTerminal(
        runId,
        status: RunStatus.cancellationUncertain,
        eventType: RunEventType.runCancellationUncertain,
        payload: <String, Object?>{
          'from': 'cancellationUncertain',
          'retry': true,
          'error': failure.message,
        },
        errorMessage:
            'Could not confirm that all processes exited: ${failure.message}',
      );
    }

    final killed = await _processTreeKiller.killTree(runId: runId);
    if (killed case FailureResult<void>(:final failure)) {
      _log.warning(
        LogEvent(
          'graph_engine.retry_cancel_unconfirmed',
          fields: {'runId': runId, 'error': failure.message},
        ),
      );
      return await _finishTerminal(
        runId,
        status: RunStatus.cancellationUncertain,
        eventType: RunEventType.runCancellationUncertain,
        payload: <String, Object?>{
          'from': 'cancellationUncertain',
          'retry': true,
          'error': failure.message,
        },
        errorMessage:
            'Could not confirm that all processes exited: ${failure.message}',
      );
    }

    _pauseGateway.cancelRun(runId);
    await _pauses?.cancelPendingForRun(runId, cancelledAt: _now());
    return await _finishTerminal(
      runId,
      status: RunStatus.cancelled,
      eventType: RunEventType.runCancelled,
      payload: const <String, Object?>{
        'from': 'cancellationUncertain',
        'retry': true,
      },
    );
  }

  /// Cancels every child run of [parentRunId] that is not final, through this
  /// engine (a [RunCanceller]), and waits until each cancel settled.
  /// Fails when a child could not be confirmed stopped (ADR 0029).
  Future<Result<void>> _cancelChildRuns(String parentRunId) async {
    const terminal = {
      RunStatus.succeeded,
      RunStatus.failed,
      RunStatus.cancelled,
    };
    final attempted = <String>{};
    final unconfirmed = <String>[];
    for (var pass = 0; pass < 5; pass++) {
      final listed = await _runs.listChildren(parentRunId);
      if (listed case FailureResult<List<Run>>(:final failure)) {
        return FailureResult(failure);
      }
      final todo = listed.valueOrNull!
          .where((r) => !terminal.contains(r.status) && attempted.add(r.id))
          .toList();
      if (todo.isEmpty) break;
      final results = await Future.wait(todo.map((r) => _cancelOneChild(r.id)));
      for (final id in results) {
        if (id != null) unconfirmed.add(id);
      }
    }
    if (unconfirmed.isEmpty) return const Success(null);
    return FailureResult(
      NodeExecutionFailure(
        'Could not confirm that child run(s) '
        '${unconfirmed.join(', ')} stopped.',
      ),
    );
  }

  Future<String?> _cancelOneChild(String id) async {
    try {
      await cancel(id);
    } on Object {
      // Checked below.
    }
    final current = await _runs.getById(id);
    if (current case Success<Run>(:final value)) {
      if (value.status == RunStatus.cancellationUncertain ||
          value.status.isActive) {
        return id;
      }
    }
    return null;
  }

  /// Kills the process trees of every running node, waits for the kill to be
  /// confirmed, then requires all active node futures to settle within
  /// [cancelGracePeriod]. If node futures do not settle in time, treats the
  /// termination as unconfirmed so the run enters `cancellationUncertain`.
  Future<Result<void>> _stopRunningNodes(_RunExecution x) async {
    if (x.running.isEmpty) return const Success(null);
    final futures = x.running.values
        .map((active) => active.future)
        .toList(growable: false);

    final killed = await _processTreeKiller.killTree(runId: x.run.id);
    if (killed.isFailure) return killed;

    var timedOut = false;
    await Future.wait(futures).timeout(
      cancelGracePeriod,
      onTimeout: () {
        timedOut = true;
        return const <_NodeCompletion>[];
      },
    );
    if (timedOut) {
      return FailureResult(
        NodeExecutionFailure(
          'Timed out after ${cancelGracePeriod.inSeconds}s waiting for '
          'active node execution of run "${x.run.id}" to settle after kill.',
        ),
      );
    }

    x.running.clear();
    x.livePaused.clear();
    return killed;
  }
}
