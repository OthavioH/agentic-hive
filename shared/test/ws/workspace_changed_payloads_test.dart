import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  final timestamp = DateTime.utc(2026, 11, 23, 9);
  final workspace = Workspace(
    id: 'ws-1',
    name: 'App',
    rootPath: '/work/app',
    isGit: true,
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  group('WsMessageType', () {
    test('names the workspace and worktree change events', () {
      expect(WsMessageType.workspacesChanged, 'workspaces.changed');
      expect(WsMessageType.worktreesChanged, 'worktrees.changed');
    });
  });

  group('WorkspacesChangedPayload', () {
    test('round-trips a created workspace', () {
      final payload = WorkspacesChangedPayload(
        kind: WorkspaceChangeKind.created,
        id: 'ws-1',
        workspace: workspace,
      );
      final decoded = WorkspacesChangedPayload.fromJson(
        _overTheWire(payload.toJson()),
      );
      expect(decoded, payload);
      expect(decoded.workspace, workspace);
    });

    test('a deletion carries no workspace', () {
      final decoded = WorkspacesChangedPayload.fromJson({
        'kind': 'deleted',
        'id': 'ws-1',
      });
      expect(decoded.kind, WorkspaceChangeKind.deleted);
      expect(decoded.workspace, isNull);
    });

    test('rejects an unknown kind', () {
      expect(
        () => WorkspacesChangedPayload.fromJson({'kind': 'moved', 'id': 'a'}),
        throwsFormatException,
      );
    });
  });

  group('WorktreesChangedPayload', () {
    test('round-trips a created worktree', () {
      const worktree = Worktree(
        id: 'feat',
        name: 'feat',
        path: '/wt/ws-1/feat',
        isPrimary: false,
        hasUncommittedChanges: false,
        branch: 'feat',
      );
      const payload = WorktreesChangedPayload(
        kind: WorktreeChangeKind.created,
        workspaceId: 'ws-1',
        worktreeId: 'feat',
        worktree: worktree,
      );
      final decoded = WorktreesChangedPayload.fromJson(
        _overTheWire(payload.toJson()),
      );
      expect(decoded, payload);
    });

    test('a removal carries no worktree', () {
      final decoded = WorktreesChangedPayload.fromJson({
        'kind': 'removed',
        'workspaceId': 'ws-1',
        'worktreeId': 'feat',
      });
      expect(decoded.kind, WorktreeChangeKind.removed);
      expect(decoded.worktree, isNull);
    });
  });
}
