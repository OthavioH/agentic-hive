import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workflows/workflow_summary.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflows_changed_payload.freezed.dart';
part 'workflows_changed_payload.g.dart';

/// Kind of change reported in [WorkflowsChangedPayload].
enum WorkflowChangeKind {
  /// A new workspace workflow file appeared on disk.
  created,

  /// An existing workspace workflow file was modified on disk.
  updated,

  /// A workspace workflow file was removed from disk.
  deleted,
}

/// Payload of a `workflows.changed` WebSocket event.
///
/// [workspaceId] names the workspace whose workflow folder changed. [workflow]
/// is absent for a deletion.
@freezed
sealed class WorkflowsChangedPayload with _$WorkflowsChangedPayload {
  /// Creates a workflows-changed payload.
  const factory({
    required WorkflowChangeKind kind,
    required String id,
    required String workspaceId,
    WorkflowSummary? workflow,
  }) = _WorkflowsChangedPayload;

  /// Decodes a workflows-changed payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkflowsChangedPayloadFromJson);
}
