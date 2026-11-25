import 'package:agentic_hive_frontend/data/workspace/workspace_tree_changes.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_tree_changes_source.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

WsEnvelope _envelope(String type, JsonMap payload) =>
    WsEnvelope(type: type, id: 'e', payload: payload);

RunEvent _event(RunEventType type) => RunEvent(
  id: 'ev-1',
  runId: 'run-1',
  sequence: 1,
  type: type,
  createdAt: DateTime.utc(2026, 11, 23),
);

Pause _pause() => Pause(
  id: 'p-1',
  runId: 'run-1',
  nodeId: 'n',
  kind: PauseKind.humanApproval,
  workflowName: 'Flow',
  nodeLabel: 'Approve',
  status: PauseStatus.pending,
  createdAt: DateTime.utc(2026, 11, 23),
);

void main() {
  group('workspaceTreeChangeFor', () {
    test('maps run lifecycle events to a run change', () {
      for (final type in <RunEventType>[
        RunEventType.runStarted,
        RunEventType.runPaused,
        RunEventType.runResumed,
        RunEventType.runSucceeded,
        RunEventType.runFailed,
        RunEventType.runCancelling,
        RunEventType.runCancelled,
      ]) {
        final change = workspaceTreeChangeFor(
          _envelope(
            WsMessageType.runEvent,
            RunEventPayload(event: _event(type)).toJson(),
          ),
        );
        expect(change, WorkspaceTreeChange.run, reason: type.wireName);
      }
    });

    test('ignores node and checkpoint events', () {
      for (final type in <RunEventType>[
        RunEventType.nodeStarted,
        RunEventType.nodeCompleted,
        RunEventType.checkpointSaved,
      ]) {
        final change = workspaceTreeChangeFor(
          _envelope(
            WsMessageType.runEvent,
            RunEventPayload(event: _event(type)).toJson(),
          ),
        );
        expect(change, isNull, reason: type.wireName);
      }
    });

    test('maps pause events to a pause change', () {
      expect(
        workspaceTreeChangeFor(
          _envelope(
            WsMessageType.pauseCreated,
            PauseCreatedPayload(pause: _pause()).toJson(),
          ),
        ),
        WorkspaceTreeChange.pause,
      );
      expect(
        workspaceTreeChangeFor(
          _envelope(
            WsMessageType.pauseResolved,
            PauseResolvedPayload(pause: _pause()).toJson(),
          ),
        ),
        WorkspaceTreeChange.pause,
      );
    });

    test('maps workspace and worktree events', () {
      expect(
        workspaceTreeChangeFor(
          _envelope(
            WsMessageType.workspacesChanged,
            const WorkspacesChangedPayload(
              kind: WorkspaceChangeKind.deleted,
              id: 'ws-1',
            ).toJson(),
          ),
        ),
        WorkspaceTreeChange.workspace,
      );
      expect(
        workspaceTreeChangeFor(
          _envelope(
            WsMessageType.worktreesChanged,
            const WorktreesChangedPayload(
              kind: WorktreeChangeKind.removed,
              workspaceId: 'ws-1',
              worktreeId: 'feat',
            ).toJson(),
          ),
        ),
        WorkspaceTreeChange.worktree,
      );
    });

    test('ignores unrelated and malformed messages', () {
      expect(
        workspaceTreeChangeFor(
          _envelope(WsMessageType.settingsUpdated, <String, Object?>{}),
        ),
        isNull,
      );
      expect(
        workspaceTreeChangeFor(
          _envelope(WsMessageType.runEvent, <String, Object?>{'bad': 1}),
        ),
        isNull,
      );
    });
  });
}
