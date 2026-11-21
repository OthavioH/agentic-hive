import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow_validation.freezed.dart';
part 'workflow_validation.g.dart';

/// Severity of a [WorkflowValidationIssue].
enum WorkflowValidationSeverity {
  /// Blocks execution of the workflow, though drafts may still be saved.
  error,

  /// Advisory diagnostic that does not block execution.
  warning,
}

/// A single diagnostic produced by validating a workflow graph.
@freezed
sealed class WorkflowValidationIssue with _$WorkflowValidationIssue {
  /// Creates a validation issue.
  const factory({
    required WorkflowValidationSeverity severity,
    required String code,
    required String message,
    String? nodeId,
    String? edgeId,
  }) = _WorkflowValidationIssue;

  /// Decodes a validation issue; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkflowValidationIssueFromJson);
}

/// Outcome of validating a workflow graph.
@freezed
sealed class WorkflowValidationResult with _$WorkflowValidationResult {
  /// Creates a validation result.
  const factory({
    required bool isValid,
    @Default(<WorkflowValidationIssue>[]) List<WorkflowValidationIssue> issues,
  }) = _WorkflowValidationResult;

  /// Decodes a validation result; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkflowValidationResultFromJson);
}
