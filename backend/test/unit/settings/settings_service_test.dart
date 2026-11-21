import 'dart:io';

import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/agent_directory_watcher.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/settings/drift_settings_repository.dart';
import 'package:agentic_hive_backend/src/data/settings/os_executable_validator.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/settings/executable_validator.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_service.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Directory defaultAgentsDir;
  late Directory customAgentsDir;
  late Directory workspaceDir;
  late AppDatabase db;
  late DriftSettingsRepository repository;
  late LocalAgentRepository agentRepository;
  late AgentDirectoryWatcher agentWatcher;
  late _FakeDetector claudeDetector;
  late _FakeDetector codexDetector;
  late DefaultHarnessService harnessService;
  late _FakeExecutableValidator executableValidator;
  late DefaultSettingsService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_service_');
    defaultAgentsDir = Directory(p.join(tempDir.path, 'agents'))..createSync();
    customAgentsDir = Directory(p.join(tempDir.path, 'custom-agents'))
      ..createSync();
    workspaceDir = Directory(p.join(tempDir.path, 'workspace'))..createSync();

    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    repository = DriftSettingsRepository(db);

    agentRepository = LocalAgentRepository(agentsDir: defaultAgentsDir.path);
    agentWatcher = AgentDirectoryWatcher(
      agentsDir: defaultAgentsDir.path,
      repository: agentRepository,
      registry: ConnectionRegistry(),
    );

    claudeDetector = _FakeDetector(HarnessId.claudeCode);
    codexDetector = _FakeDetector(HarnessId.codex);
    harnessService = DefaultHarnessService(
      detectors: [claudeDetector, codexDetector],
    );

    executableValidator = _FakeExecutableValidator();
    service = DefaultSettingsService(
      repository: repository,
      config: AppConfig(mode: RuntimeMode.development, dataDir: tempDir.path),
      executableValidator: executableValidator,
      agentRepository: agentRepository,
      agentDirectoryWatcher: agentWatcher,
      harnessService: harnessService,
    );

    addTearDown(() async {
      await service.dispose();
      await harnessService.dispose();
      await agentWatcher.close();
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('getSettings', () {
    test('returns defaults when SQLite settings table is empty', () async {
      final result = await service.getSettings();
      expect(result, isA<Success<AppSettings>>());
      final settings = (result as Success<AppSettings>).value;
      expect(settings.agentsDir, defaultAgentsDir.path);
      expect(settings.defaultAgentsDir, defaultAgentsDir.path);
      expect(settings.defaultWorkspaceDir, isNull);
      expect(settings.harnessOverrides, isEmpty);
    });
  });

  group('updateSettings atomic validation', () {
    test(
      'collects all per-field errors and performs no partial writes',
      () async {
        final nonExecFile = File(p.join(tempDir.path, 'not-exec.txt'))
          ..writeAsStringSync('hello');
        final missingDir = p.join(tempDir.path, 'does-not-exist');

        final emitted = <AppSettings>[];
        final sub = service.settingsUpdates.listen(emitted.add);
        addTearDown(sub.cancel);

        final result = await service.updateSettings(
          UpdateSettingsRequest(
            agentsDir: 'relative/agents',
            defaultWorkspaceDir: missingDir,
            harnessOverrides: {
              HarnessId.claudeCode: 'relative/claude',
              HarnessId.codex: nonExecFile.path,
            },
          ),
        );

        expect(result, isA<FailureResult<AppSettings>>());
        final failure = (result as FailureResult<AppSettings>).failure;
        expect(failure, isA<ValidationFailure>());
        final validation = failure as ValidationFailure;
        expect(validation.details, isNotNull);
        expect(
          validation.details!.keys,
          unorderedEquals([
            'agentsDir',
            'defaultWorkspaceDir',
            'harnessOverrides.claude_code',
            'harnessOverrides.codex',
          ]),
        );

        // Nothing persisted or emitted.
        final stored = await repository.getAll();
        expect((stored as Success<Map<String, String>>).value, isEmpty);
        expect(emitted, isEmpty);
      },
    );
  });

  group('updateSettings live F2/F3 reload', () {
    test(
      'updates agentsDir without moving files and resets to default',
      () async {
        final existingAgent = File(p.join(defaultAgentsDir.path, 'a.md'))
          ..writeAsStringSync('# Agent A');
        final customAgent = File(p.join(customAgentsDir.path, 'b.md'))
          ..writeAsStringSync('# Agent B');

        final emitted = <AppSettings>[];
        final sub = service.settingsUpdates.listen(emitted.add);
        addTearDown(sub.cancel);

        final updateRes = await service.updateSettings(
          UpdateSettingsRequest(
            agentsDir: customAgentsDir.path,
            defaultWorkspaceDir: workspaceDir.path,
          ),
        );
        expect(updateRes, isA<Success<AppSettings>>());
        final updated = (updateRes as Success<AppSettings>).value;
        expect(updated.agentsDir, customAgentsDir.path);
        expect(updated.defaultWorkspaceDir, workspaceDir.path);

        // F2 repository & watcher switched without moving files.
        await pumpEventQueue();
        expect(agentRepository.agentsDir, customAgentsDir.path);
        expect(agentWatcher.agentsDir, customAgentsDir.path);
        expect(existingAgent.existsSync(), isTrue);
        expect(customAgent.existsSync(), isTrue);
        expect(emitted, [updated]);

        // Reset agentsDir & clear defaultWorkspaceDir.
        final resetRes = await service.updateSettings(
          const UpdateSettingsRequest(agentsDir: '', defaultWorkspaceDir: ''),
        );
        expect(resetRes, isA<Success<AppSettings>>());
        final reset = (resetRes as Success<AppSettings>).value;
        expect(reset.agentsDir, defaultAgentsDir.path);
        expect(reset.defaultWorkspaceDir, isNull);
        expect(agentRepository.agentsDir, defaultAgentsDir.path);
        expect(agentWatcher.agentsDir, defaultAgentsDir.path);
      },
    );

    test('updates harnessOverrides and triggers F3 re-detection only for '
        'changed harnesses', () async {
      final fakeClaude = p.join(tempDir.path, 'claude.exe');
      executableValidator.allowedPaths.add(fakeClaude);

      final statusEvents = <HarnessInfo>[];
      final sub = harnessService.statusUpdates.listen(statusEvents.add);
      addTearDown(sub.cancel);

      final res1 = await service.updateSettings(
        UpdateSettingsRequest(
          harnessOverrides: {HarnessId.claudeCode: fakeClaude},
        ),
      );
      expect(res1, isA<Success<AppSettings>>());
      await pumpEventQueue();
      expect(claudeDetector.lastOverride, fakeClaude);
      expect(claudeDetector.detectCalls, 1);
      expect(codexDetector.detectCalls, 0);
      expect(statusEvents.map((e) => e.id), [HarnessId.claudeCode]);

      // Clearing claude override triggers re-detection for claude only.
      statusEvents.clear();
      final res2 = await service.updateSettings(
        const UpdateSettingsRequest(
          harnessOverrides: {HarnessId.claudeCode: ''},
        ),
      );
      expect(res2, isA<Success<AppSettings>>());
      await pumpEventQueue();
      expect(claudeDetector.lastOverride, isNull);
      expect(claudeDetector.detectCalls, 2);
      expect(codexDetector.detectCalls, 0);
      expect(statusEvents.map((e) => e.id), [HarnessId.claudeCode]);
    });
  });

  group('ExecutableValidator', () {
    test(
      'WindowsExecutableValidator checks file existence and extension',
      () async {
        const validator = WindowsExecutableValidator();
        final dir = await Directory.systemTemp.createTemp('win_exec_val_');
        addTearDown(() => dir.delete(recursive: true));

        final exe = File(p.join(dir.path, 'tool.exe'))
          ..writeAsStringSync('bin');
        final txt = File(p.join(dir.path, 'notes.txt'))
          ..writeAsStringSync('text');

        expect(await validator.isExecutable(exe.path), isTrue);
        expect(await validator.isExecutable(txt.path), isFalse);
        expect(await validator.isExecutable(dir.path), isFalse);
        expect(
          await validator.isExecutable(p.join(dir.path, 'missing.exe')),
          isFalse,
        );
      },
    );
  });
}

final class _FakeExecutableValidator implements ExecutableValidator {
  final Set<String> allowedPaths = {};

  @override
  Future<bool> isExecutable(String path) async => allowedPaths.contains(path);
}

final class _FakeDetector implements HarnessDetector {
  new(this.id);

  @override
  final HarnessId id;

  String? lastOverride;
  int detectCalls = 0;

  @override
  void setExecutableOverride(String? path) {
    lastOverride = path;
  }

  @override
  Future<HarnessInfo> detect() async {
    detectCalls++;
    return HarnessInfo(
      id: id,
      displayName: id.displayName,
      status: HarnessStatus.ready,
      executablePath: lastOverride ?? '/usr/bin/${id.wireName}',
      version: '1.0.0',
      checkedAt: DateTime.utc(2026, 11, 21),
    );
  }
}
