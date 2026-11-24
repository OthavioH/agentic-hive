import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_skill_installer.dart';
import 'package:agentic_hive_backend/src/domain/settings/settings_service.dart';
import 'package:agentic_hive_backend/src/domain/skills/skill_auto_install_mark_store.dart';
import 'package:agentic_hive_backend/src/domain/skills/skill_auto_install_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  late _FakeHarnessService harnessService;
  late _FakeSettingsService settingsService;
  late _MemoryMarkStore markStore;
  late HarnessSkillInstallerRegistry skillInstallers;
  late List<String> log;
  var nextId = 0;

  SkillAutoInstallService buildService() => DefaultSkillAutoInstallService(
    harnessService: harnessService,
    settingsService: settingsService,
    markStore: markStore,
    skillInstallers: skillInstallers,
    now: () => DateTime.utc(2026, 11, 24, 12),
    generateId: () => 'notice-${++nextId}',
  );

  setUp(() {
    log = <String>[];
    nextId = 0;
    harnessService = _FakeHarnessService(log);
    settingsService = _FakeSettingsService();
    markStore = _MemoryMarkStore(log);
    skillInstallers = HarnessSkillInstallerRegistry(<HarnessSkillInstaller>[
      _FakeSkillInstaller({
        HarnessId.claudeCode,
      }, '/home/u/.claude/skills/agentic-hive'),
      _FakeSkillInstaller({
        HarnessId.codex,
        HarnessId.geminiCli,
      }, '/home/u/.agents/skills/agentic-hive'),
      _FakeSkillInstaller({
        HarnessId.antigravity,
      }, '/home/u/.gemini/config/skills/agentic-hive'),
    ]);
  });

  tearDown(() async {
    await harnessService.dispose();
    await settingsService.dispose();
  });

  group('AC1: fresh state + detected harness', () {
    test(
      'installs skill and MCP once in order after mark, reports notice',
      () async {
        final service = buildService();
        addTearDown(service.dispose);

        harnessService.setInfo(
          _info(
            HarnessId.claudeCode,
            skillStatus: HarnessSkillStatus.notInstalled,
            mcpStatus: HarnessMcpStatus.notInstalled,
          ),
        );

        final notices = <SkillAutoInstallNotice>[];
        final sub = service.notices.listen(notices.add);
        addTearDown(sub.cancel);

        service.start();
        await service.idle();

        expect(log, [
          'mark:claude_code',
          'installSkill:claude_code',
          'installMcp:claude_code',
        ]);
        expect(notices, hasLength(1));
        expect(service.pendingNotice, notices.single);
        final result = notices.single.results.single;
        expect(result.harnessId, HarnessId.claudeCode);
        expect(result.skill.outcome, SkillAutoInstallOutcome.installed);
        expect(result.skill.paths, ['/home/u/.claude/skills/agentic-hive']);
        expect(result.mcp.outcome, SkillAutoInstallOutcome.installed);
        expect(result.mcp.paths, isEmpty);

        // start() twice is idempotent.
        service.start();
        await service.idle();
        expect(log, hasLength(3));
      },
    );

    test('does nothing before start() is called (R13)', () async {
      final service = buildService();
      addTearDown(service.dispose);
      expect(service.isStarted, isFalse);

      harnessService.emitDetection(
        _info(
          HarnessId.claudeCode,
          skillStatus: HarnessSkillStatus.notInstalled,
          mcpStatus: HarnessMcpStatus.notInstalled,
        ),
      );
      await service.idle();
      expect(log, isEmpty);
      expect(service.pendingNotice, isNull);
    });
  });

  group('AC2: second app start and dismiss', () {
    test(
      'does not reinstall after restart or after user removes skill',
      () async {
        final service1 = buildService();
        harnessService.setInfo(
          _info(
            HarnessId.claudeCode,
            skillStatus: HarnessSkillStatus.notInstalled,
            mcpStatus: HarnessMcpStatus.notInstalled,
          ),
        );
        service1.start();
        await service1.idle();
        await service1.dispose();

        log.clear();
        harnessService.setInfo(
          _info(
            HarnessId.claudeCode,
            skillStatus: HarnessSkillStatus.notInstalled,
            mcpStatus: HarnessMcpStatus.installed,
          ),
        );
        final service2 = buildService();
        addTearDown(service2.dispose);
        service2.start();
        await service2.idle();

        expect(log, isEmpty);
        expect(service2.pendingNotice, isNull);
      },
    );

    test(
      'dismissNotice clears pendingNotice and does not reinstall on detection',
      () async {
        final service = buildService();
        addTearDown(service.dispose);
        harnessService.setInfo(
          _info(
            HarnessId.claudeCode,
            skillStatus: HarnessSkillStatus.notInstalled,
            mcpStatus: HarnessMcpStatus.notInstalled,
          ),
        );
        service.start();
        await service.idle();
        expect(service.pendingNotice, isNotNull);

        service.dismissNotice();
        expect(service.pendingNotice, isNull);

        log.clear();
        harnessService.emitDetection(
          _info(
            HarnessId.claudeCode,
            skillStatus: HarnessSkillStatus.notInstalled,
            mcpStatus: HarnessMcpStatus.notInstalled,
          ),
        );
        await service.idle();
        expect(log, isEmpty);
        expect(service.pendingNotice, isNull);
      },
    );
  });

  group('AC3: later harness and failures', () {
    test(
      'installs newly detected unmarked harness, ignores marked ones',
      () async {
        await markStore.mark(HarnessId.claudeCode);
        log.clear();

        final service = buildService();
        addTearDown(service.dispose);
        harnessService
          ..setInfo(
            _info(
              HarnessId.claudeCode,
              skillStatus: HarnessSkillStatus.notInstalled,
              mcpStatus: HarnessMcpStatus.notInstalled,
            ),
          )
          ..setInfo(
            _info(
              HarnessId.codex,
              status: HarnessStatus.notInstalled,
              executablePath: null,
            ),
          );

        service.start();
        await service.idle();
        expect(log, isEmpty);

        harnessService.emitDetection(
          _info(
            HarnessId.codex,
            skillStatus: HarnessSkillStatus.notInstalled,
            mcpStatus: HarnessMcpStatus.notInstalled,
          ),
        );
        await service.idle();
        expect(log, ['mark:codex', 'installSkill:codex', 'installMcp:codex']);
      },
    );

    test('skill failure still runs MCP, marks, and never retries', () async {
      harnessService.skillFailure = const PersistenceFailure('disk full');
      final service = buildService();
      addTearDown(service.dispose);
      harnessService.setInfo(
        _info(
          HarnessId.claudeCode,
          skillStatus: HarnessSkillStatus.notInstalled,
          mcpStatus: HarnessMcpStatus.notInstalled,
        ),
      );
      service.start();
      await service.idle();

      final result = service.pendingNotice!.results.single;
      expect(result.skill.outcome, SkillAutoInstallOutcome.failed);
      expect(result.skill.message, 'disk full');
      expect(result.mcp.outcome, SkillAutoInstallOutcome.installed);
      expect(await markStore.isMarked(HarnessId.claudeCode), isTrue);

      log.clear();
      harnessService.emitDetection(
        harnessService.cachedInfo(HarnessId.claudeCode)!,
      );
      await service.idle();
      expect(log, isEmpty);
    });

    test('MCP failure reports failed while skill succeeds', () async {
      harnessService.mcpFailure = const ConflictFailure('exit 1');
      final service = buildService();
      addTearDown(service.dispose);
      harnessService.setInfo(
        _info(
          HarnessId.claudeCode,
          skillStatus: HarnessSkillStatus.notInstalled,
          mcpStatus: HarnessMcpStatus.notInstalled,
        ),
      );
      service.start();
      await service.idle();

      final result = service.pendingNotice!.results.single;
      expect(result.skill.outcome, SkillAutoInstallOutcome.installed);
      expect(result.mcp.outcome, SkillAutoInstallOutcome.failed);
      expect(result.mcp.message, 'exit 1');
    });

    test(
      'thrown exception in installSkill is caught and queue continues',
      () async {
        harnessService.throwOnSkill = true;
        final service = buildService();
        addTearDown(service.dispose);
        harnessService.setInfo(
          _info(
            HarnessId.claudeCode,
            skillStatus: HarnessSkillStatus.notInstalled,
            mcpStatus: HarnessMcpStatus.notInstalled,
          ),
        );
        service.start();
        await service.idle();

        final result = service.pendingNotice!.results.single;
        expect(result.skill.outcome, SkillAutoInstallOutcome.failed);
        expect(result.skill.message, 'Unexpected error while installing.');
        expect(result.mcp.outcome, SkillAutoInstallOutcome.installed);
      },
    );
  });

  group('AC4: autoInstallSkills setting', () {
    test(
      'off skips install and mark; turning on evaluates cached harnesses',
      () async {
        settingsService.autoInstallSkills = false;
        final service = buildService();
        addTearDown(service.dispose);
        harnessService.setInfo(
          _info(
            HarnessId.claudeCode,
            skillStatus: HarnessSkillStatus.notInstalled,
            mcpStatus: HarnessMcpStatus.notInstalled,
          ),
        );
        service.start();
        await service.idle();
        expect(log, isEmpty);
        expect(await markStore.isMarked(HarnessId.claudeCode), isFalse);

        // Off -> off does nothing.
        settingsService.emitUpdate(false);
        await service.idle();
        expect(log, isEmpty);

        // Off -> on evaluates cached harnesses.
        settingsService.emitUpdate(true);
        await service.idle();
        expect(log, [
          'mark:claude_code',
          'installSkill:claude_code',
          'installMcp:claude_code',
        ]);
        expect(service.pendingNotice, isNotNull);

        // On -> on does not re-evaluate.
        log.clear();
        settingsService.emitUpdate(true);
        await service.idle();
        expect(log, isEmpty);
      },
    );

    test('getSettings failure does nothing and writes no mark', () async {
      settingsService.failGet = true;
      final service = buildService();
      addTearDown(service.dispose);
      harnessService.setInfo(
        _info(
          HarnessId.claudeCode,
          skillStatus: HarnessSkillStatus.notInstalled,
          mcpStatus: HarnessMcpStatus.notInstalled,
        ),
      );
      service.start();
      await service.idle();
      expect(log, isEmpty);
      expect(await markStore.isMarked(HarnessId.claudeCode), isFalse);
    });
  });

  group('AC5: never updates outdated/modified/conflict/unknown', () {
    test(
      'outdated skill and mcp are skipped with exact messages and no notice',
      () async {
        final service = buildService();
        addTearDown(service.dispose);
        harnessService.setInfo(
          _info(
            HarnessId.claudeCode,
            skillStatus: HarnessSkillStatus.outdated,
            mcpStatus: HarnessMcpStatus.outdated,
          ),
        );
        service.start();
        await service.idle();

        expect(log, ['mark:claude_code']);
        expect(service.pendingNotice, isNull);
      },
    );

    test('alreadyInstalled both writes mark and emits no notice', () async {
      final service = buildService();
      addTearDown(service.dispose);
      harnessService.setInfo(
        _info(
          HarnessId.claudeCode,
          skillStatus: HarnessSkillStatus.installed,
          mcpStatus: HarnessMcpStatus.installed,
        ),
      );
      service.start();
      await service.idle();

      expect(log, ['mark:claude_code']);
      expect(service.pendingNotice, isNull);
    });

    test(
      'skill installed + mcp notInstalled installs mcp and creates notice',
      () async {
        final service = buildService();
        addTearDown(service.dispose);
        harnessService.setInfo(
          _info(
            HarnessId.claudeCode,
            skillStatus: HarnessSkillStatus.installed,
            mcpStatus: HarnessMcpStatus.notInstalled,
          ),
        );
        service.start();
        await service.idle();

        expect(log, ['mark:claude_code', 'installMcp:claude_code']);
        final result = service.pendingNotice!.results.single;
        expect(result.skill.outcome, SkillAutoInstallOutcome.alreadyInstalled);
        expect(result.mcp.outcome, SkillAutoInstallOutcome.installed);
      },
    );
  });

  group('Edge and robustness', () {
    test(
      'mark write throws -> no install, retries on next detection',
      () async {
        markStore.throwOnMark = true;
        final service = buildService();
        addTearDown(service.dispose);
        harnessService.setInfo(
          _info(
            HarnessId.claudeCode,
            skillStatus: HarnessSkillStatus.notInstalled,
            mcpStatus: HarnessMcpStatus.notInstalled,
          ),
        );
        service.start();
        await service.idle();
        expect(log, isEmpty);
        expect(service.pendingNotice, isNull);

        markStore.throwOnMark = false;
        harnessService.emitDetection(
          harnessService.cachedInfo(HarnessId.claudeCode)!,
        );
        await service.idle();
        expect(log, [
          'mark:claude_code',
          'installSkill:claude_code',
          'installMcp:claude_code',
        ]);
      },
    );

    test(
      'shared copy: codex installs, gemini reports alreadyInstalled',
      () async {
        final service = buildService();
        addTearDown(service.dispose);
        harnessService
          ..shareCodexGemini = true
          ..setInfo(
            _info(
              HarnessId.codex,
              skillStatus: HarnessSkillStatus.notInstalled,
              mcpStatus: HarnessMcpStatus.notInstalled,
            ),
          )
          ..setInfo(
            _info(
              HarnessId.geminiCli,
              skillStatus: HarnessSkillStatus.notInstalled,
              mcpStatus: HarnessMcpStatus.notInstalled,
            ),
          );

        service.start();
        await service.idle();

        final results = service.pendingNotice!.results;
        expect(results, hasLength(2));
        expect(results[0].harnessId, HarnessId.codex);
        expect(results[0].skill.outcome, SkillAutoInstallOutcome.installed);
        expect(results[1].harnessId, HarnessId.geminiCli);
        expect(
          results[1].skill.outcome,
          SkillAutoInstallOutcome.alreadyInstalled,
        );
        expect(log.where((e) => e.startsWith('installSkill:')).toList(), [
          'installSkill:codex',
        ]);
      },
    );

    test('merges two runs into one notice with new id', () async {
      final service = buildService();
      addTearDown(service.dispose);
      harnessService.setInfo(
        _info(
          HarnessId.claudeCode,
          skillStatus: HarnessSkillStatus.notInstalled,
          mcpStatus: HarnessMcpStatus.notInstalled,
        ),
      );
      service.start();
      await service.idle();
      final id1 = service.pendingNotice!.id;

      harnessService.emitDetection(
        _info(
          HarnessId.codex,
          skillStatus: HarnessSkillStatus.notInstalled,
          mcpStatus: HarnessMcpStatus.notInstalled,
        ),
      );
      await service.idle();
      final id2 = service.pendingNotice!.id;
      expect(id2, isNot(id1));
      expect(service.pendingNotice!.results.map((r) => r.harnessId), [
        HarnessId.claudeCode,
        HarnessId.codex,
      ]);
    });
  });
}

HarnessInfo _info(
  HarnessId id, {
  HarnessStatus status = HarnessStatus.ready,
  String? executablePath = '/usr/bin/cli',
  HarnessSkillStatus? skillStatus,
  String? skillMessage,
  HarnessMcpStatus mcpStatus = HarnessMcpStatus.unknown,
  String? mcpMessage,
}) => HarnessInfo(
  id: id,
  displayName: id.displayName,
  status: status,
  executablePath: executablePath,
  skillStatus: skillStatus,
  skillMessage: skillMessage,
  mcpStatus: mcpStatus,
  mcpMessage: mcpMessage,
  checkedAt: DateTime.utc(2026, 11, 24),
);

final class _FakeSkillInstaller implements HarnessSkillInstaller {
  new(this.harnessIds, this.skillDirectory);

  @override
  final Set<HarnessId> harnessIds;

  @override
  final String? skillDirectory;

  @override
  HarnessSkillDetection detect() =>
      const HarnessSkillDetection(status: HarnessSkillStatus.notInstalled);

  @override
  Result<void> install({bool overwriteModified = false}) =>
      const Success<void>(null);

  @override
  Result<void> remove() => const Success<void>(null);
}

final class _MemoryMarkStore implements SkillAutoInstallMarkStore {
  new(this._log);

  final List<String> _log;
  final Set<HarnessId> _marked = <HarnessId>{};
  bool throwOnMark = false;

  @override
  Future<bool> isMarked(HarnessId id) async => _marked.contains(id);

  @override
  Future<void> mark(HarnessId id) async {
    if (throwOnMark) {
      throw StateError('db locked');
    }
    _log.add('mark:${id.wireName}');
    _marked.add(id);
  }
}

final class _FakeSettingsService implements SettingsService {
  bool autoInstallSkills = true;
  bool failGet = false;
  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  @override
  Stream<AppSettings> get settingsUpdates => _controller.stream;

  void emitUpdate(bool enabled) {
    autoInstallSkills = enabled;
    _controller.add(
      AppSettings(
        effectiveAgentsDir: '/agents',
        defaultAgentsDir: '/agents',
        autoInstallSkills: enabled,
      ),
    );
  }

  @override
  Future<Result<AppSettings>> getSettings() async {
    if (failGet) {
      return const FailureResult(PersistenceFailure('read failed'));
    }
    return Success(
      AppSettings(
        effectiveAgentsDir: '/agents',
        defaultAgentsDir: '/agents',
        autoInstallSkills: autoInstallSkills,
      ),
    );
  }

  @override
  Future<Result<AppSettings>> applyPersistedSettings() => getSettings();

  @override
  Future<Result<AppSettings>> updateSettings(UpdateSettingsRequest request) =>
      getSettings();

  @override
  Future<void> dispose() => _controller.close();
}

final class _FakeHarnessService implements HarnessService {
  new(this._log);

  final List<String> _log;
  final Map<HarnessId, HarnessInfo> _cache = <HarnessId, HarnessInfo>{};
  final StreamController<HarnessInfo> _detections =
      StreamController<HarnessInfo>.broadcast();
  final StreamController<HarnessInfo> _statusUpdates =
      StreamController<HarnessInfo>.broadcast();

  Failure? skillFailure;
  Failure? mcpFailure;
  bool throwOnSkill = false;
  bool shareCodexGemini = false;

  void setInfo(HarnessInfo info) {
    _cache[info.id] = info;
  }

  void emitDetection(HarnessInfo info) {
    _cache[info.id] = info;
    _detections.add(info);
  }

  @override
  Stream<HarnessInfo> get detections => _detections.stream;

  @override
  Stream<HarnessInfo> get statusUpdates => _statusUpdates.stream;

  @override
  HarnessInfo? cachedInfo(HarnessId id) => _cache[id];

  @override
  Future<Result<List<HarnessInfo>>> listHarnesses() async =>
      Success(_cache.values.toList());

  @override
  Future<Result<List<HarnessInfo>>> refreshAll() => listHarnesses();

  @override
  Future<Result<HarnessInfo>> refreshOne(HarnessId id) async =>
      Success(_cache[id]!);

  @override
  Future<Result<HarnessInfo>> installSkill(
    HarnessId id, {
    bool overwriteModified = false,
  }) async {
    _log.add('installSkill:${id.wireName}');
    if (throwOnSkill) {
      throw StateError('boom');
    }
    if (skillFailure != null) {
      return FailureResult(skillFailure!);
    }
    final updated = _cache[id]!.copyWith(
      skillStatus: HarnessSkillStatus.installed,
    );
    _cache[id] = updated;
    if (shareCodexGemini &&
        (id == HarnessId.codex || id == HarnessId.geminiCli)) {
      final other = id == HarnessId.codex
          ? HarnessId.geminiCli
          : HarnessId.codex;
      final otherInfo = _cache[other];
      if (otherInfo != null) {
        _cache[other] = otherInfo.copyWith(
          skillStatus: HarnessSkillStatus.installed,
        );
      }
    }
    return Success(updated);
  }

  @override
  Future<Result<HarnessInfo>> removeSkill(HarnessId id) async =>
      Success(_cache[id]!);

  @override
  Future<Result<HarnessInfo>> installMcp(HarnessId id) async {
    _log.add('installMcp:${id.wireName}');
    if (mcpFailure != null) {
      return FailureResult(mcpFailure!);
    }
    final updated = _cache[id]!.copyWith(mcpStatus: HarnessMcpStatus.installed);
    _cache[id] = updated;
    return Success(updated);
  }

  @override
  Future<void> applyExecutableOverrides(
    Map<HarnessId, String> overrides, {
    bool triggerRefresh = true,
  }) async {}

  @override
  void reportAuthError(HarnessId id, {String? message}) {}

  @override
  void reportOutdated(HarnessId id, {String? message}) {}

  @override
  Future<void> dispose() async {
    await _detections.close();
    await _statusUpdates.close();
  }
}
