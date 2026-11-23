import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/settings/drift_settings_repository.dart';
import 'package:agentic_hive_backend/src/data/settings/file_workspace_settings_store.dart';
import 'package:agentic_hive_backend/src/data/workspace/drift_workspace_repository.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/settings/execution_settings_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Directory root;
  late AppDatabase db;
  late DefaultExecutionSettingsService service;
  late File overridesFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('execution_settings_');
    root = Directory(p.join(tempDir.path, 'project'))..createSync();
    overridesFile = File(p.join(root.path, '.agentic-hive', 'settings.json'));
    db = AppDatabase(NativeDatabase.memory());
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
    service = DefaultExecutionSettingsService(
      settings: DriftSettingsRepository(db),
      workspaces: workspaces,
      store: FileWorkspaceSettingsStore(),
      shellProvider: const _FixedShell('/bin/default-shell'),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<EffectiveExecutionSettings> effective() async =>
      (await service.effectiveFor('ws-1')).valueOrNull!;

  group('fallback', () {
    test('with nothing set the built-in defaults apply', () async {
      final result = await effective();

      expect(result.defaultIsolationMode, WorkspaceIsolationMode.worktree);
      expect(result.ignorePatterns, isEmpty);
      expect(result.defaultShell, '/bin/default-shell');
    });

    test('an absent workspace key falls back to the global value', () async {
      await service.updateGlobal(
        const ExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.direct,
          ignorePatterns: ['build/'],
          defaultShell: '/bin/global-shell',
        ),
      );

      final result = await effective();

      expect(result.defaultIsolationMode, WorkspaceIsolationMode.direct);
      expect(result.ignorePatterns, ['build/']);
      expect(result.defaultShell, '/bin/global-shell');
    });

    test('a workspace override beats the global value', () async {
      await service.updateGlobal(
        const ExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.direct,
          ignorePatterns: ['build/'],
          defaultShell: '/bin/global-shell',
        ),
      );
      await service.updateForWorkspace(
        'ws-1',
        const ExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.worktree,
          ignorePatterns: ['*.log'],
          defaultShell: '/bin/ws-shell',
        ),
      );

      final result = await effective();

      expect(result.defaultIsolationMode, WorkspaceIsolationMode.worktree);
      expect(result.ignorePatterns, ['*.log']);
      expect(result.defaultShell, '/bin/ws-shell');
    });

    test('overrides are per key: unset keys still inherit', () async {
      await service.updateGlobal(
        const ExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.direct,
          defaultShell: '/bin/global-shell',
        ),
      );
      await service.updateForWorkspace(
        'ws-1',
        const ExecutionSettings(defaultShell: '/bin/ws-shell'),
      );

      final result = await effective();

      expect(result.defaultIsolationMode, WorkspaceIsolationMode.direct);
      expect(result.defaultShell, '/bin/ws-shell');
    });

    test('an empty ignorePatterns override clears the global list', () async {
      await service.updateGlobal(
        const ExecutionSettings(ignorePatterns: ['build/']),
      );
      await service.updateForWorkspace(
        'ws-1',
        const ExecutionSettings(ignorePatterns: []),
      );

      expect((await effective()).ignorePatterns, isEmpty);
    });

    test('clearing the overrides falls back again', () async {
      await service.updateGlobal(
        const ExecutionSettings(defaultShell: '/bin/global-shell'),
      );
      await service.updateForWorkspace(
        'ws-1',
        const ExecutionSettings(defaultShell: '/bin/ws-shell'),
      );
      await service.updateForWorkspace('ws-1', const ExecutionSettings());

      expect((await effective()).defaultShell, '/bin/global-shell');
      expect(overridesFile.existsSync(), isFalse);
    });
  });

  group('response', () {
    test('reports overrides, inherited global and effective values', () async {
      await service.updateGlobal(
        const ExecutionSettings(defaultShell: '/bin/global-shell'),
      );

      final response = (await service.updateForWorkspace(
        'ws-1',
        const ExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.direct,
        ),
      )).valueOrNull!;

      expect(
        response.overrides,
        const ExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.direct,
        ),
      );
      expect(response.global.defaultShell, '/bin/global-shell');
      expect(
        response.global.defaultIsolationMode,
        WorkspaceIsolationMode.worktree,
      );
      expect(
        response.effective.defaultIsolationMode,
        WorkspaceIsolationMode.direct,
      );
    });
  });

  group('workspace file', () {
    test('writes only the set keys to .agentic-hive/settings.json', () async {
      await service.updateForWorkspace(
        'ws-1',
        const ExecutionSettings(defaultShell: '/bin/ws-shell'),
      );

      final json = jsonDecode(overridesFile.readAsStringSync());

      expect(json, {'defaultShell': '/bin/ws-shell'});
    });

    test('is read from edits made outside the app', () async {
      overridesFile.parent.createSync(recursive: true);
      overridesFile.writeAsStringSync(
        jsonEncode({'defaultIsolationMode': 'direct'}),
      );

      expect(
        (await effective()).defaultIsolationMode,
        WorkspaceIsolationMode.direct,
      );
    });

    test('a malformed file is a validation failure', () async {
      overridesFile.parent.createSync(recursive: true);
      overridesFile.writeAsStringSync('{not json');

      final result = await service.effectiveFor('ws-1');

      expect(result, isA<FailureResult<EffectiveExecutionSettings>>());
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('an unknown workspace is not found', () async {
      final result = await service.getForWorkspace('missing');

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('machine-specific settings', () {
    test('keys outside the overridable set in the file are ignored', () async {
      await service.updateGlobal(
        const ExecutionSettings(defaultShell: '/bin/global-shell'),
      );
      overridesFile.parent.createSync(recursive: true);
      overridesFile.writeAsStringSync(
        jsonEncode({
          'harnessOverrides': {'codex': '/tmp/codex'},
          'theme': 'dark',
          'agentsDir': '/tmp/agents',
        }),
      );

      final response = (await service.getForWorkspace('ws-1')).valueOrNull!;

      expect(response.overrides.isEmpty, isTrue);
      expect(response.effective, response.global);
    });
  });

  group('validation', () {
    test('rejects a blank shell and blank patterns', () async {
      final result = await service.updateForWorkspace(
        'ws-1',
        const ExecutionSettings(defaultShell: '  ', ignorePatterns: ['']),
      );

      final failure = result.failureOrNull! as ValidationFailure;
      expect(failure.details!.keys, {'defaultShell', 'ignorePatterns'});
      expect(overridesFile.existsSync(), isFalse);
    });

    test('global update rejects a blank shell', () async {
      final result = await service.updateGlobal(
        const ExecutionSettings(defaultShell: ''),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });
}

final class _FixedShell implements DefaultShellProvider {
  const new(this.defaultShell);

  @override
  final String defaultShell;
}
