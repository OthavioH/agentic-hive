import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/api/workspace/workspaces_handler.dart';
import 'package:agentic_hive_backend/src/data/harnesses/io_process_runner.dart';
import 'package:agentic_hive_backend/src/data/runs/drift_run_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/drift_workspace_repository.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
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
  late AppDatabase db;
  late DriftRunRepository runs;
  late Handler handler;
  var counter = 0;

  final workflow = Workflow(
    id: 'wf-1',
    name: 'Flow',
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
    createdAt: DateTime.utc(2026, 11, 22),
    updatedAt: DateTime.utc(2026, 11, 22),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_workspaces_');
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    runs = DriftRunRepository(db);
    const git = GitClient(IoProcessRunner());
    final service = WorkspaceService(
      workspaces: DriftWorkspaceRepository(db),
      capabilities: const WorkspaceCapabilitiesService(git),
      generateId: () => 'ws-${++counter}',
      now: () => DateTime.utc(2026, 11, 22, 12),
    );
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 7),
        ),
        version: '0.1.0',
        dataDir: tempDir.path,
        startedAt: DateTime.utc(2026, 11, 22),
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (_) => Response.notFound('ws'),
      workspacesHandler: WorkspacesHandler(service: service),
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Directory makeFolder(String name) =>
      Directory(p.join(tempDir.path, name))..createSync(recursive: true);

  Future<Response> send(String method, String path, {Object? body}) async =>
      await handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<Workspace> create(String rootPath, {String? name}) async {
    final response = await send(
      'POST',
      '/api/v1/workspaces',
      body: {'rootPath': rootPath, 'name': ?name},
    );
    expect(response.statusCode, 201);
    return Workspace.fromJson(await readJson(response));
  }

  Future<void> insertRun(
    String id,
    String workspaceId,
    RunStatus status,
  ) async {
    await runs.create(
      Run(
        id: id,
        workflowName: workflow.name,
        workflowDefinition: workflow,
        workspacePath: '/x',
        workspaceId: workspaceId,
        status: status,
        startedAt: DateTime.utc(2026, 11, 22, 10),
      ),
    );
  }

  group('POST /api/v1/workspaces', () {
    test('registers a non-git folder flagged as non-git, named after the '
        'folder', () async {
      final folder = makeFolder('notes');

      final workspace = await create(folder.path);

      expect(workspace.id, 'ws-1');
      expect(workspace.name, 'notes');
      expect(workspace.rootPath, p.normalize(folder.path));
      expect(workspace.isGit, isFalse);
      expect(workspace.activeRunCount, 0);
    });

    test('auto-detects a git repository', () async {
      final folder = makeFolder('repo');
      final init = await Process.run('git', ['init', folder.path]);
      expect(init.exitCode, 0);

      final workspace = await create(folder.path);

      expect(workspace.isGit, isTrue);
    });

    test('uses the provided name, trimmed', () async {
      final workspace = await create(makeFolder('a').path, name: '  Mine  ');

      expect(workspace.name, 'Mine');
    });

    test('rejects a duplicate root folder with 409', () async {
      final folder = makeFolder('dup');
      await create(folder.path);

      final response = await send(
        'POST',
        '/api/v1/workspaces',
        body: {'rootPath': '${folder.path}${p.separator}'},
      );

      expect(response.statusCode, 409);
      expect(
        ApiError.fromJson(await readJson(response)).code,
        ApiErrorCode.conflict,
      );
    });

    test('rejects a relative path with 400', () async {
      final response = await send(
        'POST',
        '/api/v1/workspaces',
        body: {'rootPath': 'relative/folder'},
      );

      expect(response.statusCode, 400);
    });

    test('rejects a folder that does not exist with 400', () async {
      final response = await send(
        'POST',
        '/api/v1/workspaces',
        body: {'rootPath': p.join(tempDir.path, 'missing')},
      );

      expect(response.statusCode, 400);
    });

    test('rejects a blank name with 400', () async {
      final response = await send(
        'POST',
        '/api/v1/workspaces',
        body: {'rootPath': makeFolder('b').path, 'name': '   '},
      );

      expect(response.statusCode, 400);
    });

    test('rejects a malformed body with 400', () async {
      final response = await send('POST', '/api/v1/workspaces', body: {});

      expect(response.statusCode, 400);
    });
  });

  group('GET /api/v1/workspaces', () {
    test('lists registered workspaces with their active run count', () async {
      final a = await create(makeFolder('a').path);
      await create(makeFolder('b').path);
      await insertRun('r1', a.id, RunStatus.running);
      await insertRun('r2', a.id, RunStatus.paused);
      await insertRun('r3', a.id, RunStatus.succeeded);

      final response = await send('GET', '/api/v1/workspaces');

      expect(response.statusCode, 200);
      final list = WorkspaceListResponse.fromJson(await readJson(response));
      expect(list.items.map((w) => w.name), ['a', 'b']);
      expect(list.items.first.activeRunCount, 2);
      expect(list.items.last.activeRunCount, 0);
    });

    test('is empty when nothing is registered', () async {
      final response = await send('GET', '/api/v1/workspaces');

      expect(
        WorkspaceListResponse.fromJson(await readJson(response)).items,
        isEmpty,
      );
    });
  });

  group('GET /api/v1/workspaces/:id', () {
    test('returns the workspace', () async {
      final created = await create(makeFolder('a').path);

      final response = await send('GET', '/api/v1/workspaces/${created.id}');

      expect(response.statusCode, 200);
      expect(Workspace.fromJson(await readJson(response)), created);
    });

    test('returns 404 for an unknown id', () async {
      final response = await send('GET', '/api/v1/workspaces/nope');

      expect(response.statusCode, 404);
    });
  });

  group('PATCH /api/v1/workspaces/:id', () {
    test('renames the workspace', () async {
      final created = await create(makeFolder('a').path);

      final response = await send(
        'PATCH',
        '/api/v1/workspaces/${created.id}',
        body: {'name': 'Renamed'},
      );

      expect(response.statusCode, 200);
      final renamed = Workspace.fromJson(await readJson(response));
      expect(renamed.name, 'Renamed');
      expect(renamed.rootPath, created.rootPath);
    });

    test('rejects a blank name with 400', () async {
      final created = await create(makeFolder('a').path);

      final response = await send(
        'PATCH',
        '/api/v1/workspaces/${created.id}',
        body: {'name': ''},
      );

      expect(response.statusCode, 400);
    });

    test('returns 404 for an unknown id', () async {
      final response = await send(
        'PATCH',
        '/api/v1/workspaces/nope',
        body: {'name': 'x'},
      );

      expect(response.statusCode, 404);
    });
  });

  group('DELETE /api/v1/workspaces/:id', () {
    test('unregisters without deleting any file', () async {
      final folder = makeFolder('keep');
      File(p.join(folder.path, 'note.txt')).writeAsStringSync('hi');
      final created = await create(folder.path);

      final response = await send('DELETE', '/api/v1/workspaces/${created.id}');

      expect(response.statusCode, 200);
      expect(
        (await send('GET', '/api/v1/workspaces/${created.id}')).statusCode,
        404,
      );
      expect(File(p.join(folder.path, 'note.txt')).readAsStringSync(), 'hi');
      // The folder can be registered again afterwards.
      await create(folder.path);
    });

    test('is refused with 409 while runs are active', () async {
      final created = await create(makeFolder('busy').path);
      await insertRun('r1', created.id, RunStatus.running);

      final response = await send('DELETE', '/api/v1/workspaces/${created.id}');

      expect(response.statusCode, 409);
      expect(
        (await send('GET', '/api/v1/workspaces/${created.id}')).statusCode,
        200,
      );
    });

    test('removes the history of finished runs with the workspace', () async {
      final created = await create(makeFolder('done').path);
      await insertRun('r1', created.id, RunStatus.succeeded);

      final response = await send('DELETE', '/api/v1/workspaces/${created.id}');

      expect(response.statusCode, 200);
      expect((await runs.getById('r1')).isFailure, isTrue);
    });

    test('returns 404 for an unknown id', () async {
      final response = await send('DELETE', '/api/v1/workspaces/nope');

      expect(response.statusCode, 404);
    });
  });
}
