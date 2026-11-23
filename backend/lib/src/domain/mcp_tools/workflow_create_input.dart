import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_auto_layout.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_node_ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// A validated create input ready to save.
final class WorkflowCreateDraft {
  /// Creates a validated draft.
  const new({
    required this.name,
    required this.description,
    required this.nodes,
    required this.edges,
    required this.entryNodeId,
    required this.autoPlaced,
  });

  /// Workflow name.
  final String name;

  /// Optional workflow description.
  final String? description;

  /// Nodes with positions resolved.
  final List<WorkflowNode> nodes;

  /// Workflow edges with generated ids.
  final List<WorkflowEdge> edges;

  /// Entry node id.
  final String entryNodeId;

  /// Count of nodes assigned an automatic position.
  final int autoPlaced;
}

/// Parses and validates create workflow arguments.
final class WorkflowCreateInputParser {
  /// Creates a parser using [describe] for known node type metadata.
  const new({required this.describe, this.layout = const WorkflowAutoLayout()});

  /// Resolves a node descriptor, or null when the type is unknown.
  final NodeDescriptor? Function(String typeId) describe;

  /// Layout engine used for nodes without positions.
  final WorkflowAutoLayout layout;

  /// Returns the first input problem or a validated draft.
  Result<WorkflowCreateDraft> parse(McpToolInput input) {
    final nameResult = input.requiredString(
      'name',
      missingMessage: 'Missing "name": pass a short workflow name.',
    );
    if (nameResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final name = (nameResult as Success<String>).value;
    final descriptionResult = input.optionalString('description');
    if (descriptionResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final description = (descriptionResult as Success<String?>).value;
    final rawNodes = input.arguments['nodes'];
    if (rawNodes is! List) {
      return _bad('"nodes" must be a list of node objects.');
    }
    final ids = <String, int>{};
    final rawParsed =
        <
          ({
            String id,
            String type,
            String label,
            JsonMap config,
            WorkflowPosition? position,
          })
        >[];
    for (var i = 0; i < rawNodes.length; i++) {
      final raw = rawNodes[i];
      if (raw is! Map) {
        return _bad('nodes[$i] must be an object with id, type and label.');
      }
      final map = Map<String, Object?>.from(raw);
      final id = map['id'];
      if (id is! String) return _bad('nodes[$i].id must be a string.');
      if (!WorkflowNodeIds.isValid(id)) {
        return _bad(
          'nodes[$i].id "$id" is not a valid node id: use 1-32 lowercase '
          'letters, digits or _, starting with a letter (for example review '
          'or fix_tests).',
        );
      }
      final prior = ids[id];
      if (prior != null) {
        return _bad(
          'nodes[$i].id "$id" is already used by nodes[$prior]; node ids '
          'must be unique.',
        );
      }
      ids[id] = i;
      final type = map['type'];
      if (type is! String || type.trim().isEmpty) {
        return _bad('nodes[$i].type must be a non-blank string.');
      }
      final label = map['label'];
      if (label is! String || label.trim().isEmpty) {
        return _bad('nodes[$i].label must be a non-blank string.');
      }
      final configRaw = map['config'];
      if (configRaw != null && configRaw is! Map) {
        return _bad('nodes[$i].config must be an object.');
      }
      final config = configRaw == null
          ? <String, Object?>{}
          : Map<String, Object?>.from(configRaw as Map);
      WorkflowPosition? position;
      final posRaw = map['position'];
      if (posRaw != null) {
        if (posRaw is! Map ||
            posRaw['x'] is! num ||
            posRaw['y'] is! num ||
            !(posRaw['x'] as num).isFinite ||
            !(posRaw['y'] as num).isFinite) {
          return _bad('nodes[$i].position must be {"x": number, "y": number}.');
        }
        position = WorkflowPosition(
          x: (posRaw['x']! as num).toDouble(),
          y: (posRaw['y']! as num).toDouble(),
        );
      }
      rawParsed.add((
        id: id,
        type: type.trim(),
        label: label.trim(),
        config: config,
        position: position,
      ));
    }
    final rawEdges = input.arguments['edges'];
    if (rawEdges is! List) {
      return _bad('"edges" must be a list of edge objects.');
    }
    final parsedEdges =
        <({String from, String to, String output, int? retries})>[];
    for (var i = 0; i < rawEdges.length; i++) {
      final raw = rawEdges[i];
      if (raw is! Map) {
        return _bad('edges[$i] must be an object with from, to and output.');
      }
      final map = Map<String, Object?>.from(raw);
      final from = map['from'];
      if (from is! String) return _bad('edges[$i].from must be a node id.');
      final to = map['to'];
      if (to is! String) return _bad('edges[$i].to must be a node id.');
      if (!ids.containsKey(from)) {
        return _bad('edges[$i].from "$from" is not a node id in "nodes".');
      }
      if (!ids.containsKey(to)) {
        return _bad('edges[$i].to "$to" is not a node id in "nodes".');
      }
      final output = map['output'];
      if (output is! String || output.trim().isEmpty) {
        return _bad('edges[$i].output must be a non-blank string.');
      }
      final source = rawParsed[ids[from]!];
      final descriptor = describe(source.type);
      if (descriptor != null && !descriptor.availableOutputs.contains(output)) {
        return _bad(
          'edges[$i].output "$output" is not an output of ${source.type} '
          '(node "$from"); use one of: '
          '${descriptor.availableOutputs.join(', ')}.',
        );
      }
      final retries = map['maxRetries'];
      if (retries != null && retries is! int) {
        return _bad('edges[$i].maxRetries must be an integer.');
      }
      parsedEdges.add((
        from: from,
        to: to,
        output: output,
        retries: retries as int?,
      ));
    }
    final entryResult = input.requiredString(
      'entryNodeId',
      missingMessage:
          'Missing "entryNodeId": pass the id of the node that runs first.',
    );
    if (entryResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final entry = (entryResult as Success<String>).value;
    if (!ids.containsKey(entry)) {
      return _bad('"entryNodeId" "$entry" is not a node id in "nodes".');
    }
    final positions = layout.layout(
      nodes: [
        for (final node in rawParsed)
          AutoLayoutNode(id: node.id, position: node.position),
      ],
      edges: [for (final edge in parsedEdges) (from: edge.from, to: edge.to)],
      entryNodeId: entry,
    );
    return Success(
      WorkflowCreateDraft(
        name: name,
        description: description,
        nodes: [
          for (final node in rawParsed)
            WorkflowNode(
              id: node.id,
              type: node.type,
              label: node.label,
              position: positions[node.id]!,
              config: {
                ...?describe(node.type)?.defaultConfig(),
                ...node.config,
              },
            ),
        ],
        edges: [
          for (var i = 0; i < parsedEdges.length; i++)
            WorkflowEdge(
              id: 'edge_${i + 1}',
              sourceNodeId: parsedEdges[i].from,
              sourceOutput: parsedEdges[i].output,
              targetNodeId: parsedEdges[i].to,
              maxRetries: parsedEdges[i].retries,
            ),
        ],
        entryNodeId: entry,
        autoPlaced: rawParsed.where((node) => node.position == null).length,
      ),
    );
  }

  FailureResult<WorkflowCreateDraft> _bad(String message) =>
      FailureResult(ValidationFailure(message));
}
