import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
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
  Future<Result<void>> delete(String id) async {
    runs.remove(id);
    return const Success(null);
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
}
