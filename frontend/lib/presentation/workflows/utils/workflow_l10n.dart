import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Maps workflow domain [Failure]s and [WorkflowValidationIssue] codes to
/// localized user-facing copy via [AppLocalizations].
abstract final class WorkflowL10n {
  /// Returns localized copy for a workflow [Failure] or arbitrary error object.
  static String localizeError(AppLocalizations l10n, Object? error) {
    if (error is Failure) {
      return localizeFailure(l10n, error);
    }
    return l10n.workflowsFailureUnexpected;
  }

  /// Returns localized copy for a typed [Failure].
  static String localizeFailure(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      NetworkFailure() => l10n.workflowsFailureNetwork,
      NotFoundFailure() => l10n.workflowsFailureNotFound,
      ValidationFailure() => l10n.workflowsFailureValidation,
      ConflictFailure() => l10n.workflowsFailureBackend,
      BackendFailure(code: ApiErrorCode.revisionConflict) =>
        l10n.editorRevisionConflictBadge,
      BackendFailure() => l10n.workflowsFailureBackend,
      UnexpectedFailure() => l10n.workflowsFailureUnexpected,
    };
  }

  /// Returns localized copy for a [WorkflowValidationIssue] given the current
  /// [workflow] graph.
  static String localizeValidationIssue(
    AppLocalizations l10n,
    WorkflowValidationIssue issue,
    Workflow workflow,
  ) {
    String resolveNodeLabel(String? nodeId) {
      if (nodeId == null) return '';
      for (final node in workflow.nodes) {
        if (node.id == nodeId) return node.label;
      }
      return nodeId;
    }

    WorkflowEdge? resolveEdge(String? edgeId) {
      if (edgeId == null) return null;
      for (final edge in workflow.edges) {
        if (edge.id == edgeId) return edge;
      }
      return null;
    }

    final edge = resolveEdge(issue.edgeId);
    final edgeId = issue.edgeId ?? '';

    return switch (issue.code) {
      WorkflowValidationCode.blankName => l10n.editorIssueBlankName,
      WorkflowValidationCode.emptyNodes => l10n.editorIssueEmptyNodes,
      WorkflowValidationCode.missingEntryNode =>
        l10n.editorIssueMissingEntryNode,
      WorkflowValidationCode.emptySourceOutput =>
        l10n.editorIssueEmptySourceOutput(edgeId),
      WorkflowValidationCode.orphanEdge => l10n.editorIssueOrphanEdge(edgeId),
      WorkflowValidationCode.duplicateEdge => l10n.editorIssueDuplicateEdge(
        resolveNodeLabel(edge?.sourceNodeId ?? issue.nodeId),
        edge?.sourceOutput ?? '',
        resolveNodeLabel(edge?.targetNodeId),
      ),
      WorkflowValidationCode.invalidMaxRetries =>
        l10n.editorIssueInvalidMaxRetries(edgeId),
      WorkflowValidationCode.unboundedCycle => l10n.editorIssueUnboundedCycle(
        resolveNodeLabel(edge?.sourceNodeId ?? issue.nodeId),
        resolveNodeLabel(edge?.targetNodeId),
      ),
      WorkflowValidationCode.unreachableNode => l10n.editorIssueUnreachableNode(
        resolveNodeLabel(issue.nodeId),
      ),
      WorkflowValidationCode.unknownNodeType => l10n.editorIssueUnknownNodeType(
        resolveNodeLabel(issue.nodeId),
      ),
      WorkflowValidationCode.invalidNodeConfig =>
        l10n.editorIssueInvalidNodeConfig(resolveNodeLabel(issue.nodeId)),
      _ => l10n.editorIssueUnknown(issue.code),
    };
  }
}
