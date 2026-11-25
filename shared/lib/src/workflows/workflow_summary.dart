import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workflows/workflow_scope.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow_summary.freezed.dart';
part 'workflow_summary.g.dart';

/// Lightweight summary of a saved workflow for list views.
@freezed
sealed class WorkflowSummary with _$WorkflowSummary {
  /// Creates a workflow summary.
  const factory({
    required String id,
    required String name,
    required int nodeCount,
    required int edgeCount,
    required bool hasValidationErrors,
    required DateTime updatedAt,
    String? description,
    @Default(WorkflowScope.global) WorkflowScope scope,
    String? workspaceId,

    /// Content hash of the workflow definition for optimistic concurrency;
    /// always set by the backend.
    String? revision,

    /// Whether a deletion operation is running for this workflow (ADR 0027);
    /// derived by the backend, never stored.
    @Default(false) bool deleting,
  }) = _WorkflowSummary;

  /// Decodes a workflow summary; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WorkflowSummaryFromJson);
}
