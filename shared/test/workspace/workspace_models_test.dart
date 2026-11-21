import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('WorkspaceIsolationMode', () {
    test('fromName parses all values and throws on unknown', () {
      for (final mode in WorkspaceIsolationMode.values) {
        expect(WorkspaceIsolationMode.fromName(mode.name), mode);
      }
      expect(
        () => WorkspaceIsolationMode.fromName('bogus'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SnapshotKind', () {
    test('serializes with snake_case wire names', () {
      expect(SnapshotKind.preNode.wireName, 'pre_node');
      expect(SnapshotKind.safetyPreRestore.wireName, 'safety_pre_restore');
      expect(SnapshotKind.fromWireName('pre_node'), SnapshotKind.preNode);
      expect(
        SnapshotKind.fromWireName('safety_pre_restore'),
        SnapshotKind.safetyPreRestore,
      );
      expect(
        () => SnapshotKind.fromWireName('unknown'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Snapshot', () {
    test('round-trips through JSON with optional nodeId', () {
      final snapshot = Snapshot(
        id: 'snap-1',
        runId: 'run-1',
        nodeId: 'node-a',
        commitHash: 'abc1234',
        kind: SnapshotKind.preNode,
        addedCount: 2,
        modifiedCount: 1,
        deletedCount: 3,
        createdAt: DateTime.utc(2026, 11, 21, 10),
      );

      final json = snapshot.toJson();
      expect(json['kind'], 'pre_node');
      expect(Snapshot.fromJson(json), snapshot);
    });

    test('omits null nodeId and round-trips safety_pre_restore', () {
      final snapshot = Snapshot(
        id: 'snap-2',
        runId: 'run-1',
        commitHash: 'def5678',
        kind: SnapshotKind.safetyPreRestore,
        addedCount: 0,
        modifiedCount: 0,
        deletedCount: 0,
        createdAt: DateTime.utc(2026, 11, 21, 10, 5),
      );

      final json = snapshot.toJson();
      expect(json.containsKey('nodeId'), isFalse);
      expect(json['kind'], 'safety_pre_restore');
      expect(Snapshot.fromJson(json), snapshot);
    });
  });

  group('SnapshotDiff & SnapshotFileChange', () {
    test('round-trips through JSON', () {
      const diff = SnapshotDiff(
        snapshotId: 'snap-1',
        files: [
          SnapshotFileChange(
            path: 'notes/todo.md',
            changeType: SnapshotChangeType.added,
          ),
          SnapshotFileChange(
            path: 'README.md',
            changeType: SnapshotChangeType.modified,
          ),
          SnapshotFileChange(
            path: 'old.txt',
            changeType: SnapshotChangeType.deleted,
          ),
        ],
      );

      final json = diff.toJson();
      expect(SnapshotDiff.fromJson(json), diff);
    });
  });

  group('WorkspaceCapabilities', () {
    test('round-trips through JSON', () {
      const caps = WorkspaceCapabilities(
        gitAvailable: true,
        gitVersion: 'git version 2.45.0',
        isGitRepo: true,
        hasCommits: false,
      );
      expect(WorkspaceCapabilities.fromJson(caps.toJson()), caps);

      const noGit = WorkspaceCapabilities(
        gitAvailable: false,
        isGitRepo: false,
        hasCommits: false,
      );
      final noGitJson = noGit.toJson();
      expect(noGitJson.containsKey('gitVersion'), isFalse);
      expect(WorkspaceCapabilities.fromJson(noGitJson), noGit);
    });
  });

  group('Workspace DTOs', () {
    test('RunSnapshotsResponse round-trips through JSON', () {
      final dto = RunSnapshotsResponse(
        items: [
          Snapshot(
            id: 'snap-1',
            runId: 'run-1',
            commitHash: 'abc1234',
            kind: SnapshotKind.preNode,
            addedCount: 1,
            modifiedCount: 0,
            deletedCount: 0,
            createdAt: DateTime.utc(2026, 11, 21, 10),
          ),
        ],
      );
      expect(RunSnapshotsResponse.fromJson(dto.toJson()), dto);
    });

    test('RestoreSnapshotResponse round-trips through JSON', () {
      final dto = RestoreSnapshotResponse(
        restoredSnapshotId: 'snap-1',
        safetySnapshot: Snapshot(
          id: 'snap-2',
          runId: 'run-1',
          commitHash: 'def5678',
          kind: SnapshotKind.safetyPreRestore,
          addedCount: 0,
          modifiedCount: 1,
          deletedCount: 0,
          createdAt: DateTime.utc(2026, 11, 21, 10, 5),
        ),
      );
      expect(RestoreSnapshotResponse.fromJson(dto.toJson()), dto);
    });
  });
}
