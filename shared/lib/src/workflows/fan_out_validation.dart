import 'package:agentic_hive_shared/src/nodes/node_category.dart';
import 'package:agentic_hive_shared/src/nodes/node_config_validation.dart';
import 'package:agentic_hive_shared/src/workflows/workflow.dart';
import 'package:agentic_hive_shared/src/workflows/workflow_validation.dart';

/// Resolves a saved workflow by id, or returns null when it does not resolve.
typedef WorkflowFinder = Workflow? Function(String workflowId);

/// Validates fan-out node references within a [Workflow].
abstract final class FanOutValidation {
  /// Validates the fan-out nodes of [workflow] (R13).
  static List<WorkflowValidationIssue> validate(
    Workflow workflow, {
    required WorkflowFinder findWorkflow,
  }) {
    final issues = <WorkflowValidationIssue>[];
    final nodeIds = {for (final n in workflow.nodes) n.id};

    for (final node in workflow.nodes) {
      if (node.type != NodeTypeId.fanOut) {
        continue;
      }

      final rawItemsNodeId = node.config['itemsNodeId'];
      final itemsNodeId = rawItemsNodeId is String
          ? rawItemsNodeId.trim()
          : null;
      if (!isBlank(itemsNodeId)) {
        if (itemsNodeId == node.id) {
          issues.add(
            WorkflowValidationIssue(
              severity: WorkflowValidationSeverity.error,
              code: WorkflowValidationCode.invalidNodeConfig,
              message: 'itemsNodeId: Must not be the fan-out node itself.',
              nodeId: node.id,
            ),
          );
        } else if (!nodeIds.contains(itemsNodeId)) {
          issues.add(
            WorkflowValidationIssue(
              severity: WorkflowValidationSeverity.error,
              code: WorkflowValidationCode.invalidNodeConfig,
              message:
                  'itemsNodeId: Node "$itemsNodeId" does not exist in this '
                  'workflow.',
              nodeId: node.id,
            ),
          );
        }
      }

      final rawWorkflowId = node.config['workflowId'];
      final workflowId = rawWorkflowId is String ? rawWorkflowId.trim() : null;
      if (isBlank(workflowId)) {
        continue;
      }

      final child = findWorkflow(workflowId!);
      if (child == null) {
        issues.add(
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.warning,
            code: WorkflowValidationCode.unresolvedChildWorkflow,
            message: 'Child workflow "$workflowId" does not resolve.',
            nodeId: node.id,
          ),
        );
        continue;
      }

      if (_hasFanOut(child)) {
        issues.add(
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.error,
            code: WorkflowValidationCode.nestedFanOut,
            message:
                'Child workflow "${child.name}" contains a fan-out node; '
                'nested fan-out is not supported.',
            nodeId: node.id,
          ),
        );
      }
    }

    return issues;
  }

  static bool _hasFanOut(Workflow workflow) =>
      workflow.nodes.any((n) => n.type == NodeTypeId.fanOut);
}
