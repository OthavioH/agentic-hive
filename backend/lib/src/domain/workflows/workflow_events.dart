import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Publishes workflow changes so clients can keep their view live.
abstract interface class WorkflowEvents {
  /// Reports that workflow [id] changed in [scope].
  void workflowChanged(
    WorkflowChangeKind kind,
    String id, {
    DefinitionScope scope = const GlobalScope(),
    WorkflowSummary? workflow,
  });
}

/// Builds a list summary for a saved workflow [response].
WorkflowSummary workflowSummaryOf(WorkflowResponse response) => WorkflowSummary(
  id: response.workflow.id,
  name: response.workflow.name,
  description: response.workflow.description,
  nodeCount: response.workflow.nodes.length,
  edgeCount: response.workflow.edges.length,
  hasValidationErrors: !response.validation.isValid,
  updatedAt: response.workflow.updatedAt,
  scope: response.scope,
  revision: response.revision,
);
