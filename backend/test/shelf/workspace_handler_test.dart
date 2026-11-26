import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/api/runs/runs_handler.dart';
import 'package:agentic_hive_backend/src/api/workspace/workspace_handler.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_checkpoint_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_event_repository.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/drift_snapshot_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/shadow_snapshot_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Directory tempDir;
  late Directory workspaceDir;
  late AppDatabase db;
  late DriftRunRepository runs;
  late ShadowSnapshotService snapshotService;
  late Handler handler;

  final workflow = Workflow(
    id: 'wf-1',
    name: 'Test Flow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Step',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 21, 9),
    updatedAt: DateTime.utc(2026, 11, 21, 9),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_ws_handler_');
    workspaceDir = Directory(p.join(tempDir.path, 'ws'))..createSync();
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();

    runs = DriftRunRepository(db);
    final checkpoints = DriftCheckpointRepository(db);
    final events = DriftRunEventRepository(db);
    final snapshots = DriftSnapshotRepository(db);
    const git = GitClient(IoProcessRunner());

    const capabilitiesService = WorkspaceCapabilitiesService(git);
    snapshotService = ShadowSnapshotService(
      git: git,
      runs: runs,
      snapshots: snapshots,
      events: events,
      snapshotsDir: p.join(tempDir.path, 'snapshots'),
      pathContext: p.context,
    );
    final workspaceHandler = WorkspaceHandler(
      capabilities: capabilitiesService,
      snapshots: snapshotService,
    );
    final runsHandler = RunsHandler(
      service: RunService(runs: runs, checkpoints: checkpoints, events: events),
    );

    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 5),
        ),
        version: '0.1.0',
        dataDir: tempDir.path,
        startedAt: DateTime.utc(2026, 11, 21, 9),
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (_) => Response.notFound('ws'),
      runsHandler: runsHandler,
      workspaceHandler: workspaceHandler,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Response> send(
    String method,
    String path, {
    Map<String, String>? headers,
  }) async => await handler(
    Request(method, Uri.parse('http://localhost$path'), headers: headers),
  );

  test('GET /api/v1/workspace/capabilities returns capabilities JSON', () async {
    final resp = await send(
      'GET',
      '/api/v1/workspace/capabilities?path=${Uri.encodeQueryComponent(workspaceDir.path)}',
    );
    expect(resp.statusCode, 200);
    final caps = WorkspaceCapabilities.fromJson(
      jsonDecode(await resp.readAsString()) as JsonMap,
    );
    expect(caps.gitAvailable, isTrue);
    expect(caps.isGitRepo, isFalse);
  });

  test('GET /api/v1/workspace/capabilities rejects a relative path', () async {
    final resp = await send(
      'GET',
      '/api/v1/workspace/capabilities?path=relative%2Ffolder',
    );
    expect(resp.statusCode, 400);
  });

  test('rejects requests with Origin header', () async {
    final resp = await send(
      'GET',
      '/api/v1/workspace/capabilities',
      headers: {'Origin': 'https://evil.example'},
    );
    expect(resp.statusCode, 403);
  });

  test('returns 404 for missing run or snapshot', () async {
    final missingRun = await send('GET', '/api/v1/runs/nope/snapshots');
    expect(missingRun.statusCode, 404);

    final missingDiff = await send(
      'GET',
      '/api/v1/runs/nope/snapshots/snap-1/diff',
    );
    expect(missingDiff.statusCode, 404);
  });

  test('lists snapshots, computes diff, enforces 409 when running, and '
      'restores when paused', () async {
    await runs.create(
      Run(
        id: 'run-1',
        workflowName: 'Test Flow',
        workflowDefinition: workflow,
        workspaceRoot: workspaceDir.path,
        status: RunStatus.running,
        startedAt: DateTime.utc(2026, 11, 21, 10),
      ),
    );
    await File(p.join(workspaceDir.path, 'a.txt')).writeAsString('v1\n');
    final snapRes = await snapshotService.captureSnapshot(
      runId: 'run-1',
      targetFolder: workspaceDir.path,
      nodeId: 'n1',
    );
    final snap = (snapRes as Success<Snapshot>).value;

    final listResp = await send('GET', '/api/v1/runs/run-1/snapshots');
    expect(listResp.statusCode, 200);
    final list = RunSnapshotsResponse.fromJson(
      jsonDecode(await listResp.readAsString()) as JsonMap,
    );
    expect(list.items, hasLength(1));
    expect(list.items.single.id, snap.id);

    final diffResp = await send(
      'GET',
      '/api/v1/runs/run-1/snapshots/${snap.id}/diff',
    );
    expect(diffResp.statusCode, 200);
    final diff = SnapshotDiff.fromJson(
      jsonDecode(await diffResp.readAsString()) as JsonMap,
    );
    expect(diff.files.single.path, 'a.txt');

    // Mutate file and attempt restore while running -> 409.
    await File(p.join(workspaceDir.path, 'a.txt')).writeAsString('v2\n');
    final conflictResp = await send(
      'POST',
      '/api/v1/runs/run-1/snapshots/${snap.id}/restore',
    );
    expect(conflictResp.statusCode, 409);

    // Pause and restore -> 200.
    await runs.updateStatus('run-1', status: RunStatus.paused);
    final restoreResp = await send(
      'POST',
      '/api/v1/runs/run-1/snapshots/${snap.id}/restore',
    );
    expect(restoreResp.statusCode, 200);
    final restoreDto = RestoreSnapshotResponse.fromJson(
      jsonDecode(await restoreResp.readAsString()) as JsonMap,
    );
    expect(restoreDto.restoredSnapshotId, snap.id);
    expect(restoreDto.safetySnapshot.kind, SnapshotKind.safetyPreRestore);
    expect(
      await File(p.join(workspaceDir.path, 'a.txt')).readAsString(),
      'v1\n',
    );
  });
}
