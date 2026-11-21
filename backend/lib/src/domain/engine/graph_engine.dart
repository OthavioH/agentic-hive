import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/engine/workflow_graph.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_recovery_service.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/snapshot_service.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';

/// A node that stopped the run until a human answers.
final class _PausedNode {
  const new({required this.nodeId, required this.kind, this.question});

  factory fromJson(Object? json) {
    final map = json! as Map<Object?, Object?>;
    return _PausedNode(
      nodeId: map['nodeId']! as String,
      kind: PauseKind.values.byName(map['kind']! as String),
      question: map['question'] as String?,
    );
  }

  final String nodeId;
  final PauseKind kind;
  final String? question;

  JsonMap toJson() => <String, Object?>{
    'nodeId': nodeId,
    'kind': kind.name,
    if (question != null) 'question': question,
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

  /// Set when the harness called `ask_human` during this attempt.
  HumanPauseRequest? pauseRequest;

  /// Completes once the harness process tree of this attempt has exited.
  Future<Result<void>>? termination;
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
  final Map<String, _PausedNode> paused = <String, _PausedNode>{};
  final Map<String, int> executionsByNode = <String, int>{};

  /// Outcomes already decided by a human on resume; the node is not re-run.
  final Map<String, NodeOutcome> resolved = <String, NodeOutcome>{};

  /// Answers to inject into the next execution of an `ask_human` node.
  final Map<String, String> humanAnswers = <String, String>{};

  final Completer<void> cancelSignal = Completer<void>();
  final Completer<Result<Run>> cancelDone = Completer<Result<Run>>();
  bool cancelRequested = false;
  String? failReason;
}

/// Marker returned by the wait loop when a cancel request wakes it.
final class _CancelWakeUp {
  const new();
}

/// Executes a frozen workflow from its entry node to a terminal state, a
/// pause, or a cancellation (ADR 0001, 0003, 0004, 0006, 0007).
///
/// The engine talks to nodes only through `Node.execute`; it never inspects a
/// concrete node type and never assumes the workspace is code. Everything it
/// persists goes through the run, checkpoint and event repositories, and every
/// fallible call returns a `Result` (ADR 0017).
final class GraphEngine {
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

  /// Whether the engine is currently driving [runId] in this process.
  bool isExecuting(String runId) => _claimed.contains(runId);

  /// Starts the `running` run [runId] at its workflow's entry node and drives
  /// it until it succeeds, fails, is cancelled, or pauses.
  ///
  /// The returned future completes with the run in its final persisted state.
  Future<Result<Run>> start(String runId) async {
    if (!_claim(runId)) return _alreadyExecuting(runId);
    try {
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
    } finally {
      _claimed.remove(runId);
    }
  }

  /// Resumes the `paused` or `interrupted` run [runId].
  ///
  /// A `paused` run needs [input] for its paused node: an
  /// [ApprovalDecisionInput] resolves a `human_approval` node directly, a
  /// [HumanAnswerInput] re-runs the node that asked with the answer injected.
  /// Resuming a `paused` run keeps `attemptsByEdge` and the circuit breaker
  /// count. Resuming an `interrupted` run rolls the workspace back to the
  /// snapshot taken before the interrupted node, resets the circuit breaker to
  /// `0` and keeps `attemptsByEdge`. [input] is not needed then.
  Future<Result<Run>> resume(String runId, {ResumeInput? input}) async {
    if (!_claim(runId)) return _alreadyExecuting(runId);
    try {
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
            RunStatus.succeeded ||
            RunStatus.failed ||
            RunStatus.cancelled:
          return FailureResult(
            ConflictFailure(
              'Run "$runId" is ${status.name}; only a paused or interrupted '
              'run can be resumed.',
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
    } finally {
      _claimed.remove(runId);
    }
  }

  /// Cancels [runId].
  ///
  /// A run executing in this process aborts its active nodes and reports
  /// `run.cancelled` only after the [ProcessTreeKiller] confirmed that every
  /// process tree exited. A `paused` (or `interrupted`) run has nothing
  /// running and transitions to `cancelled` immediately.
  Future<Result<Run>> cancel(String runId) async {
    final executing = _active[runId];
    if (executing != null) {
      executing.cancelRequested = true;
      if (!executing.cancelSignal.isCompleted) {
        executing.cancelSignal.complete();
      }
      return await executing.cancelDone.future;
    }
    if (!_claim(runId)) return _alreadyExecuting(runId);
    try {
      final runResult = await _runs.getById(runId);
      if (runResult case FailureResult<Run>(:final failure)) {
        return FailureResult(failure);
      }
      final run = runResult.valueOrNull!;
      switch (run.status) {
        case RunStatus.paused || RunStatus.interrupted:
          _pauseGateway.cancelRun(runId);
          return await _finishTerminal(
            runId,
            status: RunStatus.cancelled,
            eventType: RunEventType.runCancelled,
            payload: <String, Object?>{'from': run.status.name},
          );
        case RunStatus.running:
          return FailureResult(
            ConflictFailure(
              'Run "$runId" is marked running but is not executing in this '
              'backend; wait for recovery to mark it interrupted.',
            ),
          );
        case RunStatus.succeeded || RunStatus.failed || RunStatus.cancelled:
          return FailureResult(
            ConflictFailure('Run "$runId" is already ${run.status.name}.'),
          );
      }
    } finally {
      _claimed.remove(runId);
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

    switch ((target.kind, input)) {
      case (PauseKind.approval, ApprovalDecisionInput()):
        final approval = input as ApprovalDecisionInput;
        x.resolved[target.nodeId] = NodeOutcome(
          outputLabel: switch (approval.decision) {
            HumanApprovalDecision.approved => NodeOutput.approved,
            HumanApprovalDecision.rejected => NodeOutput.rejected,
          },
          data: <String, Object?>{
            'decision': approval.decision.name,
            if (approval.feedback != null) 'feedback': approval.feedback,
          },
        );
      case (PauseKind.askHuman, HumanAnswerInput(:final answer)):
        if (answer.trim().isEmpty) {
          return const FailureResult(
            ValidationFailure('The human answer must not be blank.'),
          );
        }
        x.humanAnswers[target.nodeId] = answer;
        final rollback = await _rollback(
          point.run.id,
          nodeIds: <String>{target.nodeId},
          earliest: false,
        );
        if (rollback case FailureResult<void>(:final failure)) {
          return FailureResult(failure);
        }
      case (PauseKind.approval, _) || (PauseKind.askHuman, _):
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
    PauseKind.approval => 'an approval decision',
    PauseKind.askHuman => 'a human answer',
  };

  Future<Result<_RunExecution>> _prepareInterruptedResume(
    ResumePoint point,
  ) async {
    final rollback = await _rollback(
      point.run.id,
      nodeIds: point.pendingNodeIds.toSet(),
      earliest: true,
      since: point.latestCheckpoint?.createdAt,
    );
    if (rollback case FailureResult<void>(:final failure)) {
      return FailureResult(failure);
    }
    return Success(_newExecution(point, circuitBreakerCount: 0));
  }

  /// Restores the workspace to a pre-node snapshot of one of [nodeIds]: the
  /// earliest taken at or after [since] when [earliest], else the latest.
  /// Does nothing when no such snapshot exists (the node never started).
  Future<Result<void>> _rollback(
    String runId, {
    required Set<String> nodeIds,
    required bool earliest,
    DateTime? since,
  }) async {
    final listed = await _snapshots.listSnapshots(runId);
    if (listed case FailureResult<RunSnapshotsResponse>(:final failure)) {
      return FailureResult(failure);
    }
    final candidates = listed.valueOrNull!.items
        .where(
          (s) =>
              s.kind == SnapshotKind.preNode &&
              s.nodeId != null &&
              nodeIds.contains(s.nodeId) &&
              (since == null || !s.createdAt.isBefore(since)),
        )
        .toList(growable: false);
    if (candidates.isEmpty) return const Success(null);

    final snapshot = earliest ? candidates.first : candidates.last;
    final restored = await _snapshots.restoreSnapshot(runId, snapshot.id);
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
    if (raw is! List<Object?>) return const Success(<_PausedNode>[]);
    return Success(raw.map(_PausedNode.fromJson).toList(growable: false));
  }

  // ---------------------------------------------------------------------------
  // Main loop
  // ---------------------------------------------------------------------------

  Future<Result<Run>> _drive(_RunExecution x) async {
    final runId = x.run.id;
    _active[runId] = x;
    final subscription = _pauseGateway.requests
        .where((request) => request.runId == runId)
        .listen((request) => _onPauseRequest(x, request));

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
      await subscription.cancel();
      _active.remove(runId);
    }
    if (!x.cancelDone.isCompleted) x.cancelDone.complete(outcome);
    return outcome;
  }

  Future<Result<Run>> _loop(_RunExecution x) async {
    while (true) {
      if (x.cancelRequested) return await _finishCancelled(x);

      if (x.failReason == null && x.paused.isEmpty) {
        await _launchReady(x);
      }
      if (x.cancelRequested) continue;
      if (x.failReason != null) return await _finishFailed(x);
      if (x.running.isEmpty) break;

      final event = await Future.any<Object>(<Future<Object>>[
        for (final active in x.running.values) active.future,
        x.cancelSignal.future.then((_) => const _CancelWakeUp()),
      ]);
      if (event is _NodeCompletion) await _onCompletion(x, event);
    }

    if (x.paused.isNotEmpty) return await _finishPaused(x);
    if (x.pending.isNotEmpty) {
      x.failReason =
          'The scheduler stalled with pending nodes ${x.pending.join(', ')}.';
      return await _finishFailed(x);
    }
    return await _finishSucceeded(x);
  }

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

    final ready = <String>[];
    for (var i = 0; i < x.pending.length && ready.length < slots; i++) {
      if (!_isHeld(x, i)) ready.add(x.pending[i]);
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
      workspaceDir: _workspaceOf(x.run),
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

  String _workspaceOf(Run run) =>
      run.isolationMode == WorkspaceIsolationMode.worktree &&
          run.worktreePath != null
      ? run.worktreePath!
      : run.workspacePath;

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
          workspacePath: _workspaceOf(x.run),
          attempt: attempt,
          availableOutputs: node.availableOutputs,
          config: workflowNode.config,
          inputs: _inputsFor(x, id),
          humanAnswer: x.humanAnswers.remove(id),
        ),
      );
    }
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
  /// immediate predecessors whose edge led to [nodeId].
  Map<String, Object?> _inputsFor(_RunExecution x, String nodeId) {
    final predecessors = <String, Object?>{};
    for (final edge in x.graph.incoming(nodeId)) {
      final output = x.nodeOutputs[edge.sourceNodeId];
      if (output != null && output['outputLabel'] == edge.sourceOutput) {
        predecessors[edge.sourceNodeId] = output;
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
    final active = x.running.remove(done.nodeId)!;
    if (x.cancelRequested) return;

    switch (done.result) {
      case Success<NodeOutcome>(:final value):
        await _onOutcome(x, done.nodeId, value);
      case FailureResult<NodeOutcome>(:final failure):
        await _onNodeFailure(x, active, failure);
    }
  }

  void _onPauseRequest(_RunExecution x, HumanPauseRequest request) {
    final active = x.running[request.nodeId];
    if (active == null ||
        active.attempt != request.attempt ||
        active.pauseRequest != null) {
      return;
    }
    active
      ..pauseRequest = request
      ..termination = _terminateForPause(request);
  }

  /// Ends the harness that asked a question: its process tree must exit before
  /// the pause checkpoint is saved, and the waiting MCP request is released.
  Future<Result<void>> _terminateForPause(HumanPauseRequest request) async {
    final killed = await _processTreeKiller.killTree(
      runId: request.runId,
      nodeId: request.nodeId,
    );
    _pauseGateway.cancelAttempt(
      runId: request.runId,
      nodeId: request.nodeId,
      attempt: request.attempt,
    );
    return killed;
  }

  Future<void> _onNodeFailure(
    _RunExecution x,
    _ActiveNode active,
    Failure failure,
  ) async {
    final id = active.nodeId;

    final request = active.pauseRequest;
    if (request != null) {
      final terminated = await active.termination!;
      if (terminated case FailureResult<void>(failure: final killFailure)) {
        x.failReason =
            'Could not terminate node "$id" before pausing: '
            '${killFailure.message}';
        return;
      }
      x.paused[id] = _PausedNode(
        nodeId: id,
        kind: PauseKind.askHuman,
        question: request.question,
      );
      return;
    }

    if (failure case PauseRequestedFailure(:final kind, :final question)) {
      x.paused[id] = _PausedNode(nodeId: id, kind: kind, question: question);
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
        x.failReason = outgoing.isEmpty
            ? 'Node "${_labelOf(x, nodeId)}" ended with "$label" and has no '
                  'outgoing edge.'
            : 'Node "${_labelOf(x, nodeId)}" emitted "$label" but no edge '
                  'leaves it for that output.';
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
      if (!x.pending.contains(edge.targetNodeId)) {
        x.pending.add(edge.targetNodeId);
      }
    }

    await _saveCheckpoint(x, completedNodeId: nodeId);
  }

  bool _isPositive(String label) =>
      label == NodeOutput.onSuccess || label == NodeOutput.approved;

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

  Future<Result<Run>> _finishTerminal(
    String runId, {
    required RunStatus status,
    required RunEventType eventType,
    JsonMap payload = const <String, Object?>{},
    String? errorMessage,
  }) async {
    await _emit(runId, eventType, payload: payload);
    return await _runs.updateStatus(
      runId,
      status: status,
      finishedAt: _now(),
      errorMessage: errorMessage,
    );
  }

  Future<Result<Run>> _finishSucceeded(_RunExecution x) => _finishTerminal(
    x.run.id,
    status: RunStatus.succeeded,
    eventType: RunEventType.runSucceeded,
  );

  Future<Result<Run>> _finishPaused(_RunExecution x) async {
    await _saveCheckpoint(x);
    if (x.failReason != null) return await _finishFailed(x);

    await _emit(
      x.run.id,
      RunEventType.runPaused,
      payload: <String, Object?>{
        'pausedNodes': [for (final node in x.paused.values) node.toJson()],
      },
    );
    return await _runs.updateStatus(x.run.id, status: RunStatus.paused);
  }

  /// Fail-fast: cancels active siblings, waits for their process trees to
  /// exit, then marks the run `failed`.
  Future<Result<Run>> _finishFailed(_RunExecution x) async {
    final reason = x.failReason ?? 'The run failed.';
    final stopped = await _stopRunningNodes(x);
    if (stopped case FailureResult<void>(:final failure)) {
      _log.warning(
        LogEvent(
          'graph_engine.kill_unconfirmed',
          fields: {'runId': x.run.id, 'error': failure.message},
        ),
      );
    }
    _pauseGateway.cancelRun(x.run.id);
    return await _finishTerminal(
      x.run.id,
      status: RunStatus.failed,
      eventType: RunEventType.runFailed,
      payload: <String, Object?>{'reason': reason},
      errorMessage: reason,
    );
  }

  Future<Result<Run>> _finishCancelled(_RunExecution x) async {
    final stopped = await _stopRunningNodes(x);
    if (stopped case FailureResult<void>(:final failure)) {
      // The run stays `running`: cancellation is never reported as done
      // without confirmation that the process tree exited.
      return FailureResult(
        ConflictFailure(
          'Could not confirm that run "${x.run.id}" stopped: '
          '${failure.message}',
        ),
      );
    }
    _pauseGateway.cancelRun(x.run.id);
    return await _finishTerminal(
      x.run.id,
      status: RunStatus.cancelled,
      eventType: RunEventType.runCancelled,
      payload: const <String, Object?>{'from': 'running'},
    );
  }

  /// Kills the process trees of every running node, waits for the kill to be
  /// confirmed, then lets the abandoned node futures settle.
  Future<Result<void>> _stopRunningNodes(_RunExecution x) async {
    if (x.running.isEmpty) return const Success(null);
    final futures = x.running.values
        .map((active) => active.future)
        .toList(growable: false);

    final killed = await _processTreeKiller.killTree(runId: x.run.id);
    if (killed.isSuccess) {
      await Future.wait(
        futures,
      ).timeout(cancelGracePeriod, onTimeout: () => const <_NodeCompletion>[]);
    }
    x.running.clear();
    return killed;
  }
}
