import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow_deletion.freezed.dart';
part 'workflow_deletion.g.dart';

/// Current phase of an asynchronous workflow deletion (ADR 0027).
enum WorkflowDeletionPhase {
  /// Active runs are being stopped.
  @JsonValue('stopping_runs')
  stoppingRuns,

  /// Runs and their artifacts are being removed.
  @JsonValue('deleting_runs')
  deletingRuns,

  /// The operation has completed.
  @JsonValue('done')
  done,
}

/// Final outcome of a workflow deletion.
enum WorkflowDeletionOutcome {
  /// The workflow was deleted.
  @JsonValue('deleted')
  deleted,

  /// The deletion failed.
  @JsonValue('failed')
  failed,
}

/// Response body of `DELETE /api/v1/workflows/:id` (`202`, ADR 0027).
@freezed
sealed class WorkflowDeletionAccepted with _$WorkflowDeletionAccepted {
  /// Creates an accepted workflow deletion response.
  const factory({required String operationId, required String workflowId}) =
      _WorkflowDeletionAccepted;

  /// Decodes a response; throws [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkflowDeletionAcceptedFromJson);
}

/// Body of the workflow deletion status endpoint and progress event.
@freezed
sealed class WorkflowDeletionStatus with _$WorkflowDeletionStatus {
  /// Creates an operation status snapshot.
  const factory({
    required String operationId,
    required String workflowId,
    required WorkflowDeletionPhase phase,
    required DateTime startedAt,
    String? workspaceId,
    @Default(0) int runsToStop,
    @Default(0) int runsStopped,
    @Default(0) int runsDeleted,
    @Default(<String>[]) List<String> orphanedRuns,
    WorkflowDeletionOutcome? outcome,
    String? errorCode,
    String? errorMessage,
    DateTime? finishedAt,
  }) = _WorkflowDeletionStatus;

  /// Decodes a status; throws [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkflowDeletionStatusFromJson);
}
