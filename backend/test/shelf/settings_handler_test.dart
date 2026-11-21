import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/api/settings/settings_handler.dart';
import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/data/agents/agent_directory_watcher.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/settings/drift_settings_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/settings/executable_validator.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_service.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

Request _jsonRequest(String path, {required String method, Object? body}) =>
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: const {'content-type': 'application/json'},
      body: body == null ? null : (body is String ? body : jsonEncode(body)),
    );

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late AgentDirectoryWatcher watcher;
  late DefaultHarnessService harnessService;
  late DefaultSettingsService settingsService;
  late Handler handler;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_handler_');
    Directory(p.join(tempDir.path, 'agents')).createSync();
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();

    final agentRepository = LocalAgentRepository(
      agentsDir: p.join(tempDir.path, 'agents'),
    );
    watcher = AgentDirectoryWatcher(
      agentsDir: p.join(tempDir.path, 'agents'),
      repository: agentRepository,
      registry: ConnectionRegistry(),
    );
    harnessService = DefaultHarnessService(detectors: const []);
    settingsService = DefaultSettingsService(
      repository: DriftSettingsRepository(db),
      config: AppConfig(mode: RuntimeMode.development, dataDir: tempDir.path),
      executableValidator: _AlwaysValidExecutable(),
      agentRepository: agentRepository,
      agentDirectoryWatcher: watcher,
      harnessService: harnessService,
    );

    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 3),
        ),
        version: '0.1.0',
        dataDir: tempDir.path,
        startedAt: DateTime.utc(2026, 11, 21),
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (_) => Response(418),
      settingsHandler: SettingsHandler(settingsService),
    );

    addTearDown(() async {
      await settingsService.dispose();
      await harnessService.dispose();
      await watcher.close();
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('/api/v1/settings', () {
    test('GET returns 200 with AppSettings JSON', () async {
      final response = await handler(buildRequest('/api/v1/settings'));
      expect(response.statusCode, 200);
      final settings = AppSettings.fromJson(await readJson(response));
      expect(settings.agentsDir, p.join(tempDir.path, 'agents'));
      expect(settings.defaultAgentsDir, p.join(tempDir.path, 'agents'));
      expect(settings.defaultWorkspaceDir, isNull);
      expect(settings.harnessOverrides, isEmpty);
    });

    test('PUT updates valid settings and returns 200', () async {
      final customDir = Directory(p.join(tempDir.path, 'custom'))..createSync();
      final response = await handler(
        _jsonRequest(
          '/api/v1/settings',
          method: 'PUT',
          body: UpdateSettingsRequest(
            agentsDir: customDir.path,
            defaultWorkspaceDir: tempDir.path,
          ).toJson(),
        ),
      );
      expect(response.statusCode, 200);
      final settings = AppSettings.fromJson(await readJson(response));
      expect(settings.agentsDir, customDir.path);
      expect(settings.defaultWorkspaceDir, tempDir.path);
    });

    test(
      'PUT returns 400 ApiError with per-field details on invalid paths',
      () async {
        final response = await handler(
          _jsonRequest(
            '/api/v1/settings',
            method: 'PUT',
            body: const UpdateSettingsRequest(
              agentsDir: 'relative/path',
              defaultWorkspaceDir: 'another/relative',
            ).toJson(),
          ),
        );

        expect(response.statusCode, 400);
        final error = ApiError.fromJson(await readJson(response));
        expect(error.code, ApiErrorCode.badRequest);
        expect(error.details, isNotNull);
        expect(
          error.details!.keys,
          unorderedEquals(['agentsDir', 'defaultWorkspaceDir']),
        );
      },
    );

    test('PUT returns 400 on malformed JSON', () async {
      final response = await handler(
        _jsonRequest(
          '/api/v1/settings',
          method: 'PUT',
          body: '{not valid json',
        ),
      );
      expect(response.statusCode, 400);
      final error = ApiError.fromJson(await readJson(response));
      expect(error.code, ApiErrorCode.badRequest);
    });
  });
}

final class _AlwaysValidExecutable implements ExecutableValidator {
  @override
  Future<bool> isExecutable(String path) async => true;
}
