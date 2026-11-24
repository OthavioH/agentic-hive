import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// In-memory [RunRepository] for engine tests.
final class InMemoryRunRepository implements RunRepository {
  /// Creates an empty repository.
  new();

  /// Stored runs by id.
  final Map<String, Run> runs = <String, Run>{};

  /// Every status written through [updateStatus], in order.
  final List<RunStatus> statusHistory = <RunStatus>[];

  /// Statuses whose write fails with a [PersistenceFailure].
  final Set<RunStatus> failingStatuses = <RunStatus>{};

  @override
  Future<Result<Run>> create(Run run) async {
    runs[run.id] = run;
    return Success(run);
  }

  @override
  Future<Result<Run>> getById(String id) async {
    final run = runs[id];
    return run == null
        ? FailureResult(NotFoundFailure('Run "$id" not found.'))
        : Success(run);
  }

  @override
  Future<Result<({List<RunSummary> items, int total})>> list({
    RunStatus? status,
    String? workflowId,
    int limit = 50,
    int offset = 0,
  }) async => const Success((items: <RunSummary>[], total: 0));

  @override
  Future<Result<List<Run>>> listByStatus(RunStatus status) async => Success(
    runs.values.where((r) => r.status == status).toList(growable: false),
  );

  @override
  Future<Result<List<Run>>> listChildren(
    String parentRunId, {
    String? parentNodeId,
  }) async {
    final matches =
        runs.values
            .where(
              (r) =>
                  r.parentRunId == parentRunId &&
                  (parentNodeId == null || r.parentNodeId == parentNodeId),
            )
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return Success(matches);
  }

  @override
  Future<Result<int>> countByStatusFinishedSince(
    RunStatus status, {
    required DateTime finishedSince,
  }) async {
    final cutoff = finishedSince.toUtc();
    return Success(
      runs.values.where((r) {
        final finishedAt = r.finishedAt;
        return r.status == status &&
            finishedAt != null &&
            !finishedAt.toUtc().isBefore(cutoff);
      }).length,
    );
  }

  @override
  Future<Result<Run>> updateStatus(
    String id, {
    required RunStatus status,
    DateTime? finishedAt,
    String? errorMessage,
    bool clearFinishedAt = false,
    bool clearErrorMessage = false,
  }) async {
    final run = runs[id];
    if (run == null) return FailureResult(NotFoundFailure('Run "$id".'));
    if (failingStatuses.contains(status)) {
      return const FailureResult(PersistenceFailure('disk full'));
    }
    statusHistory.add(status);
    return Success(
      runs[id] = run.copyWith(
        status: status,
        finishedAt: clearFinishedAt ? null : (finishedAt ?? run.finishedAt),
        errorMessage: clearErrorMessage
            ? null
            : (errorMessage ?? run.errorMessage),
      ),
    );
  }

  @override
  Future<Result<Run>> markInterruptedWithEvent(
    String runId, {
    required String eventId,
    required DateTime createdAt,
    JsonMap payload = const {},
  }) => updateStatus(runId, status: RunStatus.interrupted);

  @override
  Future<Result<Run>> markCancellationUncertainWithEvent(
    String runId, {
    required String eventId,
    required DateTime createdAt,
    JsonMap payload = const {},
  }) => updateStatus(runId, status: RunStatus.cancellationUncertain);

  @override
  Future<Result<List<String>>> delete(String id) async {
    final existing = runs[id];
    if (existing == null) {
      return FailureResult(NotFoundFailure('Run "$id" not found.'));
    }
    if (existing.status.isActive) {
      return FailureResult(
        ConflictFailure(
          'Cannot delete active run "$id" with status "${existing.status.name}".',
        ),
      );
    }
    final children = runs.values.where((r) => r.parentRunId == id).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    for (final child in children) {
      if (child.status.isActive) {
        return FailureResult(
          ConflictFailure(
            'Cannot delete run "$id": child run "${child.id}" is active '
            'with status "${child.status.name}".',
          ),
        );
      }
    }
    final ids = [for (final child in children) child.id, id];
    ids.forEach(runs.remove);
    return Success(ids);
  }

  @override
  Future<Result<List<String>>> deleteAllOfWorkflow(
    String workflowId, {
    String? workspaceId,
    Set<String> orphanIds = const {},
  }) async {
    final matching =
        runs.values
            .where(
              (r) =>
                  r.workflowId == workflowId &&
                  (workspaceId == null || r.workspaceId == workspaceId),
            )
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final kept = {
      for (final run in matching)
        if (orphanIds.contains(run.id)) run.id,
    };
    final deletedParentIds = {
      for (final run in matching)
        if (!kept.contains(run.id)) run.id,
    };
    final known = {for (final run in matching) run.id};
    final extraChildren =
        runs.values
            .where(
              (r) =>
                  r.parentRunId != null &&
                  deletedParentIds.contains(r.parentRunId) &&
                  !known.contains(r.id),
            )
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final keptChildren = {
      for (final child in extraChildren)
        if (orphanIds.contains(child.id)) child.id,
    };
    final activeRuns = <Run>[
      for (final run in matching)
        if (!kept.contains(run.id) && run.status.isActive) run,
      for (final child in extraChildren)
        if (!keptChildren.contains(child.id) && child.status.isActive) child,
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final active = <String, RunStatus>{
      for (final run in activeRuns) run.id: run.status,
    };
    if (active.isNotEmpty) {
      return FailureResult(
        WorkflowHasActiveRunsFailure(
          'Workflow "$workflowId" has ${active.length} active run(s). '
          'Stop them, then delete it again.',
          activeRuns: active,
        ),
      );
    }
    final ids = [
      for (final run in matching)
        if (!kept.contains(run.id)) run.id,
      for (final child in extraChildren)
        if (!keptChildren.contains(child.id)) child.id,
    ]..forEach(runs.remove);
    for (final id in kept) {
      final run = runs[id];
      if (run != null) {
        runs[id] = run.copyWith(workflowId: null);
      }
    }
    for (final id in keptChildren) {
      final run = runs[id];
      if (run != null) {
        runs[id] = run.copyWith(
          workflowId: null,
          parentRunId: null,
          parentNodeId: null,
        );
      }
    }
    return Success(ids);
  }
}

/// In-memory [CheckpointRepository] for engine tests.
final class InMemoryCheckpointRepository implements CheckpointRepository {
  /// Creates an empty repository.
  new();

  /// Stored checkpoints in append order.
  final List<Checkpoint> checkpoints = <Checkpoint>[];

  @override
  Future<Result<Checkpoint>> append({
    required String id,
    required String runId,
    required List<String> pendingNodeIds,
    required Map<String, int> attemptsByEdge,
    required int circuitBreakerCount,
    required Map<String, JsonMap> nodeOutputs,
    required DateTime createdAt,
    String? completedNodeId,
    int? sequence,
  }) async {
    final checkpoint = Checkpoint(
      id: id,
      runId: runId,
      sequence: checkpoints.where((c) => c.runId == runId).length + 1,
      pendingNodeIds: List<String>.of(pendingNodeIds),
      attemptsByEdge: Map<String, int>.of(attemptsByEdge),
      circuitBreakerCount: circuitBreakerCount,
      nodeOutputs: Map<String, JsonMap>.of(nodeOutputs),
      createdAt: createdAt,
      completedNodeId: completedNodeId,
    );
    checkpoints.add(checkpoint);
    return Success(checkpoint);
  }

  @override
  Future<Result<List<Checkpoint>>> listForRun(String runId) async =>
      Success(checkpoints.where((c) => c.runId == runId).toList());

  @override
  Future<Result<Checkpoint?>> getLatestForRun(String runId) async {
    final mine = checkpoints.where((c) => c.runId == runId);
    return Success(mine.isEmpty ? null : mine.last);
  }
}

/// In-memory [RunEventRepository] for engine tests.
///
/// Pages hold only [pageSize] events, like the real repository, so tests
/// exercise the engine's paging.
final class InMemoryRunEventRepository implements RunEventRepository {
  /// Creates an empty repository.
  new();

  /// Maximum events returned per `listForRun` call.
  static const int pageSize = 3;

  /// Stored events in append order.
  final List<RunEvent> events = <RunEvent>[];

  /// Called right after an event was stored.
  void Function(RunEvent event)? onAppend;

  /// The event types of [runId] in order.
  List<RunEventType> typesOf(String runId) =>
      events.where((e) => e.runId == runId).map((e) => e.type).toList();

  /// The events of [runId] with [type].
  List<RunEvent> ofType(String runId, RunEventType type) =>
      events.where((e) => e.runId == runId && e.type == type).toList();

  @override
  Future<Result<RunEvent>> append({
    required String id,
    required String runId,
    required RunEventType type,
    required DateTime createdAt,
    String? nodeId,
    String? edgeId,
    JsonMap payload = const {},
    int? sequence,
  }) async {
    final event = RunEvent(
      id: id,
      runId: runId,
      sequence: events.where((e) => e.runId == runId).length + 1,
      type: type,
      createdAt: createdAt,
      nodeId: nodeId,
      edgeId: edgeId,
      payload: payload,
    );
    events.add(event);
    onAppend?.call(event);
    return Success(event);
  }

  @override
  Future<Result<({List<RunEvent> items, int lastSequence})>> listForRun(
    String runId, {
    int? afterSequence,
    int? limit,
  }) async {
    final items = events
        .where(
          (e) =>
              e.runId == runId &&
              (afterSequence == null || e.sequence > afterSequence),
        )
        .take(limit ?? pageSize)
        .toList(growable: false);
    return Success((
      items: items,
      lastSequence: items.isEmpty ? (afterSequence ?? 0) : items.last.sequence,
    ));
  }

  @override
  Future<Result<Map<String, Map<String, DateTime>>>> findExecutingNodesForRuns(
    List<String> runIds,
  ) async {
    final runIdSet = runIds.toSet();
    final result = <String, Map<String, DateTime>>{};
    for (final event in events) {
      if (!runIdSet.contains(event.runId)) continue;
      final nodeId = event.nodeId;
      if (nodeId == null || nodeId.isEmpty) continue;
      if (event.type == RunEventType.nodeStarted) {
        result.putIfAbsent(event.runId, () => <String, DateTime>{})[nodeId] =
            event.createdAt;
      } else if (event.type == RunEventType.nodeCompleted ||
          event.type == RunEventType.nodeFailed) {
        result[event.runId]?.remove(nodeId);
      }
    }
    return Success(result);
  }
}

/// In-memory [PauseRepository] for unit tests.
final class InMemoryPauseRepository implements PauseRepository {
  /// Creates an in-memory pause repository.
  new();

  /// Stored pauses by id.
  final Map<String, Pause> pauses = <String, Pause>{};

  /// When non-null, [create] fails with this failure.
  Failure? createFailure;

  @override
  Future<Result<Pause>> create(Pause pause) async {
    if (createFailure != null) return FailureResult(createFailure!);
    if (pauses.containsKey(pause.id)) {
      return FailureResult(
        PersistenceFailure('Duplicate pause id "${pause.id}".'),
      );
    }
    pauses[pause.id] = pause;
    return Success(pause);
  }

  @override
  Future<Result<Pause>> getById(String id) async {
    final pause = pauses[id];
    if (pause == null) {
      return FailureResult(NotFoundFailure('Pause "$id" not found.'));
    }
    return Success(pause);
  }

  @override
  Future<Result<({List<Pause> items, int total})>> list({
    PauseStatus? status,
    String? runId,
    int limit = 50,
    int offset = 0,
  }) async {
    final filtered =
        pauses.values
            .where((p) => status == null || p.status == status)
            .where((p) => runId == null || p.runId == runId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return Success((
      items: filtered.skip(offset).take(limit).toList(growable: false),
      total: filtered.length,
    ));
  }

  @override
  Future<Result<List<Pause>>> listPendingForRun(String runId) async => Success(
    pauses.values
        .where((p) => p.runId == runId && p.status == PauseStatus.pending)
        .toList(growable: false),
  );

  @override
  Future<Result<Pause>> markAnswered(
    String id, {
    required DateTime answeredAt,
    String? decision,
    String? feedback,
    String? answer,
    Object? editedProposal,
  }) async {
    final existing = pauses[id];
    if (existing == null) {
      return FailureResult(NotFoundFailure('Pause "$id" not found.'));
    }
    if (existing.status != PauseStatus.pending) {
      return const FailureResult(
        ConflictFailure('This pause was already resolved or cancelled.'),
      );
    }
    final updated = existing.copyWith(
      status: PauseStatus.answered,
      decision: decision,
      feedback: feedback,
      answer: answer,
      editedProposal: editedProposal,
      answeredAt: answeredAt,
    );
    pauses[id] = updated;
    return Success(updated);
  }

  @override
  Future<Result<List<Pause>>> cancelPendingForRun(
    String runId, {
    required DateTime cancelledAt,
  }) async {
    final cancelled = <Pause>[];
    for (final entry in pauses.entries.toList()) {
      if (entry.value.runId == runId &&
          entry.value.status == PauseStatus.pending) {
        final updated = entry.value.copyWith(
          status: PauseStatus.cancelled,
          answeredAt: cancelledAt,
        );
        pauses[entry.key] = updated;
        cancelled.add(updated);
      }
    }
    return Success(cancelled);
  }

  @override
  Future<Result<List<Pause>>> cancelPendingForNode(
    String runId,
    String nodeId, {
    required DateTime cancelledAt,
  }) async {
    final cancelled = <Pause>[];
    for (final entry in pauses.entries.toList()) {
      if (entry.value.runId == runId &&
          entry.value.nodeId == nodeId &&
          entry.value.status == PauseStatus.pending) {
        final updated = entry.value.copyWith(
          status: PauseStatus.cancelled,
          answeredAt: cancelledAt,
        );
        pauses[entry.key] = updated;
        cancelled.add(updated);
      }
    }
    return Success(cancelled);
  }
}
