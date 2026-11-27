import 'package:agentic_hive_backend/src/domain/runs/attempt_node_type.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

Run _run({String nodeType = NodeTypeId.claudeCode}) => Run(
  id: 'run-1',
  workflowId: 'wf-1',
  workflowName: 'Test',
  workspaceId: 'ws-1',
  workspaceRoot: '/tmp/ws',
  status: RunStatus.running,
  startedAt: DateTime.utc(2026, 11, 20, 12),
  workflowDefinition: Workflow(
    id: 'wf-1',
    name: 'Test',
    entryNodeId: 'n1',
    nodes: [
      WorkflowNode(
        id: 'n1',
        type: nodeType,
        label: 'Node 1',
        position: const WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    createdAt: DateTime.utc(2026, 11, 20, 12),
    updatedAt: DateTime.utc(2026, 11, 20, 12),
  ),
);

RunEvent _event({
  required int sequence,
  required RunEventType type,
  String nodeId = 'n1',
  JsonMap payload = const {},
}) => RunEvent(
  id: 'ev-$sequence',
  runId: 'run-1',
  sequence: sequence,
  type: type,
  nodeId: nodeId,
  payload: payload,
  createdAt: DateTime.utc(2026, 11, 20, 12),
);

void main() {
  group('nodeTypeForAttempt', () {
    test('returns configured type when there are no events', () {
      final run = _run();
      expect(
        nodeTypeForAttempt(
          run: run,
          events: const [],
          nodeId: 'n1',
          attempt: 1,
        ),
        NodeTypeId.claudeCode,
      );
    });

    test(
      'switches to fallback harness on later attempts and keeps it on retry',
      () {
        final run = _run();
        final events = [
          _event(
            sequence: 1,
            type: RunEventType.nodeStarted,
            payload: const {'attempt': 1},
          ),
          _event(
            sequence: 2,
            type: RunEventType.nodeFallback,
            payload: const {
              'from': {'harness': NodeTypeId.claudeCode},
              'to': {'harness': NodeTypeId.codex},
              'reason': 'rate_limit',
            },
          ),
          _event(
            sequence: 3,
            type: RunEventType.nodeStarted,
            payload: const {'attempt': 2},
          ),
          _event(
            sequence: 4,
            type: RunEventType.nodeStarted,
            payload: const {'attempt': 3},
          ),
        ];

        expect(
          nodeTypeForAttempt(
            run: run,
            events: events,
            nodeId: 'n1',
            attempt: 1,
          ),
          NodeTypeId.claudeCode,
        );
        expect(
          nodeTypeForAttempt(
            run: run,
            events: events,
            nodeId: 'n1',
            attempt: 2,
          ),
          NodeTypeId.codex,
        );
        expect(
          nodeTypeForAttempt(
            run: run,
            events: events,
            nodeId: 'n1',
            attempt: 3,
          ),
          NodeTypeId.codex,
        );
      },
    );

    test(
      'counts legacy node.started events without attempt field by order',
      () {
        final run = _run();
        final events = [
          _event(sequence: 1, type: RunEventType.nodeStarted),
          _event(
            sequence: 2,
            type: RunEventType.nodeFallback,
            payload: const {
              'to': {'harness': NodeTypeId.geminiCli},
            },
          ),
          _event(sequence: 3, type: RunEventType.nodeStarted),
        ];

        expect(
          nodeTypeForAttempt(
            run: run,
            events: events,
            nodeId: 'n1',
            attempt: 1,
          ),
          NodeTypeId.claudeCode,
        );
        expect(
          nodeTypeForAttempt(
            run: run,
            events: events,
            nodeId: 'n1',
            attempt: 2,
          ),
          NodeTypeId.geminiCli,
        );
      },
    );

    test('returns null for unknown node', () {
      final run = _run();
      expect(
        nodeTypeForAttempt(
          run: run,
          events: const [],
          nodeId: 'missing',
          attempt: 1,
        ),
        isNull,
      );
    });
  });
}
