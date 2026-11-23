import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  final createdAt = DateTime.utc(2026, 11, 20, 10, 30);
  final updatedAt = DateTime.utc(2026, 11, 20, 11, 45);

  const sampleNode = WorkflowNode(
    id: 'node-1',
    type: 'harness',
    label: 'Implementer',
    position: WorkflowPosition(x: 120.5, y: 240),
    config: {'harness': 'codex', 'timeoutSeconds': 300},
  );

  const sampleEdge = WorkflowEdge(
    id: 'edge-1',
    sourceNodeId: 'node-1',
    sourceOutput: 'onSuccess',
    targetNodeId: 'node-2',
    maxRetries: 2,
  );

  final sampleWorkflow = Workflow(
    id: 'wf-1',
    name: 'Build and Verify',
    description: 'Runs implementer then reviewer.',
    nodes: [sampleNode],
    edges: [sampleEdge],
    entryNodeId: 'node-1',
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  group('WorkflowPosition', () {
    test('round-trips through JSON', () {
      const position = WorkflowPosition(x: 42.5, y: -18.25);

      final decoded = WorkflowPosition.fromJson(
        _overTheWire(position.toJson()),
      );

      expect(decoded, position);
    });

    test('throws a FormatException when a coordinate has the wrong type', () {
      expect(
        () => WorkflowPosition.fromJson({'x': 'bad', 'y': 0}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"x"'),
          ),
        ),
      );
    });
  });

  group('WorkflowNode', () {
    test('round-trips through JSON with config', () {
      final decoded = WorkflowNode.fromJson(_overTheWire(sampleNode.toJson()));

      expect(decoded, sampleNode);
    });

    test('defaults config to an empty map when omitted', () {
      final decoded = WorkflowNode.fromJson({
        'id': 'n1',
        'type': 'placeholder',
        'label': 'Step 1',
        'position': {'x': 0, 'y': 0},
      });

      expect(decoded.config, isEmpty);
    });
  });

  group('WorkflowEdge', () {
    test('round-trips through JSON with maxRetries', () {
      final decoded = WorkflowEdge.fromJson(_overTheWire(sampleEdge.toJson()));

      expect(decoded, sampleEdge);
    });

    test('omits maxRetries when null', () {
      const edge = WorkflowEdge(
        id: 'edge-2',
        sourceNodeId: 'n1',
        sourceOutput: 'onFailure',
        targetNodeId: 'n2',
      );

      final encoded = edge.toJson();

      expect(encoded.containsKey('maxRetries'), isFalse);
      expect(WorkflowEdge.fromJson(_overTheWire(encoded)), edge);
    });
  });

  group('Workflow', () {
    test('round-trips through JSON', () {
      final decoded = Workflow.fromJson(_overTheWire(sampleWorkflow.toJson()));

      expect(decoded, sampleWorkflow);
    });

    test('defaults schemaVersion to 1 and omits null optional fields', () {
      final draft = Workflow(
        id: 'wf-draft',
        name: 'Draft',
        nodes: const [],
        edges: const [],
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final encoded = draft.toJson();
      expect(encoded.containsKey('description'), isFalse);
      expect(encoded.containsKey('entryNodeId'), isFalse);

      final decoded = Workflow.fromJson({
        'id': 'wf-draft',
        'name': 'Draft',
        'nodes': <Object?>[],
        'edges': <Object?>[],
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      });

      expect(decoded.schemaVersion, 1);
      expect(decoded.description, isNull);
      expect(decoded.entryNodeId, isNull);
    });

    test('throws a FormatException naming missing required field', () {
      expect(
        () => Workflow.fromJson({'id': 'wf-1'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"name"'),
          ),
        ),
      );
    });
  });

  group('WorkflowSummary', () {
    test('round-trips through JSON', () {
      final summary = WorkflowSummary(
        id: 'wf-1',
        name: 'Build and Verify',
        description: 'Runs implementer then reviewer.',
        nodeCount: 2,
        edgeCount: 1,
        hasValidationErrors: false,
        updatedAt: updatedAt,
      );

      final decoded = WorkflowSummary.fromJson(_overTheWire(summary.toJson()));

      expect(decoded, summary);
    });

    test('round-trips revision through JSON', () {
      final summary = WorkflowSummary(
        id: 'wf-1',
        name: 'Build and Verify',
        nodeCount: 2,
        edgeCount: 1,
        hasValidationErrors: false,
        updatedAt: updatedAt,
        revision: 'abc123',
      );

      final encoded = summary.toJson();
      expect(encoded['revision'], 'abc123');
      expect(WorkflowSummary.fromJson(_overTheWire(encoded)), summary);

      final withoutRevision = WorkflowSummary(
        id: 'wf-1',
        name: 'Build and Verify',
        nodeCount: 2,
        edgeCount: 1,
        hasValidationErrors: false,
        updatedAt: updatedAt,
      );
      expect(withoutRevision.toJson().containsKey('revision'), isFalse);
    });
  });

  group('WorkflowValidationResult', () {
    test('round-trips through JSON with error and warning issues', () {
      const result = WorkflowValidationResult(
        isValid: false,
        issues: [
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.error,
            code: 'unbounded_cycle',
            message: 'Cycle requires at least one edge with maxRetries > 0.',
            nodeId: 'node-1',
            edgeId: 'edge-1',
          ),
          WorkflowValidationIssue(
            severity: WorkflowValidationSeverity.warning,
            code: 'unreachable_node',
            message: 'Node is not reachable from entryNodeId.',
            nodeId: 'node-3',
          ),
        ],
      );

      final decoded = WorkflowValidationResult.fromJson(
        _overTheWire(result.toJson()),
      );

      expect(decoded, result);
      expect(decoded.isValid, isFalse);
      expect(decoded.issues, hasLength(2));
      expect(decoded.issues.first.severity, WorkflowValidationSeverity.error);
      expect(decoded.issues.last.severity, WorkflowValidationSeverity.warning);
      expect(decoded.issues.last.edgeId, isNull);
    });
  });

  group('Workflow DTOs', () {
    test('CreateWorkflowRequest round-trips through JSON', () {
      const req = CreateWorkflowRequest(
        name: 'New Flow',
        description: 'Desc',
        nodes: [sampleNode],
        edges: [sampleEdge],
        entryNodeId: 'node-1',
      );

      final decoded = CreateWorkflowRequest.fromJson(
        _overTheWire(req.toJson()),
      );

      expect(decoded, req);
    });

    test('UpdateWorkflowRequest round-trips through JSON', () {
      const req = UpdateWorkflowRequest(
        name: 'Updated Flow',
        nodes: [sampleNode],
        edges: [sampleEdge],
        entryNodeId: 'node-1',
        schemaVersion: 2,
      );

      final decoded = UpdateWorkflowRequest.fromJson(
        _overTheWire(req.toJson()),
      );

      expect(decoded, req);
    });

    test('DuplicateWorkflowRequest round-trips through JSON', () {
      const req = DuplicateWorkflowRequest(name: 'Copy');

      final decoded = DuplicateWorkflowRequest.fromJson(
        _overTheWire(req.toJson()),
      );

      expect(decoded, req);
      expect(DuplicateWorkflowRequest.fromJson(const {}).name, isNull);
    });

    test('ValidateWorkflowRequest round-trips through JSON', () {
      final req = ValidateWorkflowRequest(workflow: sampleWorkflow);

      final decoded = ValidateWorkflowRequest.fromJson(
        _overTheWire(req.toJson()),
      );

      expect(decoded, req);
    });

    test('WorkflowListResponse round-trips through JSON', () {
      final resp = WorkflowListResponse(
        workflows: [
          WorkflowSummary(
            id: 'wf-1',
            name: 'Build and Verify',
            nodeCount: 1,
            edgeCount: 1,
            hasValidationErrors: false,
            updatedAt: updatedAt,
          ),
        ],
      );

      final decoded = WorkflowListResponse.fromJson(
        _overTheWire(resp.toJson()),
      );

      expect(decoded, resp);
    });

    test('WorkflowResponse round-trips through JSON', () {
      final resp = WorkflowResponse(
        workflow: sampleWorkflow,
        validation: const WorkflowValidationResult(isValid: true),
      );

      final decoded = WorkflowResponse.fromJson(_overTheWire(resp.toJson()));

      expect(decoded, resp);
    });

    test('UpdateWorkflowRequest carries an optional revision', () {
      const withRev = UpdateWorkflowRequest(
        name: 'Updated Flow',
        revision: 'r1',
      );
      final encodedWith = withRev.toJson();
      expect(encodedWith['revision'], 'r1');
      expect(
        UpdateWorkflowRequest.fromJson(_overTheWire(encodedWith)),
        withRev,
      );

      const withoutRev = UpdateWorkflowRequest(name: 'Updated Flow');
      expect(withoutRev.toJson().containsKey('revision'), isFalse);
      expect(
        UpdateWorkflowRequest.fromJson(_overTheWire(withoutRev.toJson())),
        withoutRev,
      );
    });

    test('WorkflowResponse carries an optional revision', () {
      final resp = WorkflowResponse(
        workflow: sampleWorkflow,
        validation: const WorkflowValidationResult(isValid: true),
        revision: 'r1',
      );

      final encoded = resp.toJson();
      expect(encoded['revision'], 'r1');
      expect(WorkflowResponse.fromJson(_overTheWire(encoded)), resp);
    });
  });

  group('DeleteWorkflowResponse', () {
    test('round-trips through JSON', () {
      const resp = DeleteWorkflowResponse(
        id: 'wf-1',
        deletedRuns: 2,
        orphanedRuns: ['r9'],
      );
      final encoded = _overTheWire(resp.toJson());

      expect(encoded, {
        'id': 'wf-1',
        'deletedRuns': 2,
        'orphanedRuns': ['r9'],
      });
      expect(DeleteWorkflowResponse.fromJson(encoded), resp);
    });

    test('defaults orphanedRuns to empty when absent', () {
      final decoded = DeleteWorkflowResponse.fromJson({
        'id': 'wf-1',
        'deletedRuns': 2,
      });
      expect(decoded.orphanedRuns, isEmpty);
    });

    test('encodes an empty orphanedRuns list', () {
      const resp = DeleteWorkflowResponse(id: 'wf-1', deletedRuns: 0);
      expect(_overTheWire(resp.toJson()), {
        'id': 'wf-1',
        'deletedRuns': 0,
        'orphanedRuns': <String>[],
      });
    });

    test('throws FormatException when deletedRuns is missing', () {
      expect(
        () => DeleteWorkflowResponse.fromJson({'id': 'wf-1'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
