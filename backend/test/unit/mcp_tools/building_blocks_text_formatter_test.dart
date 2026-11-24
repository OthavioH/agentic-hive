import 'package:agentic_hive_backend/src/domain/mcp_tools/building_blocks_text_formatter.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

const _legend =
    'Node types (11). Config: * required, =a|b closed values, :int :bool '
    ':[string] :{string} :[{...}] types (default string).';

final _canonicalBlocks = <String>[
  [
    '- harness.claude_code -> onSuccess|onFailure\n',
    '  config: agentId, additionalInstructions, ',
    'workingDirectory, timeoutSeconds:int, model, ',
    'effort=low|medium|high|max, ',
    'extraArgs:[string]; set at least one of ',
    'agentId|additionalInstructions',
  ].join(),
  [
    '- harness.terminal -> onSuccess|onFailure\n',
    '  config: agentId, additionalInstructions, ',
    'workingDirectory, timeoutSeconds:int, ',
    'extraArgs:[string], command, args:[string], ',
    'sendPromptToStdin:bool; set at least one of ',
    'agentId|additionalInstructions|command',
  ].join(),
  [
    '- command -> onSuccess|onFailure\n',
    '  config: command*, args:[string], workingDirectory, ',
    'timeoutSeconds:int, env:{string}',
  ].join(),
  [
    '- validator.tests -> onSuccess|onFailure\n',
    '  config: command*, args:[string], workingDirectory, ',
    'timeoutSeconds:int',
  ].join(),
  [
    '- validator.checklist -> onSuccess|onFailure\n',
    '  config: rules*:[{label*, ',
    'kind*=fileExists|commandSucceeds|outputMatchesRegex, ',
    'path, command, workingDirectory, pattern}]',
  ].join(),
  [
    '- validator.review -> approved|changesRequested\n',
    '  config: ',
    'harnessType*=harness.claude_code|harness.codex|',
    'harness.gemini_cli|harness.antigravity, ',
    'agentId, reviewCriteria, timeoutSeconds:int; set at ',
    'least one of agentId|reviewCriteria',
  ].join(),
  [
    '- human_approval -> approved|rejected\n',
    '  config: instructions*, title, allowFeedback:bool, ',
    'proposalNodeId, proposalPath, proposalSchema',
  ].join(),
  [
    '- fan_out -> onSuccess|onFailure\n',
    '  config: workflowId*, itemsNodeId*, itemsPath*, inputField, ',
    'overridesField, nameField, concurrency:int, maxItems:int',
  ].join(),
];

AgentSummary _agent({
  required String id,
  required String name,
  AgentScope scope = AgentScope.global,
  String description = '',
}) => AgentSummary(
  id: id,
  name: name,
  contentHash: 'h',
  updatedAt: DateTime.utc(2026),
  description: description,
  scope: scope,
);

void main() {
  const formatter = BuildingBlocksTextFormatter();

  group('BuildingBlocksTextFormatter', () {
    test('T-F1 renders the canonical node types exactly', () {
      final out = formatter.format(
        nodeTypes: NodeDescriptors.all,
        agents: const [],
        brokenAgents: 0,
      );

      expect(out, startsWith('$_legend\n'));
      for (final block in _canonicalBlocks) {
        expect(out, contains(block));
      }
    });

    test('T-F4 harness blocks list model and effort only where supported', () {
      final out = formatter.format(
        nodeTypes: NodeDescriptors.all,
        agents: const [],
        brokenAgents: 0,
      );
      String blockFor(String typeId) {
        final start = out.indexOf('- $typeId ->');
        final next = out.indexOf('\n- ', start + 1);
        return next == -1 ? out.substring(start) : out.substring(start, next);
      }

      expect(
        blockFor(NodeTypeId.geminiCli),
        allOf(
          contains(', model, extraArgs:[string]'),
          isNot(contains('effort')),
        ),
      );
      expect(
        blockFor(NodeTypeId.codex),
        contains('effort=low|medium|high|max'),
      );
      expect(
        blockFor(NodeTypeId.antigravity),
        contains('effort=low|medium|high|max'),
      );
      expect(
        blockFor(NodeTypeId.terminal),
        allOf(isNot(contains('model')), isNot(contains('effort'))),
      );
    });

    test('T-F2 field without config shows none', () {
      final out = formatter.format(
        nodeTypes: [
          NodeDescriptor(
            typeId: 'test.echo',
            category: NodeCategory.execution,
            availableOutputs: ['onSuccess'],
            defaultConfig: () => <String, Object?>{},
            validateConfig: _noIssues,
            configFields: [],
          ),
        ],
        agents: const [],
        brokenAgents: 0,
      );

      expect(out, contains('- test.echo -> onSuccess\n  config: none'));
    });

    test('T-F3 agents: id, name, scope and truncated description', () {
      final long = 'x' * 81;
      final out = formatter.format(
        nodeTypes: const [],
        agents: [
          _agent(
            id: 'a',
            name: 'A',
            scope: AgentScope.workspace,
            description: long,
          ),
          _agent(id: 'b', name: 'B'),
        ],
        brokenAgents: 0,
      );

      expect(
        out,
        contains(
          'Agents (2; use the id as config.agentId):\n'
          '- a "A" (workspace): ${'x' * 77}...\n'
          '- b "B" (global)',
        ),
      );
    });

    test('T-F4 no agents', () {
      final out = formatter.format(
        nodeTypes: NodeDescriptors.all,
        agents: const [],
        brokenAgents: 0,
      );

      expect(out, endsWith('Agents: none in this scope.'));
    });

    test('T-F5 broken agents count', () {
      final one = formatter.format(
        nodeTypes: const [],
        agents: const [],
        brokenAgents: 1,
      );
      final two = formatter.format(
        nodeTypes: const [],
        agents: const [],
        brokenAgents: 2,
      );

      expect(one, endsWith('1 agent with file errors omitted.'));
      expect(two, endsWith('2 agents with file errors omitted.'));
    });
  });
}

List<NodeConfigIssue> _noIssues(JsonMap config) => const [];
