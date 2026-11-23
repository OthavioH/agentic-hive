import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

WorkflowNode _node(
  String id, {
  String label = '',
  String type = NodeTypeId.command,
  JsonMap config = const {'command': 'echo ok'},
}) => WorkflowNode(
  id: id,
  type: type,
  label: label.isEmpty ? id : label,
  position: const WorkflowPosition(x: 0, y: 0),
  config: config,
);

WorkflowEdge _edge(
  String id,
  String source,
  String target, {
  String output = 'onSuccess',
  int? maxRetries,
}) => WorkflowEdge(
  id: id,
  sourceNodeId: source,
  sourceOutput: output,
  targetNodeId: target,
  maxRetries: maxRetries,
);

Workflow _workflow({
  String name = 'Test Workflow',
  List<WorkflowNode>? nodes,
  List<WorkflowEdge> edges = const [],
  String? entryNodeId = 'n1',
}) => Workflow(
  id: 'wf-1',
  name: name,
  nodes: nodes ?? [_node('n1')],
  edges: edges,
  entryNodeId: entryNodeId,
  createdAt: DateTime.utc(2026, 11, 20),
  updatedAt: DateTime.utc(2026, 11, 20),
);

void main() {
  const validator = WorkflowValidator();

  group('WorkflowValidator', () {
    test('accepts a valid linear workflow', () {
      final wf = _workflow(
        nodes: [_node('n1'), _node('n2')],
        edges: [_edge('e1', 'n1', 'n2')],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test(
      'accepts parallel fan-out from the same (sourceNodeId, sourceOutput)',
      () {
        final wf = _workflow(
          nodes: [_node('n1'), _node('n2'), _node('n3')],
          edges: [_edge('e1', 'n1', 'n2'), _edge('e2', 'n1', 'n3')],
        );

        final result = validator.validate(wf);

        expect(result.isValid, isTrue);
        expect(result.issues, isEmpty);
      },
    );

    test('accepts a self-loop when maxRetries > 0', () {
      final wf = _workflow(
        nodes: [_node('n1')],
        edges: [_edge('e1', 'n1', 'n1', output: 'onFailure', maxRetries: 2)],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test(
      'accepts a multi-node cycle when at least one edge has maxRetries > 0',
      () {
        final wf = _workflow(
          nodes: [_node('n1'), _node('n2'), _node('n3')],
          edges: [
            _edge('e1', 'n1', 'n2'),
            _edge('e2', 'n2', 'n3'),
            _edge('e3', 'n3', 'n1', output: 'onFailure', maxRetries: 1),
          ],
        );

        final result = validator.validate(wf);

        expect(result.isValid, isTrue);
        expect(result.issues, isEmpty);
      },
    );

    test('reports error for blank workflow name', () {
      final wf = _workflow(name: '   ');

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      expect(
        result.issues.map((i) => i.code),
        contains(WorkflowValidationCode.blankName),
      );
    });

    test('reports error for empty nodes list', () {
      final wf = _workflow(nodes: const [], entryNodeId: null);

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      expect(
        result.issues.map((i) => i.code),
        containsAll([
          WorkflowValidationCode.emptyNodes,
          WorkflowValidationCode.missingEntryNode,
        ]),
      );
    });

    test('reports error for missing or non-existent entryNodeId', () {
      final wf = _workflow(entryNodeId: 'missing');

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      expect(
        result.issues.map((i) => i.code),
        contains(WorkflowValidationCode.missingEntryNode),
      );
    });

    test('reports error for empty sourceOutput', () {
      final wf = _workflow(
        nodes: [_node('n1'), _node('n2')],
        edges: [_edge('e1', 'n1', 'n2', output: '  ')],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      expect(
        result.issues,
        contains(
          isA<WorkflowValidationIssue>()
              .having(
                (i) => i.code,
                'code',
                WorkflowValidationCode.emptySourceOutput,
              )
              .having((i) => i.edgeId, 'edgeId', 'e1'),
        ),
      );
    });

    test('reports error for orphan edges', () {
      final wf = _workflow(
        nodes: [_node('n1')],
        edges: [_edge('e1', 'n1', 'missing-target')],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      expect(
        result.issues,
        contains(
          isA<WorkflowValidationIssue>()
              .having((i) => i.code, 'code', WorkflowValidationCode.orphanEdge)
              .having((i) => i.edgeId, 'edgeId', 'e1'),
        ),
      );
    });

    test('reports error for duplicate edges', () {
      final wf = _workflow(
        nodes: [_node('n1'), _node('n2')],
        edges: [_edge('e1', 'n1', 'n2'), _edge('e2', 'n1', 'n2')],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      expect(
        result.issues,
        contains(
          isA<WorkflowValidationIssue>()
              .having(
                (i) => i.code,
                'code',
                WorkflowValidationCode.duplicateEdge,
              )
              .having((i) => i.edgeId, 'edgeId', 'e2'),
        ),
      );
    });

    test('reports error for maxRetries <= 0', () {
      final wf = _workflow(
        nodes: [_node('n1'), _node('n2')],
        edges: [_edge('e1', 'n1', 'n2', maxRetries: 0)],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      expect(
        result.issues,
        contains(
          isA<WorkflowValidationIssue>()
              .having(
                (i) => i.code,
                'code',
                WorkflowValidationCode.invalidMaxRetries,
              )
              .having((i) => i.edgeId, 'edgeId', 'e1'),
        ),
      );
    });

    test('reports error for unbounded self-loop', () {
      final wf = _workflow(
        nodes: [_node('n1')],
        edges: [_edge('e1', 'n1', 'n1')],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      expect(
        result.issues,
        contains(
          isA<WorkflowValidationIssue>()
              .having(
                (i) => i.code,
                'code',
                WorkflowValidationCode.unboundedCycle,
              )
              .having((i) => i.edgeId, 'edgeId', 'e1'),
        ),
      );
    });

    test('reports error for unbounded multi-node cycle', () {
      final wf = _workflow(
        nodes: [_node('n1'), _node('n2'), _node('n3')],
        edges: [
          _edge('e1', 'n1', 'n2'),
          _edge('e2', 'n2', 'n3'),
          _edge('e3', 'n3', 'n1'),
        ],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      expect(
        result.issues.map((i) => i.code),
        contains(WorkflowValidationCode.unboundedCycle),
      );
    });

    test('reports warning for unreachable node while keeping isValid true', () {
      final wf = _workflow(
        nodes: [
          _node('n1'),
          _node('n2', label: 'Orphan Step'),
        ],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isTrue);
      expect(
        result.issues,
        contains(
          isA<WorkflowValidationIssue>()
              .having(
                (i) => i.severity,
                'severity',
                WorkflowValidationSeverity.warning,
              )
              .having(
                (i) => i.code,
                'code',
                WorkflowValidationCode.unreachableNode,
              )
              .having((i) => i.nodeId, 'nodeId', 'n2'),
        ),
      );
    });

    test('reports error for unknown node type', () {
      final wf = _workflow(
        nodes: [_node('n1', type: 'unknown.type', config: const {})],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      expect(
        result.issues,
        contains(
          isA<WorkflowValidationIssue>()
              .having(
                (i) => i.code,
                'code',
                WorkflowValidationCode.unknownNodeType,
              )
              .having((i) => i.nodeId, 'nodeId', 'n1'),
        ),
      );
    });

    test('reports field-level error for invalid node config', () {
      final wf = _workflow(
        nodes: [
          _node(
            'n1',
            config: const {'command': '  ', 'workingDirectory': '../escape'},
          ),
        ],
      );

      final result = validator.validate(wf);

      expect(result.isValid, isFalse);
      final configIssues = result.issues
          .where((i) => i.code == WorkflowValidationCode.invalidNodeConfig)
          .toList();
      expect(configIssues, hasLength(2));
      expect(configIssues.every((i) => i.nodeId == 'n1'), isTrue);
    });
  });
}
