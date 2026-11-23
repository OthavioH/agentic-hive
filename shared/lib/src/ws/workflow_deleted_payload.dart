import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow_deleted_payload.freezed.dart';
part 'workflow_deleted_payload.g.dart';

/// Successful workflow deletion event payload.
@freezed
sealed class WorkflowDeletedPayload with _$WorkflowDeletedPayload {
  /// Creates a successful deletion payload.
  const factory({
    required String operationId,
    required String workflowId,
    required int deletedRuns,
    String? workspaceId,
    @Default(<String>[]) List<String> orphanedRuns,
  }) = _WorkflowDeletedPayload;

  /// Decodes a payload; throws [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkflowDeletedPayloadFromJson);
}
