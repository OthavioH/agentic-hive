import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workflow_validation.freezed.dart';
part 'workflow_validation.g.dart';

/// Machine-readable codes for [WorkflowValidationIssue].
abstract final class WorkflowValidationCode {
  /// Workflow name is blank.
  static const String blankName = 'blank_name';

  /// Workflow has no nodes.
  static const String emptyNodes = 'empty_nodes';

  /// `entryNodeId` is missing or does not reference an existing node.
  static const String missingEntryNode = 'missing_entry_node';

  /// An edge has a blank `sourceOutput`.
  static const String emptySourceOutput = 'empty_source_output';

  /// An edge references a missing source or target node.
  static const String orphanEdge = 'orphan_edge';

  /// Multiple edges share `(sourceNodeId, sourceOutput, targetNodeId)`.
  static const String duplicateEdge = 'duplicate_edge';

  /// An edge specifies `maxRetries <= 0`.
  static const String invalidMaxRetries = 'invalid_max_retries';

  /// A directed cycle contains no edge with `maxRetries > 0`.
  static const String unboundedCycle = 'unbounded_cycle';

  /// A node cannot be reached from `entryNodeId`.
  static const String unreachableNode = 'unreachable_node';

  /// A node specifies a `type` not registered in the node catalog.
  static const String unknownNodeType = 'unknown_node_type';

  /// A node's `config` failed validation for its node type.
  static const String invalidNodeConfig = 'invalid_node_config';
}

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
