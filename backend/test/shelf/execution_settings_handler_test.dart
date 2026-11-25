import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/api/settings/execution_settings_handler.dart';
import 'package:agentic_hive_backend/src/data/settings/drift_settings_repository.dart';
import 'package:agentic_hive_backend/src/data/settings/file_workspace_settings_store.dart';
import 'package:agentic_hive_backend/src/data/workspace/drift_workspace_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/settings/execution_settings_service.dart';
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
  late Directory root;
  late AppDatabase db;
  late Handler handler;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_exec_settings_');
    root = Directory(p.join(tempDir.path, 'project'))..createSync();
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    final workspaces = DriftWorkspaceRepository(db);
    final now = DateTime.utc(2026, 11, 22);
    await workspaces.create(
      Workspace(
        id: 'ws-1',
        name: 'project',
        rootPath: root.path,
        isGit: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 7),
        ),
        version: '0.1.0',
        dataDir: tempDir.path,
        startedAt: now,
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (_) => Response.notFound('ws'),
      executionSettingsHandler: ExecutionSettingsHandler(
        DefaultExecutionSettingsService(
          settings: DriftSettingsRepository(db),
          workspaces: workspaces,
          store: FileWorkspaceSettingsStore(),
          shellProvider: const _FixedShell(),
        ),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<Response> send(String method, String path, {Object? body}) async =>
      await handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  group('/api/v1/workspaces/{id}/settings', () {
    test('GET with no overrides returns the built-in defaults', () async {
      final response = await send('GET', '/api/v1/workspaces/ws-1/settings');

      expect(response.statusCode, 200);
      final body = WorkspaceSettingsResponse.fromJson(await readJson(response));
      expect(body.overrides.isEmpty, isTrue);
      expect(
        body.effective.defaultIsolationMode,
        WorkspaceIsolationMode.worktree,
      );
      expect(body.effective.defaultShell, '/bin/sh');
    });

    test('PUT stores overrides that beat the global value', () async {
      await send(
        'PUT',
        '/api/v1/settings/execution',
        body: {'defaultShell': '/bin/global'},
      );

      final response = await send(
        'PUT',
        '/api/v1/workspaces/ws-1/settings',
        body: {
          'defaultIsolationMode': 'direct',
          'ignorePatterns': ['*.log'],
        },
      );

      expect(response.statusCode, 200);
      final body = WorkspaceSettingsResponse.fromJson(await readJson(response));
      expect(
        body.overrides.defaultIsolationMode,
        WorkspaceIsolationMode.direct,
      );
      expect(body.effective.ignorePatterns, ['*.log']);
      expect(body.effective.defaultShell, '/bin/global');
      expect(
        File(p.join(root.path, '.agentic-hive', 'settings.json')).existsSync(),
        isTrue,
      );
    });

    test('PUT rejects machine-specific settings with 400', () async {
      for (final key in ['harnessOverrides', 'theme', 'agentsDir']) {
        final response = await send(
          'PUT',
          '/api/v1/workspaces/ws-1/settings',
          body: {key: 'x'},
        );

        expect(response.statusCode, 400, reason: key);
        expect(await response.readAsString(), contains(key));
      }
    });

    test('PUT rejects an unknown isolation mode with 400', () async {
      final response = await send(
        'PUT',
        '/api/v1/workspaces/ws-1/settings',
        body: {'defaultIsolationMode': 'sideways'},
      );

      expect(response.statusCode, 400);
    });

    test('PUT rejects a body that is not an object', () async {
      final response = await send(
        'PUT',
        '/api/v1/workspaces/ws-1/settings',
        body: ['x'],
      );

      expect(response.statusCode, 400);
    });

    test('unknown workspace answers 404', () async {
      final response = await send('GET', '/api/v1/workspaces/nope/settings');

      expect(response.statusCode, 404);
    });
  });

  group('/api/v1/settings/execution', () {
    test('PUT then GET round-trips the global settings', () async {
      final put = await send(
        'PUT',
        '/api/v1/settings/execution',
        body: {
          'defaultIsolationMode': 'direct',
          'ignorePatterns': ['build/'],
          'defaultShell': '/bin/zsh',
        },
      );
      expect(put.statusCode, 200);

      final get = await send('GET', '/api/v1/settings/execution');

      expect(
        ExecutionSettings.fromJson(await readJson(get)),
        const ExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.direct,
          ignorePatterns: ['build/'],
          defaultShell: '/bin/zsh',
        ),
      );
    });

    test('PUT rejects machine-specific settings with 400', () async {
      final response = await send(
        'PUT',
        '/api/v1/settings/execution',
        body: {'harnessOverrides': <String, String>{}},
      );

      expect(response.statusCode, 400);
    });
  });
}

final class _FixedShell implements DefaultShellProvider {
  const new();

  @override
  String get defaultShell => '/bin/sh';
}
