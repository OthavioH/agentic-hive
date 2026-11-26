import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// One workflow deletion (ADR 0027), as an immutable snapshot.
final class WorkflowDeletionOperation {
  /// Creates an operation snapshot.
  const new({
    required this.id,
    required this.workflowId,
    required this.phase,
    required this.startedAt,
    this.scope = const GlobalScope(),
    this.runsToStop = 0,
    this.runsStopped = 0,
    this.runsDeleted = 0,
    this.orphanedRuns = const [],
    this.outcome,
    this.failure,
    this.finishedAt,
  });

  /// Operation identifier.
  final String id;

  /// Workflow identifier.
  final String workflowId;

  /// Scope of the workflow being deleted.
  final DefinitionScope scope;

  /// Current phase.
  final WorkflowDeletionPhase phase;

  /// Number of active runs scheduled to stop.
  final int runsToStop;

  /// Number of active runs whose cancellation settled.
  final int runsStopped;

  /// Number of runs whose artifacts were cleaned.
  final int runsDeleted;

  /// Runs retained as orphans.
  final List<String> orphanedRuns;

  /// Final outcome, null while running.
  final WorkflowDeletionOutcome? outcome;

  /// Why the operation failed; null unless [outcome] is failed.
  final Failure? failure;

  /// Start time.
  final DateTime startedAt;

  /// Finish time, null while running.
  final DateTime? finishedAt;

  /// Whether the operation finished (deleted or failed).
  bool get isFinished => outcome != null;

  /// Copies this snapshot, retaining fields whose arguments are null.
  WorkflowDeletionOperation copyWith({
    WorkflowDeletionPhase? phase,
    int? runsToStop,
    int? runsStopped,
    int? runsDeleted,
    List<String>? orphanedRuns,
    WorkflowDeletionOutcome? outcome,
    Failure? failure,
    DateTime? finishedAt,
  }) => WorkflowDeletionOperation(
    id: id,
    workflowId: workflowId,
    scope: scope,
    phase: phase ?? this.phase,
    runsToStop: runsToStop ?? this.runsToStop,
    runsStopped: runsStopped ?? this.runsStopped,
    runsDeleted: runsDeleted ?? this.runsDeleted,
    orphanedRuns: orphanedRuns ?? this.orphanedRuns,
    outcome: outcome ?? this.outcome,
    failure: failure ?? this.failure,
    startedAt: startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
  );
}
