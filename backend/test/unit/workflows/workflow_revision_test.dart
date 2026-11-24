import 'dart:convert';

import 'package:agentic_hive_backend/src/domain/workflows/workflow_revision.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 11, 20, 10);
  final updatedAt = DateTime.utc(2026, 11, 20, 11);

  Workflow makeWorkflow({
    String id = 'wf-1',
    String name = 'My Workflow',
    List<WorkflowNode>? nodes,
    List<WorkflowEdge>? edges,
    String? entryNodeId,
    DateTime? created,
    DateTime? updated,
  }) => Workflow(
    id: id,
    name: name,
    nodes: nodes ?? const [],
    edges: edges ?? const [],
    entryNodeId: entryNodeId,
    createdAt: created ?? createdAt,
    updatedAt: updated ?? updatedAt,
  );

  group('workflowRevision', () {
    test('is 16 lowercase hex characters', () {
      expect(
        workflowRevision(makeWorkflow()),
        matches(RegExp(r'^[0-9a-f]{16}$')),
      );
    });

    test('is stable for identical content', () {
      final a = makeWorkflow();
      final b = makeWorkflow();
      expect(workflowRevision(a), workflowRevision(b));
      expect(workflowRevision(a), workflowRevision(a));
    });

    test('ignores createdAt and updatedAt', () {
      final a = makeWorkflow();
      final b = a.copyWith(
        createdAt: DateTime.utc(2025),
        updatedAt: DateTime.utc(2027, 12, 31),
      );
      expect(workflowRevision(a), workflowRevision(b));
    });

    test('ignores map key order in node config', () {
      final a = makeWorkflow(
        nodes: const [
          WorkflowNode(
            id: 'n1',
            type: 'harness',
            label: 'A',
            position: WorkflowPosition(x: 0, y: 0),
            config: {
              'a': 1,
              'b': {'y': 2, 'x': 3},
            },
          ),
        ],
      );
      final b = makeWorkflow(
        nodes: const [
          WorkflowNode(
            id: 'n1',
            type: 'harness',
            label: 'A',
            position: WorkflowPosition(x: 0, y: 0),
            config: {
              'b': {'x': 3, 'y': 2},
              'a': 1,
            },
          ),
        ],
      );
      expect(workflowRevision(a), workflowRevision(b));
    });

    test('changes when the name changes', () {
      final a = makeWorkflow(name: 'One');
      final b = makeWorkflow(name: 'Two');
      expect(workflowRevision(a), isNot(workflowRevision(b)));
    });

    test('changes when a node config value changes', () {
      final a = makeWorkflow(
        nodes: const [
          WorkflowNode(
            id: 'n1',
            type: 'harness',
            label: 'A',
            position: WorkflowPosition(x: 0, y: 0),
            config: {'model': 'sonnet'},
          ),
        ],
      );
      final b = makeWorkflow(
        nodes: const [
          WorkflowNode(
            id: 'n1',
            type: 'harness',
            label: 'A',
            position: WorkflowPosition(x: 0, y: 0),
            config: {'model': 'opus'},
          ),
        ],
      );
      expect(workflowRevision(a), isNot(workflowRevision(b)));
    });

    test('changes when an edge is added', () {
      final a = makeWorkflow();
      final b = makeWorkflow(
        edges: const [
          WorkflowEdge(
            id: 'e1',
            sourceNodeId: 'n1',
            sourceOutput: 'onSuccess',
            targetNodeId: 'n2',
          ),
        ],
      );
      expect(workflowRevision(a), isNot(workflowRevision(b)));
    });

    test('changes when entryNodeId changes', () {
      final a = makeWorkflow(entryNodeId: 'n1');
      final b = makeWorkflow(entryNodeId: 'n2');
      expect(workflowRevision(a), isNot(workflowRevision(b)));
    });

    test('matches the documented algorithm', () {
      final workflow = makeWorkflow(id: 'wf', name: 'N');
      final expected = sha256
          .convert(
            utf8.encode(
              jsonEncode({
                'edges': <Object?>[],
                'id': 'wf',
                'name': 'N',
                'nodes': <Object?>[],
                'schemaVersion': 1,
              }),
            ),
          )
          .toString()
          .substring(0, 16);

      expect(workflowRevision(workflow), expected);
    });
  });
}
