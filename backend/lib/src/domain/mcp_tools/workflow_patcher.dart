import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_auto_layout.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_edit_copy.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_edit_operations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// The result of applying `edit_workflow` operations to a workflow.
final class WorkflowPatch {
  /// Creates the result of applying a patch.
  const new({
    required this.name,
    required this.description,
    required this.nodes,
    required this.edges,
    required this.entryNodeId,
    required this.tally,
    required this.operationCount,
  });

  /// Workflow name.
  final String name;

  /// Optional workflow description.
  final String? description;

  /// Resulting workflow nodes.
  final List<WorkflowNode> nodes;

  /// Resulting workflow edges.
  final List<WorkflowEdge> edges;

  /// Resulting entry node.
  final String? entryNodeId;

  /// Patch tally.
  final WorkflowEditTally tally;

  /// Number of operations applied.
  final int operationCount;
}

/// Applies edit operations as one transaction on an in-memory copy (B4/B5/B7).
final class WorkflowPatcher {
  /// Creates a patcher with descriptor lookup and an optional layout engine.
  new({
    required NodeDescriptor? Function(String typeId) describe,
    this._layout = const WorkflowAutoLayout(),
  }) : _operations = {
         for (final operation in <WorkflowEditOperation>[
           AddNodeOperation(describe),
           const UpdateNodeOperation(),
           const RemoveNodeOperation(),
           ConnectOperation(describe),
           const DisconnectOperation(),
           const SetEntryOperation(),
           const SetMetaOperation(),
         ])
           operation.name: operation,
       };

  final WorkflowAutoLayout _layout;
  final Map<String, WorkflowEditOperation> _operations;

  /// Operation names in the order used by error messages.
  List<String> get operationNames => _operations.keys.toList();

  /// Applies [operations] to [workflow], leaving [workflow] unchanged.
  Result<WorkflowPatch> apply(Workflow workflow, List<Object?> operations) {
    final copy = WorkflowEditCopy.of(workflow);
    final names = operationNames.join(', ');
    for (var i = 0; i < operations.length; i++) {
      final raw = operations[i];
      if (raw is! Map) {
        return FailureResult(
          ValidationFailure(
            'operations[$i] must be an object with an "op" field. '
            'Nothing was applied.',
          ),
        );
      }
      final args = Map<String, Object?>.from(raw);
      final opName = args['op'];
      if (opName is! String) {
        return FailureResult(
          ValidationFailure(
            'operations[$i].op is missing; use one of: $names. '
            'Nothing was applied.',
          ),
        );
      }
      final operation = _operations[opName];
      if (operation == null) {
        return FailureResult(
          ValidationFailure(
            'operations[$i].op "$opName" is not an operation; use one of: '
            '$names. Nothing was applied.',
          ),
        );
      }
      final result = operation.apply(args, copy);
      if (result case FailureResult(:final failure)) {
        return FailureResult(
          ValidationFailure(
            'operations[$i] $opName: ${failure.message} Nothing was applied.',
          ),
        );
      }
    }
    if (copy.autoPlace.isNotEmpty) {
      final positions = _layout.layout(
        nodes: [
          for (final node in copy.nodes)
            AutoLayoutNode(
              id: node.id,
              position: copy.autoPlace.contains(node.id) ? null : node.position,
            ),
        ],
        edges: [
          for (final edge in copy.edges)
            (from: edge.sourceNodeId, to: edge.targetNodeId),
        ],
        entryNodeId: copy.entryNodeId,
      );
      for (var i = 0; i < copy.nodes.length; i++) {
        final node = copy.nodes[i];
        if (copy.autoPlace.contains(node.id)) {
          copy.nodes[i] = node.copyWith(position: positions[node.id]!);
        }
      }
    }
    return Success(
      WorkflowPatch(
        name: copy.name,
        description: copy.description,
        nodes: copy.nodes,
        edges: copy.edges,
        entryNodeId: copy.entryNodeId,
        tally: copy.tally,
        operationCount: operations.length,
      ),
    );
  }
}
