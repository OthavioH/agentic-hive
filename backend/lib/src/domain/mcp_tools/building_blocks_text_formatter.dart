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

  /// Formats node types, listed agents and the count of omitted broken agents.
  String format({
    required List<NodeDescriptor> nodeTypes,
    required List<AgentSummary> agents,
    required int brokenAgents,
  }) {
    final lines = <String>[
      'Node types (${nodeTypes.length}). $_legendTail',
      for (final node in nodeTypes) ..._nodeLines(node),
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
