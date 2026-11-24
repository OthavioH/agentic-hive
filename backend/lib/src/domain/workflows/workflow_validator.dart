import 'dart:collection';

import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

export 'package:agentic_hive_shared/agentic_hive_shared.dart'
    show WorkflowValidationCode;

enum _VisitState { unvisited, visiting, visited }

/// Pure-Dart domain service that validates a [Workflow] graph.
final class WorkflowValidator {
  /// Creates a workflow validator.
  ///
  /// When [_nodeRegistry] is provided, node types and configs are validated
  /// against registered descriptors; otherwise falls back to the shared
  /// [NodeDescriptors] catalog.
  const new({this._nodeRegistry});

  final NodeRegistry? _nodeRegistry;

  /// Validates [workflow] against all structural and safety rules.
  WorkflowValidationResult validate(Workflow workflow) {
    final issues = <WorkflowValidationIssue>[];

    if (workflow.name.trim().isEmpty) {
      issues.add(
        const WorkflowValidationIssue(
          severity: WorkflowValidationSeverity.error,
          code: WorkflowValidationCode.blankName,
          message: 'Workflow name must not be blank.',
        ),
      );
    }

    if (workflow.nodes.isEmpty) {
      issues.add(
        const WorkflowValidationIssue(
          severity: WorkflowValidationSeverity.error,
          code: WorkflowValidationCode.emptyNodes,
          message: 'Workflow must contain at least one node.',
        ),
      );
    }

    final nodeIds = {for (final node in workflow.nodes) node.id};
    final entryNodeId = workflow.entryNodeId;
    if (entryNodeId == null ||
        entryNodeId.isEmpty ||
        !nodeIds.contains(entryNodeId)) {
      issues.add(
        WorkflowValidationIssue(
          severity: WorkflowValidationSeverity.error,
          code: WorkflowValidationCode.missingEntryNode,
          message: 'Workflow must have a valid entryNodeId.',
          nodeId: entryNodeId,
        ),
      );
    }

    final seenEdges = <(String, String, String)>{};
    final validEdges = <WorkflowEdge>[];

    for (final edge in workflow.edges) {
      if (edge.sourceOutput.trim().isEmpty) {
        issues.add(
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.error,
            code: WorkflowValidationCode.emptySourceOutput,
            message: 'Edge "${edge.id}" must have a non-empty sourceOutput.',
            nodeId: edge.sourceNodeId,
            edgeId: edge.id,
          ),
        );
      }

      final hasValidEndpoints =
          nodeIds.contains(edge.sourceNodeId) &&
          nodeIds.contains(edge.targetNodeId);
      if (!hasValidEndpoints) {
        issues.add(
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.error,
            code: WorkflowValidationCode.orphanEdge,
            message:
                'Edge "${edge.id}" references a missing source or target node.',
            edgeId: edge.id,
          ),
        );
      } else {
        validEdges.add(edge);
      }

      final key = (edge.sourceNodeId, edge.sourceOutput, edge.targetNodeId);
      if (!seenEdges.add(key)) {
        issues.add(
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.error,
            code: WorkflowValidationCode.duplicateEdge,
            message:
                'Duplicate edge from "${edge.sourceNodeId}" '
                '(${edge.sourceOutput}) to "${edge.targetNodeId}".',
            nodeId: edge.sourceNodeId,
            edgeId: edge.id,
          ),
        );
      }

      final maxRetries = edge.maxRetries;
      if (maxRetries != null && maxRetries <= 0) {
        issues.add(
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.error,
            code: WorkflowValidationCode.invalidMaxRetries,
            message: 'Edge "${edge.id}" maxRetries must be greater than 0.',
            nodeId: edge.sourceNodeId,
            edgeId: edge.id,
          ),
        );
      }
    }

    _validateNodes(workflow.nodes, issues);
    _detectUnboundedCycles(workflow.nodes, validEdges, issues);
    _detectUnreachableNodes(workflow.nodes, validEdges, entryNodeId, issues);

    final isValid = !issues.any(
      (issue) => issue.severity == WorkflowValidationSeverity.error,
    );
    return WorkflowValidationResult(isValid: isValid, issues: issues);
  }

  void _validateNodes(
    List<WorkflowNode> nodes,
    List<WorkflowValidationIssue> issues,
  ) {
    final nodeIds = {for (final node in nodes) node.id};
    for (final node in nodes) {
      final descriptor = _nodeRegistry != null
          ? _nodeRegistry.descriptorFor(node.type)
          : NodeDescriptors.of(node.type);
      if (descriptor == null) {
        issues.add(
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.error,
            code: WorkflowValidationCode.unknownNodeType,
            message: 'Unknown node type "${node.type}".',
            nodeId: node.id,
          ),
        );
        continue;
      }

      for (final configIssue in descriptor.validateConfig(node.config)) {
        issues.add(
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.error,
            code: WorkflowValidationCode.invalidNodeConfig,
            message: '${configIssue.field}: ${configIssue.message}',
            nodeId: node.id,
          ),
        );
      }

      if (node.type == NodeTypeId.humanApproval) {
        _validateProposalSource(node, nodeIds, issues);
      }
    }
  }

  void _validateProposalSource(
    WorkflowNode node,
    Set<String> nodeIds,
    List<WorkflowValidationIssue> issues,
  ) {
    final raw = node.config['proposalNodeId'];
    if (raw is! String) return;
    final proposalNodeId = raw.trim();
    if (proposalNodeId.isEmpty) return;

    if (proposalNodeId == node.id) {
      issues.add(
        WorkflowValidationIssue(
          severity: WorkflowValidationSeverity.error,
          code: WorkflowValidationCode.invalidNodeConfig,
          message: 'proposalNodeId: Must not be the approval node itself.',
          nodeId: node.id,
        ),
      );
    } else if (!nodeIds.contains(proposalNodeId)) {
      issues.add(
        WorkflowValidationIssue(
          severity: WorkflowValidationSeverity.error,
          code: WorkflowValidationCode.invalidNodeConfig,
          message:
              'proposalNodeId: Node "$proposalNodeId" does not exist in this '
              'workflow.',
          nodeId: node.id,
        ),
      );
    }
  }

  void _detectUnboundedCycles(
    List<WorkflowNode> nodes,
    List<WorkflowEdge> validEdges,
    List<WorkflowValidationIssue> issues,
  ) {
    final unboundedAdj = <String, List<WorkflowEdge>>{};
    for (final edge in validEdges) {
      final maxRetries = edge.maxRetries;
      if (maxRetries == null || maxRetries <= 0) {
        (unboundedAdj[edge.sourceNodeId] ??= []).add(edge);
      }
    }

    final state = <String, _VisitState>{
      for (final node in nodes) node.id: _VisitState.unvisited,
    };

    void dfs(String nodeId) {
      state[nodeId] = _VisitState.visiting;
      for (final edge in unboundedAdj[nodeId] ?? const <WorkflowEdge>[]) {
        final targetState = state[edge.targetNodeId];
        if (targetState == _VisitState.visiting) {
          issues.add(
            WorkflowValidationIssue(
              severity: WorkflowValidationSeverity.error,
              code: WorkflowValidationCode.unboundedCycle,
              message:
                  'Cycle involving "${edge.sourceNodeId}" -> '
                  '"${edge.targetNodeId}" requires at least one edge with '
                  'maxRetries > 0.',
              nodeId: edge.sourceNodeId,
              edgeId: edge.id,
            ),
          );
        } else if (targetState == _VisitState.unvisited) {
          dfs(edge.targetNodeId);
        }
      }
      state[nodeId] = _VisitState.visited;
    }

    for (final node in nodes) {
      if (state[node.id] == _VisitState.unvisited) {
        dfs(node.id);
      }
    }
  }

  void _detectUnreachableNodes(
    List<WorkflowNode> nodes,
    List<WorkflowEdge> validEdges,
    String? entryNodeId,
    List<WorkflowValidationIssue> issues,
  ) {
    if (entryNodeId == null || !nodes.any((n) => n.id == entryNodeId)) {
      return;
    }

    final adj = <String, List<String>>{};
    for (final edge in validEdges) {
      (adj[edge.sourceNodeId] ??= []).add(edge.targetNodeId);
    }

    final visited = <String>{entryNodeId};
    final queue = Queue<String>()..add(entryNodeId);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final next in adj[current] ?? const <String>[]) {
        if (visited.add(next)) {
          queue.add(next);
        }
      }
    }

    for (final node in nodes) {
      if (!visited.contains(node.id)) {
        issues.add(
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.warning,
            code: WorkflowValidationCode.unreachableNode,
            message:
                'Node "${node.label}" is not reachable from the entry node.',
            nodeId: node.id,
          ),
        );
      }
    }
  }
}
