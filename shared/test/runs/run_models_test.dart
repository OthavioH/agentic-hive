import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  final sampleWorkflow = Workflow(
    id: 'wf-1',
    name: 'Test Workflow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Start',
        position: WorkflowPosition(x: 10, y: 20),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 10),
    updatedAt: DateTime.utc(2026, 11, 20, 10),
  );

  group('RunStatus', () {
    test('isActive is true only for running and paused', () {
      expect(RunStatus.running.isActive, isTrue);
      expect(RunStatus.paused.isActive, isTrue);
      expect(RunStatus.interrupted.isActive, isFalse);
      expect(RunStatus.succeeded.isActive, isFalse);
      expect(RunStatus.failed.isActive, isFalse);
      expect(RunStatus.cancelled.isActive, isFalse);
    });

    test('fromName parses valid names and throws on unknown', () {
      for (final status in RunStatus.values) {
        expect(RunStatus.fromName(status.name), status);
      }
      expect(
        () => RunStatus.fromName('bogus'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Run', () {
    test('round-trips through JSON with frozen Workflow snapshot', () {
      final run = Run(
        id: 'run-1',
        workflowId: 'wf-1',
        workflowName: 'Test Workflow',
        workflowDefinition: sampleWorkflow,
        workspacePath: '/tmp/ws',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12),
        finishedAt: DateTime.utc(2026, 11, 20, 12, 5),
        errorMessage: 'none',
      );

      final json = run.toJson();
      expect(json['status'], 'running');
      expect(json['workflowDefinition'], isA<Map<String, Object?>>());
      expect(Run.fromJson(json), run);
    });

    test('omits null optional fields from JSON', () {
      final run = Run(
        id: 'run-2',
        workflowName: 'Ad-hoc',
        workflowDefinition: sampleWorkflow,
        workspacePath: '/tmp/ws',
        status: RunStatus.paused,
        startedAt: DateTime.utc(2026, 11, 20, 12),
      );

      final json = run.toJson();
      expect(json.containsKey('workflowId'), isFalse);
      expect(json.containsKey('finishedAt'), isFalse);
      expect(json.containsKey('errorMessage'), isFalse);
      expect(Run.fromJson(json), run);
    });
  });

  group('RunSummary', () {
    test('round-trips through JSON', () {
      final summary = RunSummary(
        id: 'run-1',
        workflowId: 'wf-1',
        workflowName: 'Test Workflow',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026, 11, 20, 12),
        finishedAt: DateTime.utc(2026, 11, 20, 12, 1),
        checkpointCount: 3,
      );

      expect(RunSummary.fromJson(summary.toJson()), summary);
    });
  });

  group('Checkpoint', () {
    test('round-trips through JSON', () {
      final checkpoint = Checkpoint(
        id: 'cp-1',
        runId: 'run-1',
        sequence: 2,
        completedNodeId: 'n1',
        pendingNodeIds: const ['n2', 'n3'],
        attemptsByEdge: const {'e1': 1},
        circuitBreakerCount: 0,
        nodeOutputs: const {
          'n1': {'status': 'ok', 'tokens': 42},
        },
        createdAt: DateTime.utc(2026, 11, 20, 12, 1),
      );

      final json = checkpoint.toJson();
      expect(Checkpoint.fromJson(json), checkpoint);
    });
  });

  group('RunEventType and RunEvent', () {
    test('all RunEventType values serialize as dot-notation strings', () {
      const expected = {
        RunEventType.runStarted: 'run.started',
        RunEventType.runPaused: 'run.paused',
        RunEventType.runResumed: 'run.resumed',
        RunEventType.runInterrupted: 'run.interrupted',
        RunEventType.runSucceeded: 'run.succeeded',
        RunEventType.runFailed: 'run.failed',
        RunEventType.runCancelled: 'run.cancelled',
        RunEventType.nodeStarted: 'node.started',
        RunEventType.nodeCompleted: 'node.completed',
        RunEventType.nodeFailed: 'node.failed',
        RunEventType.nodeRetried: 'node.retried',
        RunEventType.checkpointSaved: 'checkpoint.saved',
      };

      expect(expected.length, RunEventType.values.length);
      for (final entry in expected.entries) {
        expect(entry.key.wireName, entry.value);
        expect(RunEventType.fromWireName(entry.value), entry.key);

        final event = RunEvent(
          id: 'ev-1',
          runId: 'run-1',
          sequence: 1,
          type: entry.key,
          createdAt: DateTime.utc(2026, 11, 20, 12),
        );
        final json = event.toJson();
        expect(json['type'], entry.value);
        expect(RunEvent.fromJson(json), event);
      }

      expect(
        () => RunEventType.fromWireName('unknown.event'),
        throwsA(isA<FormatException>()),
      );
    });

    test('RunEvent defaults payload to empty map when omitted', () {
      final decoded = RunEvent.fromJson({
        'id': 'ev-2',
        'runId': 'run-1',
        'sequence': 4,
        'type': 'node.retried',
        'nodeId': 'n1',
        'edgeId': 'e1',
        'createdAt': '2026-11-20T12:00:00.000Z',
      });
      expect(decoded.payload, isEmpty);
      expect(decoded.type, RunEventType.nodeRetried);
      expect(decoded.nodeId, 'n1');
      expect(decoded.edgeId, 'e1');
    });
  });

  group('Paginated DTOs', () {
    test('RunsListResponse round-trips through JSON', () {
      final dto = RunsListResponse(
        items: [
          RunSummary(
            id: 'run-1',
            workflowName: 'Flow',
            status: RunStatus.interrupted,
            startedAt: DateTime.utc(2026, 11, 20, 12),
            checkpointCount: 1,
          ),
        ],
        total: 5,
      );
      expect(RunsListResponse.fromJson(dto.toJson()), dto);
    });

    test('RunEventsResponse round-trips through JSON', () {
      final dto = RunEventsResponse(
        items: [
          RunEvent(
            id: 'ev-1',
            runId: 'run-1',
            sequence: 3,
            type: RunEventType.checkpointSaved,
            payload: const {'checkpointId': 'cp-1'},
            createdAt: DateTime.utc(2026, 11, 20, 12),
          ),
        ],
        lastSequence: 3,
      );
      expect(RunEventsResponse.fromJson(dto.toJson()), dto);
    });

    test('RunCheckpointsResponse round-trips through JSON', () {
      final dto = RunCheckpointsResponse(
        items: [
          Checkpoint(
            id: 'cp-1',
            runId: 'run-1',
            sequence: 1,
            pendingNodeIds: const ['n1'],
            attemptsByEdge: const {},
            circuitBreakerCount: 0,
            nodeOutputs: const {},
            createdAt: DateTime.utc(2026, 11, 20, 12),
          ),
        ],
      );
      expect(RunCheckpointsResponse.fromJson(dto.toJson()), dto);
    });
  });
}
