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
    test('isActive is true only for running, paused, and cancelling', () {
      expect(RunStatus.running.isActive, isTrue);
      expect(RunStatus.paused.isActive, isTrue);
      expect(RunStatus.cancelling.isActive, isTrue);
      expect(RunStatus.cancellationUncertain.isActive, isFalse);
      expect(RunStatus.interrupted.isActive, isFalse);
      expect(RunStatus.succeeded.isActive, isFalse);
      expect(RunStatus.failed.isActive, isFalse);
      expect(RunStatus.cancelled.isActive, isFalse);
    });

    test('isExecutingProcesses is true only for running and cancelling', () {
      expect(RunStatus.running.isExecutingProcesses, isTrue);
      expect(RunStatus.cancelling.isExecutingProcesses, isTrue);
      expect(RunStatus.paused.isExecutingProcesses, isFalse);
      expect(RunStatus.cancellationUncertain.isExecutingProcesses, isFalse);
      expect(RunStatus.interrupted.isExecutingProcesses, isFalse);
      expect(RunStatus.succeeded.isExecutingProcesses, isFalse);
      expect(RunStatus.failed.isExecutingProcesses, isFalse);
      expect(RunStatus.cancelled.isExecutingProcesses, isFalse);
    });

    test('isRunningOrPaused is true only for running and paused', () {
      expect(RunStatus.running.isRunningOrPaused, isTrue);
      expect(RunStatus.paused.isRunningOrPaused, isTrue);
      expect(RunStatus.cancelling.isRunningOrPaused, isFalse);
      expect(RunStatus.cancellationUncertain.isRunningOrPaused, isFalse);
      expect(RunStatus.interrupted.isRunningOrPaused, isFalse);
      expect(RunStatus.succeeded.isRunningOrPaused, isFalse);
      expect(RunStatus.failed.isRunningOrPaused, isFalse);
      expect(RunStatus.cancelled.isRunningOrPaused, isFalse);
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
        workspaceRoot: '/tmp/ws',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12),
        finishedAt: DateTime.utc(2026, 11, 20, 12, 5),
        errorMessage: 'none',
        input: 'Check all Dart files for unused imports.',
      );

      final json = run.toJson();
      expect(json['status'], 'running');
      expect(json['input'], 'Check all Dart files for unused imports.');
      expect(json['workflowDefinition'], isA<Map<String, Object?>>());
      expect(Run.fromJson(json), run);
    });

    test('omits null optional fields from JSON', () {
      final run = Run(
        id: 'run-2',
        workflowName: 'Ad-hoc',
        workflowDefinition: sampleWorkflow,
        workspaceRoot: '/tmp/ws',
        status: RunStatus.paused,
        startedAt: DateTime.utc(2026, 11, 20, 12),
      );

      final json = run.toJson();
      expect(json.containsKey('workflowId'), isFalse);
      expect(json.containsKey('finishedAt'), isFalse);
      expect(json.containsKey('errorMessage'), isFalse);
      expect(json.containsKey('worktreePath'), isFalse);
      expect(json.containsKey('worktreeBranch'), isFalse);
      expect(json.containsKey('input'), isFalse);
      expect(json.containsKey('parentRunId'), isFalse);
      expect(json.containsKey('parentNodeId'), isFalse);
      expect(json.containsKey('childIndex'), isFalse);
      expect(json.containsKey('childName'), isFalse);
      expect(json.containsKey('nodeOverrides'), isFalse);
      expect(json.containsKey('attachments'), isFalse);
      expect(Run.fromJson(json), run);
    });

    test('round-trips attachment metadata', () {
      final run = Run(
        id: 'run-att',
        workflowName: 'With Attachments',
        workflowDefinition: sampleWorkflow,
        workspaceRoot: '/tmp/ws',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12),
        attachments: const [
          RunAttachment(
            fileName: 'shot.png',
            mimeType: 'image/png',
            sizeBytes: 1234,
          ),
        ],
      );

      final json = run.toJson();
      expect(json['attachments'], [
        {'fileName': 'shot.png', 'mimeType': 'image/png', 'sizeBytes': 1234},
      ]);
      final encoded = (json['attachments']! as List).single as Map;
      expect(encoded.containsKey('data'), isFalse);
      expect(Run.fromJson(json), run);
    });

    test('decodes an old payload without attachments', () {
      final legacyJson = Run(
        id: 'run-old',
        workflowName: 'Old',
        workflowDefinition: sampleWorkflow,
        workspaceRoot: '/tmp/ws',
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026, 11, 20, 12),
      ).toJson();
      expect(legacyJson.containsKey('attachments'), isFalse);
      expect(Run.fromJson(legacyJson).attachments, isNull);
    });

    test('round-trips parent link and node overrides', () {
      final run = Run(
        id: 'run-child',
        workflowId: 'wf-1',
        workflowName: 'Child Workflow',
        workflowDefinition: sampleWorkflow,
        workspaceRoot: '/tmp/ws',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12),
        parentRunId: 'run-0',
        parentNodeId: 'fan',
        childIndex: 2,
        childName: 'issue-3',
        nodeOverrides: const {'h': NodeOverride(model: 'm')},
      );

      final json = run.toJson();
      expect(json['parentRunId'], 'run-0');
      expect(json['nodeOverrides'], {
        'h': {'model': 'm'},
      });
      expect(Run.fromJson(json), run);
    });

    test('defaults isolationMode to direct when omitted and round-trips '
        'worktree fields', () {
      final legacyJson = {
        'id': 'run-legacy',
        'workflowName': 'Legacy',
        'workflowDefinition': sampleWorkflow.toJson(),
        'workspaceRoot': '/tmp/ws',
        'status': 'succeeded',
        'startedAt': '2026-11-20T12:00:00.000Z',
      };
      final legacy = Run.fromJson(legacyJson);
      expect(legacy.isolationMode, WorkspaceIsolationMode.direct);
      expect(legacy.worktreePath, isNull);
      expect(legacy.worktreeBranch, isNull);

      final worktreeRun = Run(
        id: 'run-wt',
        workflowName: 'Isolated',
        workflowDefinition: sampleWorkflow,
        workspaceRoot: '/tmp/ws',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12),
        isolationMode: WorkspaceIsolationMode.worktree,
        worktreePath: '/data/worktrees/run-wt',
        worktreeBranch: 'hive/run-wt',
      );
      expect(Run.fromJson(worktreeRun.toJson()), worktreeRun);
    });

    test('serializes workspaceRoot and omits workspacePath', () {
      final run = Run(
        id: 'run-ws-root',
        workflowName: 'Workspace Root',
        workflowDefinition: sampleWorkflow,
        workspaceRoot: '/tmp/ws',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12),
      );

      final json = run.toJson();
      expect(json['workspaceRoot'], '/tmp/ws');
      expect(json.containsKey('workspacePath'), isFalse);
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

    test('round-trips parent link and omits null keys', () {
      final child = RunSummary(
        id: 'run-child',
        workflowName: 'Child',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12),
        checkpointCount: 0,
        parentRunId: 'run-0',
        parentNodeId: 'fan',
      );
      final childJson = child.toJson();
      expect(childJson['parentRunId'], 'run-0');
      expect(childJson['parentNodeId'], 'fan');
      expect(RunSummary.fromJson(childJson), child);

      final root = RunSummary(
        id: 'run-root',
        workflowName: 'Root',
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 20, 12),
        checkpointCount: 0,
      );
      final rootJson = root.toJson();
      expect(rootJson.containsKey('parentRunId'), isFalse);
      expect(rootJson.containsKey('parentNodeId'), isFalse);
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

    test('defaults fallbackIndexByNodeId to empty and round-trips it', () {
      final legacy = Checkpoint.fromJson({
        'id': 'cp-legacy',
        'runId': 'run-1',
        'sequence': 1,
        'pendingNodeIds': const ['n2'],
        'attemptsByEdge': const <String, int>{},
        'circuitBreakerCount': 0,
        'nodeOutputs': const <String, JsonMap>{},
        'createdAt': '2026-11-20T12:01:00.000Z',
      });
      expect(legacy.fallbackIndexByNodeId, isEmpty);

      final withFallback = Checkpoint(
        id: 'cp-2',
        runId: 'run-1',
        sequence: 3,
        pendingNodeIds: const ['n2'],
        attemptsByEdge: const {},
        circuitBreakerCount: 0,
        nodeOutputs: const {},
        fallbackIndexByNodeId: const {'plan': 1},
        createdAt: DateTime.utc(2026, 11, 20, 12, 2),
      );
      expect(Checkpoint.fromJson(withFallback.toJson()), withFallback);
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
        RunEventType.runCancelling: 'run.cancelling',
        RunEventType.runCancellationUncertain: 'run.cancellation_uncertain',
        RunEventType.runCancelled: 'run.cancelled',
        RunEventType.nodeStarted: 'node.started',
        RunEventType.nodeCompleted: 'node.completed',
        RunEventType.nodeFailed: 'node.failed',
        RunEventType.nodeRetried: 'node.retried',
        RunEventType.nodeFallback: 'node.fallback',
        RunEventType.checkpointSaved: 'checkpoint.saved',
        RunEventType.snapshotCaptured: 'snapshot.captured',
        RunEventType.snapshotRestored: 'snapshot.restored',
        RunEventType.snapshotWarning: 'snapshot.warning',
        RunEventType.warning: 'run.warning',
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

    test('StartRunRequest round-trips through JSON', () {
      const dto = StartRunRequest(
        workflowId: 'wf-1',
        workspaceId: 'ws-1',
        workspaceIsolationMode: WorkspaceIsolationMode.direct,
        ignorePatterns: ['build/', '*.tmp'],
        input: 'Audit auth middleware',
      );
      final json = dto.toJson();
      expect(json['input'], 'Audit auth middleware');
      expect(StartRunRequest.fromJson(json), dto);

      const minimal = StartRunRequest(workflowId: 'wf-2', workspaceId: 'ws-2');
      final minimalJson = minimal.toJson();
      expect(minimalJson.containsKey('workspaceIsolationMode'), isFalse);
      expect(minimalJson.containsKey('ignorePatterns'), isFalse);
      expect(minimalJson.containsKey('input'), isFalse);
      expect(minimalJson.containsKey('nodeOverrides'), isFalse);
      expect(minimalJson.containsKey('attachments'), isFalse);
      expect(StartRunRequest.fromJson(minimalJson), minimal);
    });

    test('StartRunRequest round-trips attachments', () {
      const dto = StartRunRequest(
        workflowId: 'wf-1',
        workspaceId: 'ws-1',
        attachments: [
          RunAttachmentPayload(
            fileName: 'Pasted image 1.png',
            mimeType: 'image/png',
            data: 'iVBORw0KGgo=',
          ),
        ],
      );
      final json = dto.toJson();
      expect(json['attachments'], [
        {
          'fileName': 'Pasted image 1.png',
          'mimeType': 'image/png',
          'data': 'iVBORw0KGgo=',
        },
      ]);
      expect(StartRunRequest.fromJson(json), dto);
    });

    test('StartRunRequest decodes an old payload without attachments', () {
      final decoded = StartRunRequest.fromJson({
        'workflowId': 'wf',
        'workspaceId': 'ws',
      });
      expect(decoded.attachments, isNull);
    });

    test('RunAttachmentPayload rejects a missing data field', () {
      expect(
        () => RunAttachmentPayload.fromJson({
          'fileName': 'a',
          'mimeType': 'image/png',
        }),
        throwsFormatException,
      );
    });

    test('StartRunRequest carries node overrides', () {
      const dto = StartRunRequest(
        workflowId: 'wf-1',
        workspaceId: 'ws-1',
        nodeOverrides: {'h': NodeOverride(effort: 'low')},
      );
      final json = dto.toJson();
      expect(json['nodeOverrides'], {
        'h': {'effort': 'low'},
      });
      expect(StartRunRequest.fromJson(json), dto);
    });

    test('StartRunRequest requires workspaceId and drops workspacePath', () {
      expect(
        () => StartRunRequest.fromJson(<String, Object?>{'workflowId': 'wf'}),
        throwsFormatException,
      );
      final json = const StartRunRequest(
        workflowId: 'wf',
        workspaceId: 'ws',
      ).toJson();
      expect(json.containsKey('workspacePath'), isFalse);
    });

    test('StartRunRequest carries each run target through JSON', () {
      const targets = <RunTarget>[
        RunTarget.primary(),
        RunTarget.worktree(worktreeId: 'feature-x'),
        RunTarget.newWorktree(),
        RunTarget.newWorktree(
          name: 'spike',
          branch: 'hive/spike',
          baseBranch: 'main',
        ),
      ];
      for (final target in targets) {
        final dto = StartRunRequest(
          workflowId: 'wf',
          workspaceId: 'ws',
          target: target,
        );
        expect(StartRunRequest.fromJson(dto.toJson()), dto);
      }
    });

    test('RunTarget uses a type discriminator and rejects unknown types', () {
      expect(const RunTarget.primary().toJson(), {'type': 'primary'});
      expect(const RunTarget.worktree(worktreeId: 'a').toJson(), {
        'type': 'worktree',
        'worktreeId': 'a',
      });
      expect(
        () => RunTarget.fromJson(<String, Object?>{'type': 'nope'}),
        throwsFormatException,
      );
      expect(
        () => RunTarget.fromJson(<String, Object?>{'type': 'worktree'}),
        throwsFormatException,
      );
    });

    test('StartRunRequest target is optional', () {
      const request = StartRunRequest(workflowId: 'wf', workspaceId: 'ws');
      expect(request.target, isNull);
      expect(request.toJson().containsKey('target'), isFalse);
    });

    test('RunNodeLogsResponse round-trips through JSON', () {
      final dto = RunNodeLogsResponse(
        runId: 'run-1',
        nodeId: 'n1',
        attempt: 2,
        availableAttempts: const [1, 2],
        entries: [
          RunLogEntry(
            stream: RunOutputStream.stdout,
            chunk: 'hello world',
            timestamp: DateTime.utc(2026, 11, 20, 12),
            offset: 1,
          ),
          RunLogEntry(
            stream: RunOutputStream.stderr,
            chunk: 'warning line',
            timestamp: DateTime.utc(2026, 11, 20, 12, 0, 1),
            offset: 2,
          ),
        ],
        truncated: true,
        offset: 2,
      );
      expect(RunNodeLogsResponse.fromJson(dto.toJson()), dto);
    });
  });

  group('RunAttachmentLimits', () {
    test('defines allowed MIME types and size/count limits', () {
      expect(RunAttachmentLimits.allowedMimeTypes, {
        'image/png',
        'image/jpeg',
        'image/webp',
        'image/gif',
      });
      expect(RunAttachmentLimits.maxCount, 10);
      expect(RunAttachmentLimits.maxBytesEach, 10485760);
      expect(RunAttachmentLimits.maxTotalBytes, 26214400);
    });
  });
}
