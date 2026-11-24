import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Formats the `list_building_blocks` body as compact text (#108, §3.3).
final class BuildingBlocksTextFormatter {
  /// Creates a [BuildingBlocksTextFormatter].
  const new();

  static const int _maxDescriptionLength = 80;

  static final String _legendTail = [
    'Config: * required, =a|b closed values,',
    ':int :bool :[string] :{string} :[{...}] types (default string).',
  ].join(' ');

  static const String _fanOut1 =
      'Fan-out (fan_out): starts one child run of the saved workflow '
      'workflowId for each item of the list at itemsPath in the output of '
      'the earlier node itemsNodeId, and waits for all of them.';
  static const String _fanOut2 =
      '  The child workflow is resolved in the workspace first, then global; '
      'it must not contain a fan_out node.';
  static const String _fanOut3 =
      '  Without inputField the whole item is the child input; inputField, '
      'nameField and overridesField are dot paths inside each item '
      '(nameField names the worktree).';
  static const String _fanOut4 =
      '  overridesField points to an object {"<child node id>": {agentId?, '
      'model?, effort?}} that overrides those settings of the child '
      'workflow nodes for that child only; the node type (harness) stays '
      'fixed.';
  static const String _fanOut5 =
      '  concurrency (default 2) children run at once; more than maxItems '
      '(default 20) items fails the node. onSuccess only if every child '
      'succeeded, else onFailure.';

  /// Notes printed when the fan-out node type is listed (ADR 0029).
  static const List<String> fanOutNotes = [
    _fanOut1,
    _fanOut2,
    _fanOut3,
    _fanOut4,
    _fanOut5,
  ];

  /// Formats node types, listed agents and the count of omitted broken agents.
  String format({
    required List<NodeDescriptor> nodeTypes,
    required List<AgentSummary> agents,
    required int brokenAgents,
  }) {
    final lines = <String>[
      'Node types (${nodeTypes.length}). $_legendTail',
      for (final node in nodeTypes) ..._nodeLines(node),
      if (nodeTypes.any((node) => node.typeId == NodeTypeId.fanOut))
        ...fanOutNotes,
      if (agents.isEmpty)
        'Agents: none in this scope.'
      else ...[
        'Agents (${agents.length}; use the id as config.agentId):',
        for (final agent in agents) _agentLine(agent),
      ],
      if (brokenAgents == 1)
        '1 agent with file errors omitted.'
      else if (brokenAgents > 1)
        '$brokenAgents agents with file errors omitted.',
    ];
    return lines.join('\n');
  }

  List<String> _nodeLines(NodeDescriptor node) {
    final configLine = node.configFields.isEmpty
        ? '  config: none'
        : '  config: ${node.configFields.map(_field).join(', ')}'
              '${node.requiredOneOf.isEmpty ? '' : '; set at least one of '
                        '${node.requiredOneOf.join('|')}'}';
    return [
      '- ${node.typeId} -> ${node.availableOutputs.join('|')}',
      configLine,
    ];
  }

  String _field(NodeConfigField field) {
    final closed = field.values.isEmpty ? '' : '=${field.values.join('|')}';
    return '${field.name}${field.required ? '*' : ''}'
        '${_kindSuffix(field)}$closed';
  }

  String _kindSuffix(NodeConfigField field) => switch (field.kind) {
    NodeConfigFieldKind.string => '',
    NodeConfigFieldKind.integer => ':int',
    NodeConfigFieldKind.boolean => ':bool',
    NodeConfigFieldKind.stringList => ':[string]',
    NodeConfigFieldKind.stringMap => ':{string}',
    NodeConfigFieldKind.objectList =>
      ':[{${field.itemFields.map(_field).join(', ')}}]',
  };

  String _agentLine(AgentSummary agent) {
    final description = agent.description.trim();
    final suffix = description.isEmpty ? '' : ': ${_truncate(description)}';
    return '- ${agent.id} "${agent.name}" (${agent.scope.name})$suffix';
  }

  String _truncate(String text) => text.length > _maxDescriptionLength
      ? '${text.substring(0, _maxDescriptionLength - 3)}...'
      : text;
}
