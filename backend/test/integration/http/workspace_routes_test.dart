@Timeout(Duration(seconds: 60))
library;

import 'dart:io';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_event_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/drift_snapshot_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/workspace/shadow_snapshot_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late String dataDir;
  late Directory workspaceDir;
  late SocketHttpClient client;
  late String snapshotId;

  final workflow = Workflow(
    id: 'wf-1',
    name: 'HTTP Snapshot Flow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Edit',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 21, 9),
    updatedAt: DateTime.utc(2026, 11, 21, 9),
  );

  setUp(() async {
    dataDir = (await createTempDir()).path;
    workspaceDir = await createTempDir();
    final config = configFor(dataDir);
    final db = AppDatabase.open(File(config.databasePath));
    try {
      final runs = DriftRunRepository(db);
      final events = DriftRunEventRepository(db);
      final snapshots = DriftSnapshotRepository(db);

      await runs.create(
        Run(
          id: 'run-http',
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspaceRoot: workspaceDir.path,
          status: RunStatus.paused,
          startedAt: DateTime.utc(2026, 11, 21, 10),
        ),
      );
      await runs.create(
        Run(
          id: 'run-active',
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspaceRoot: workspaceDir.path,
          status: RunStatus.running,
          startedAt: DateTime.utc(2026, 11, 21, 10),
        ),
      );

      final snapService = ShadowSnapshotService(
        git: const GitClient(IoProcessRunner()),
        runs: runs,
        snapshots: snapshots,
        events: events,
        snapshotsDir: config.snapshotsDir,
        pathContext: p.context,
      );

      await File(p.join(workspaceDir.path, 'hello.txt'))
          .writeAsString('before\n');
      final snapRes = await snapService.captureSnapshot(
        runId: 'run-http',
        workspaceDir: workspaceDir.path,
        nodeId: 'n1',
      );
      snapshotId = (snapRes as Success<Snapshot>).value.id;

      await File(p.join(workspaceDir.path, 'hello.txt'))
          .writeAsString('after\n');
    } finally {
      await db.close();
    }

    final backend = await startBackend(dataDir);
    client = openClient(backend.socketPath);
  });

  test('serves capabilities, snapshots, diff, restore, and rejects Origin '
      'over Unix socket', () async {
    final capsResp = await client.get(
      '/api/v1/workspace/capabilities?path=${Uri.encodeQueryComponent(workspaceDir.path)}',
    );
    expect(capsResp.statusCode, 200);
    final caps = WorkspaceCapabilities.fromJson(capsResp.json);
    expect(caps.gitAvailable, isTrue);

    final listResp = await client.get('/api/v1/runs/run-http/snapshots');
    expect(listResp.statusCode, 200);
    final list = RunSnapshotsResponse.fromJson(listResp.json);
    expect(list.items.single.id, snapshotId);

    final diffResp = await client.get(
      '/api/v1/runs/run-http/snapshots/$snapshotId/diff',
    );
    expect(diffResp.statusCode, 200);
    final diff = SnapshotDiff.fromJson(diffResp.json);
    expect(diff.files.single.path, 'hello.txt');

    final restoreResp = await client.post(
      '/api/v1/runs/run-http/snapshots/$snapshotId/restore',
    );
    expect(restoreResp.statusCode, 200);
    expect(
      await File(p.join(workspaceDir.path, 'hello.txt')).readAsString(),
      'before\n',
    );

    final missingResp = await client.get('/api/v1/runs/missing/snapshots');
    expect(missingResp.statusCode, 404);

    final originResp = await client.get(
      '/api/v1/workspace/capabilities',
      headers: {'Origin': 'http://localhost:3000'},
    );
    expect(originResp.statusCode, 403);
  });
}
