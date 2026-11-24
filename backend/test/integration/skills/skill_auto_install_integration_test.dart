import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/api/skills/skill_auto_install_handler.dart';
import 'package:agentic_hive_backend/src/config/app_config.dart';
import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/agent_directory_watcher.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/harnesses/claude_code_skill_installer.dart';
import 'package:agentic_hive_backend/src/data/harnesses/shared_agents_skill_installer.dart';
import 'package:agentic_hive_backend/src/data/settings/drift_settings_repository.dart';
import 'package:agentic_hive_backend/src/data/skills/metadata_skill_auto_install_mark_store.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/db/metadata_repository.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_skill_installer.dart';
import 'package:agentic_hive_backend/src/domain/settings/executable_validator.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_service.dart';
import 'package:agentic_hive_backend/src/domain/skills/skill_auto_install_service.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill_loader.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempHome;
  late Directory dataDir;
  late AppDatabase db;
  late _FakeBundledSkillLoader loader;
  late _FakeMcpInstaller mcpInstaller;
  late _FakeDetector claudeDetector;
  late _FakeDetector codexDetector;
  late _FakeDetector geminiDetector;
  late _FakeDetector agyDetector;

  PlatformPaths tempPaths() => platformPathsFor(
    Platform.operatingSystem,
    environment: <String, String>{
      'HOME': tempHome.path,
      'USERPROFILE': tempHome.path,
      'LOCALAPPDATA': tempHome.path,
    },
  );

  setUp(() {
    tempHome = Directory.systemTemp.createTempSync('hive_auto_int_home_');
    dataDir = Directory.systemTemp.createTempSync('hive_auto_int_data_');
    Directory(p.join(dataDir.path, 'agents')).createSync(recursive: true);
    db = AppDatabase(NativeDatabase.memory());
    loader = _FakeBundledSkillLoader(_makeBundle('v1'));
    mcpInstaller = _FakeMcpInstaller();
    claudeDetector = _FakeDetector(HarnessId.claudeCode, present: true);
    codexDetector = _FakeDetector(HarnessId.codex, present: true);
    geminiDetector = _FakeDetector(HarnessId.geminiCli, present: false);
    agyDetector = _FakeDetector(HarnessId.antigravity, present: false);
  });

  tearDown(() async {
    await db.close();
    if (tempHome.existsSync()) tempHome.deleteSync(recursive: true);
    if (dataDir.existsSync()) dataDir.deleteSync(recursive: true);
  });

  Future<
    ({
      DefaultHarnessService harness,
      DefaultSettingsService settings,
      DefaultSkillAutoInstallService autoInstall,
      AgentDirectoryWatcher watcher,
    })
  >
  buildGraph() async {
    final paths = tempPaths();
    final skillInstallers = HarnessSkillInstallerRegistry(
      <HarnessSkillInstaller>[
        ClaudeCodeSkillInstaller(
          platformPaths: paths,
          bundledSkillLoader: loader,
          appVersion: '1.0.0',
        ),
        SharedAgentsSkillInstaller(
          platformPaths: paths,
          bundledSkillLoader: loader,
          appVersion: '1.0.0',
        ),
      ],
    );
    final mcpInstallers = HarnessMcpInstallerRegistry(<HarnessMcpInstaller>[
      _PerHarnessMcp(HarnessId.claudeCode, mcpInstaller),
      _PerHarnessMcp(HarnessId.codex, mcpInstaller),
      _PerHarnessMcp(HarnessId.geminiCli, mcpInstaller),
    ]);
    final harness = DefaultHarnessService(
      detectors: <HarnessDetector>[
        claudeDetector,
        codexDetector,
        geminiDetector,
        agyDetector,
      ],
      mcpInstallers: mcpInstallers,
      mcpLocator: HiveMcpLocator(
        overrideCommand: const HiveMcpLaunchCommand(executable: 'hive_mcp'),
      ),
      skillInstallers: skillInstallers,
    );
    final agentRepo = LocalAgentRepository(
      agentsDir: p.join(dataDir.path, 'agents'),
    );
    final watcher = AgentDirectoryWatcher(
      agentsDir: p.join(dataDir.path, 'agents'),
      repository: agentRepo,
      registry: ConnectionRegistry(),
    );
    final settings = DefaultSettingsService(
      repository: DriftSettingsRepository(db),
      config: AppConfig(mode: RuntimeMode.development, dataDir: dataDir.path),
      executableValidator: _FakeExecutableValidator(),
      agentRepository: agentRepo,
      agentDirectoryWatcher: watcher,
      harnessService: harness,
    );
    final markStore = MetadataSkillAutoInstallMarkStore(
      DriftMetadataRepository(db),
    );
    final autoInstall = DefaultSkillAutoInstallService(
      harnessService: harness,
      settingsService: settings,
      markStore: markStore,
      skillInstallers: skillInstallers,
    );
    return (
      harness: harness,
      settings: settings,
      autoInstall: autoInstall,
      watcher: watcher,
    );
  }

  test('first scan, second start, and later harness use temp home', () async {
    final g1 = await buildGraph();
    g1.autoInstall.start();
    await g1.autoInstall.idle();

    final claudeSkillDir = p.join(
      tempHome.path,
      '.claude',
      'skills',
      agenticHiveSkillName,
    );
    final sharedSkillDir = p.join(
      tempHome.path,
      '.agents',
      'skills',
      agenticHiveSkillName,
    );
    expect(File(p.join(claudeSkillDir, 'SKILL.md')).existsSync(), isTrue);
    expect(
      File(p.join(claudeSkillDir, 'hive-skill.json')).existsSync(),
      isTrue,
    );
    expect(File(p.join(sharedSkillDir, 'SKILL.md')).existsSync(), isTrue);
    expect(mcpInstaller.installedFor, {HarnessId.claudeCode, HarnessId.codex});

    final handler = SkillAutoInstallHandler(g1.autoInstall);
    final res = await handler.getNotice(
      Request(
        'GET',
        Uri.parse('http://localhost/api/v1/skills/auto-install/notice'),
      ),
    );
    final decoded = SkillAutoInstallNoticeResponse.fromJson(
      jsonDecode(await res.readAsString()) as JsonMap,
    );
    expect(decoded.notice!.results.map((r) => r.harnessId), [
      HarnessId.claudeCode,
      HarnessId.codex,
    ]);
    for (final r in decoded.notice!.results) {
      for (final path in r.skill.paths) {
        expect(path, startsWith(tempHome.path));
      }
    }

    await g1.autoInstall.dispose();
    await g1.settings.dispose();
    await g1.harness.dispose();
    await g1.watcher.close();

    // Second start: delete claude skill folder; must NOT be recreated.
    Directory(claudeSkillDir).deleteSync(recursive: true);
    mcpInstaller.installCalls = 0;

    final g2 = await buildGraph();
    addTearDown(() async {
      await g2.autoInstall.dispose();
      await g2.settings.dispose();
      await g2.harness.dispose();
      await g2.watcher.close();
    });
    g2.autoInstall.start();
    await g2.autoInstall.idle();

    expect(Directory(claudeSkillDir).existsSync(), isFalse);
    expect(mcpInstaller.installCalls, 0);

    // Later harness: gemini becomes present; gets MCP + alreadyInstalled skill.
    geminiDetector.present = true;
    await g2.harness.refreshOne(HarnessId.geminiCli);
    await g2.autoInstall.idle();

    expect(mcpInstaller.installedFor.contains(HarnessId.geminiCli), isTrue);
    final geminiResult = g2.autoInstall.pendingNotice!.results.single;
    expect(geminiResult.harnessId, HarnessId.geminiCli);
    expect(
      geminiResult.skill.outcome,
      SkillAutoInstallOutcome.alreadyInstalled,
    );
    expect(geminiResult.mcp.outcome, SkillAutoInstallOutcome.installed);
    expect(Directory(claudeSkillDir).existsSync(), isFalse);
  });

  test('outdated skill is never updated automatically', () async {
    final paths = tempPaths();
    final installer = ClaudeCodeSkillInstaller(
      platformPaths: paths,
      bundledSkillLoader: loader,
      appVersion: '1.0.0',
    );
    expect(installer.install(), isA<Success<void>>());
    final skillMd = File(p.join(installer.skillDirectory!, 'SKILL.md'));
    final v1Content = skillMd.readAsStringSync();

    loader.bundle = _makeBundle('v2');

    final g = await buildGraph();
    addTearDown(() async {
      await g.autoInstall.dispose();
      await g.settings.dispose();
      await g.harness.dispose();
      await g.watcher.close();
    });
    g.autoInstall.start();
    await g.autoInstall.idle();

    expect(skillMd.readAsStringSync(), v1Content);
  });

  test('autoInstallSkills off skips, turning on installs', () async {
    final g = await buildGraph();
    addTearDown(() async {
      await g.autoInstall.dispose();
      await g.settings.dispose();
      await g.harness.dispose();
      await g.watcher.close();
    });
    await g.settings.updateSettings(
      const UpdateSettingsRequest(autoInstallSkills: false),
    );

    g.autoInstall.start();
    await g.autoInstall.idle();
    expect(tempHome.listSync(), isEmpty);
    expect(mcpInstaller.installCalls, 0);

    await g.settings.updateSettings(
      const UpdateSettingsRequest(autoInstallSkills: true),
    );
    await g.autoInstall.idle();
    expect(mcpInstaller.installedFor, {HarnessId.claudeCode, HarnessId.codex});
  });
}

BundledSkill _makeBundle(String version) {
  final files = <String, List<int>>{
    'SKILL.md': utf8.encode('# Agentic Hive $version\n'),
  };
  return BundledSkill(
    name: agenticHiveSkillName,
    files: files,
    contentHash: computeSkillContentHash(files),
  );
}

final class _FakeBundledSkillLoader implements BundledSkillLoader {
  new(this.bundle);
  BundledSkill bundle;

  @override
  Result<BundledSkill> load(String name) => Success(bundle);
}

final class _FakeDetector implements HarnessDetector {
  new(this.id, {required this.present});

  @override
  final HarnessId id;
  bool present;

  @override
  void setExecutableOverride(String? path) {}

  @override
  Future<HarnessInfo> detect() async => HarnessInfo(
    id: id,
    displayName: id.displayName,
    status: present ? HarnessStatus.ready : HarnessStatus.notInstalled,
    executablePath: present ? '/fake/${id.wireName}' : null,
    checkedAt: DateTime.utc(2026, 11, 24),
  );
}

final class _FakeMcpInstaller {
  final Set<HarnessId> installedFor = <HarnessId>{};
  int installCalls = 0;
}

final class _PerHarnessMcp implements HarnessMcpInstaller {
  new(this.id, this.state);

  @override
  final HarnessId id;
  final _FakeMcpInstaller state;

  @override
  Future<HarnessMcpDetectionResult> detect({
    required String executablePath,
    required HiveMcpLaunchCommand expectedCommand,
  }) async => HarnessMcpDetectionResult(
    status: state.installedFor.contains(id)
        ? HarnessMcpStatus.installed
        : HarnessMcpStatus.notInstalled,
  );

  @override
  Future<Result<void>> install({
    required String executablePath,
    required HiveMcpLaunchCommand command,
  }) async {
    state.installCalls++;
    state.installedFor.add(id);
    return const Success<void>(null);
  }
}

final class _FakeExecutableValidator implements ExecutableValidator {
  @override
  Future<bool> isExecutable(String path) async => true;
}
