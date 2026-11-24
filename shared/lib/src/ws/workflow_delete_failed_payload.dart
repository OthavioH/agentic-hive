import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow_delete_failed_payload.freezed.dart';
part 'workflow_delete_failed_payload.g.dart';

/// Failed workflow deletion event payload.
@freezed
sealed class WorkflowDeleteFailedPayload with _$WorkflowDeleteFailedPayload {
  /// Creates a failed deletion payload.
  const factory({
    required String operationId,
    required String workflowId,
    required String code,
    required String message,
    String? workspaceId,
    @Default(0) int deletedRuns,
    @Default(<String>[]) List<String> orphanedRuns,
  }) = _WorkflowDeleteFailedPayload;

  /// Decodes a payload; throws [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkflowDeleteFailedPayloadFromJson);
}
