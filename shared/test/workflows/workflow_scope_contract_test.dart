import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  final timestamp = DateTime.utc(2026, 11, 23, 9);

  group('WorkflowSummary scope', () {
    test('defaults to global without a workspace id', () {
      final summary = WorkflowSummary.fromJson({
        'id': 'a',
        'name': 'A',
        'nodeCount': 1,
        'edgeCount': 0,
        'hasValidationErrors': false,
        'updatedAt': timestamp.toIso8601String(),
      });
      expect(summary.scope, const GlobalScope());
    });

    test('round-trips a workspace scope', () {
      final summary = WorkflowSummary(
        id: 'a',
        name: 'A',
        nodeCount: 1,
        edgeCount: 0,
        hasValidationErrors: false,
        updatedAt: timestamp,
        scope: const WorkspaceScope('ws-1'),
      );
      final decoded = WorkflowSummary.fromJson(_overTheWire(summary.toJson()));
      expect(decoded, summary);
      expect(decoded.scope, const WorkspaceScope('ws-1'));
    });
  });

  group('requests', () {
    test('CreateWorkflowRequest carries an optional workspace id', () {
      expect(CreateWorkflowRequest.fromJson({'name': 'x'}).workspaceId, isNull);
      final request = CreateWorkflowRequest.fromJson({
        'name': 'x',
        'workspaceId': 'ws-1',
      });
      expect(request.workspaceId, 'ws-1');
    });
  });

  group('WorkflowResponse scope', () {
    test('defaults to global and round-trips a workspace scope', () {
      final workflow = Workflow(
        id: 'wf',
        name: 'wf',
        nodes: const [],
        edges: const [],
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      const validation = WorkflowValidationResult(isValid: true);
      final response = WorkflowResponse(
        workflow: workflow,
        validation: validation,
        scope: const WorkspaceScope('ws-1'),
      );
      final decoded = WorkflowResponse.fromJson(
        _overTheWire(response.toJson()),
      );
      expect(decoded.scope, const WorkspaceScope('ws-1'));
      final bare = WorkflowResponse.fromJson({
        'workflow': workflow.toJson(),
        'validation': validation.toJson(),
      });
      expect(bare.scope, const GlobalScope());
    });
  });

  group('WorkflowsChangedPayload', () {
    test('round-trips with a summary and workspace id', () {
      final payload = WorkflowsChangedPayload(
        kind: WorkflowChangeKind.updated,
        id: 'deploy',
        workspaceId: 'ws-1',
        workflow: WorkflowSummary(
          id: 'deploy',
          name: 'Deploy',
          nodeCount: 2,
          edgeCount: 1,
          hasValidationErrors: false,
          updatedAt: timestamp,
          scope: const WorkspaceScope('ws-1'),
        ),
      );
      expect(
        WorkflowsChangedPayload.fromJson(_overTheWire(payload.toJson())),
        payload,
      );
    });

    test('message type is workflows.changed', () {
      expect(WsMessageType.workflowsChanged, 'workflows.changed');
    });
  });
}
