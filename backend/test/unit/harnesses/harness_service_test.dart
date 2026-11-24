import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/config/platform_paths.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/harnesses/shared_agents_skill_installer.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_skill_installer.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill.dart';
import 'package:agentic_hive_backend/src/skills/bundled_skill_loader.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 20, 21);

  late _FakeDetector claude;
  late _FakeDetector codex;
  late _FakeDetector gemini;
  late _FakeDetector agy;
  late DefaultHarnessService service;

  setUp(() {
    claude = _FakeDetector(
      HarnessId.claudeCode,
      HarnessInfo(
        id: HarnessId.claudeCode,
        displayName: 'Claude Code',
        status: HarnessStatus.ready,
        version: '2.1.0',
        executablePath: '/usr/bin/claude',
        checkedAt: t0,
      ),
    );
    codex = _FakeDetector(
      HarnessId.codex,
      HarnessInfo(
        id: HarnessId.codex,
        displayName: 'Codex',
        status: HarnessStatus.ready,
        version: '0.25.0',
        executablePath: '/usr/bin/codex',
        checkedAt: t0,
      ),
    );
    gemini = _FakeDetector(
      HarnessId.geminiCli,
      HarnessInfo(
        id: HarnessId.geminiCli,
        displayName: 'Gemini CLI',
        status: HarnessStatus.notInstalled,
        checkedAt: t0,
      ),
    );
    agy = _FakeDetector(
      HarnessId.antigravity,
      HarnessInfo(
        id: HarnessId.antigravity,
        displayName: 'Antigravity',
        status: HarnessStatus.unavailable,
        executablePath: '/usr/bin/agy',
        errorMessage: 'Timed out while checking Antigravity CLI.',
        checkedAt: t0,
      ),
    );
    service = DefaultHarnessService(
      detectors: [claude, codex, gemini, agy],
      now: () => t0.add(const Duration(seconds: 5)),
    );
  });

  tearDown(() => service.dispose());

  test(
    'listHarnesses scans once and returns cached results thereafter',
    () async {
      final first = await service.listHarnesses();
      final second = await service.listHarnesses();

      expect(first.valueOrNull?.map((h) => h.id), [
        HarnessId.claudeCode,
        HarnessId.codex,
        HarnessId.geminiCli,
        HarnessId.antigravity,
      ]);
      expect(second.valueOrNull, first.valueOrNull);
      expect(claude.calls, 1);
      expect(codex.calls, 1);
      expect(gemini.calls, 1);
      expect(agy.calls, 1);
    },
  );

  test('refreshAll broadcasts only harnesses whose status or fields '
      'changed', () async {
    await service.listHarnesses();
    final updates = <HarnessInfo>[];
    final sub = service.statusUpdates.listen(updates.add);

    // Update only gemini; claude gets a newer timestamp with identical status.
    final t1 = t0.add(const Duration(minutes: 1));
    claude.next = claude.next.copyWith(checkedAt: t1);
    gemini.next = HarnessInfo(
      id: HarnessId.geminiCli,
      displayName: 'Gemini CLI',
      status: HarnessStatus.ready,
      version: '0.2.0',
      executablePath: '/usr/bin/gemini',
      checkedAt: t1,
    );

    final refreshed = await service.refreshAll();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(refreshed.valueOrNull?[2].status, HarnessStatus.ready);
    expect(updates, hasLength(1));
    expect(updates.single.id, HarnessId.geminiCli);
    expect(updates.single.status, HarnessStatus.ready);
  });

  test('reportAuthError and reportOutdated update cache and broadcast, and '
      'refreshOne clears stale errors when probe succeeds', () async {
    await service.listHarnesses();
    final updates = <HarnessInfo>[];
    final sub = service.statusUpdates.listen(updates.add);

    service
      ..reportAuthError(HarnessId.claudeCode)
      ..reportOutdated(HarnessId.codex, message: 'Update codex now.');
    await Future<void>.delayed(Duration.zero);

    final cachedAfterReports = (await service.listHarnesses()).valueOrNull!;
    expect(cachedAfterReports[0].status, HarnessStatus.authError);
    expect(cachedAfterReports[0].version, '2.1.0');
    expect(cachedAfterReports[0].executablePath, '/usr/bin/claude');
    expect(cachedAfterReports[1].status, HarnessStatus.outdated);
    expect(cachedAfterReports[1].errorMessage, 'Update codex now.');

    // Re-verifying claude succeeds and clears authError.
    final rechecked = await service.refreshOne(HarnessId.claudeCode);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(rechecked.valueOrNull?.status, HarnessStatus.ready);
    expect(rechecked.valueOrNull?.errorMessage, isNull);
    expect(updates.map((u) => (u.id, u.status)), [
      (HarnessId.claudeCode, HarnessStatus.authError),
      (HarnessId.codex, HarnessStatus.outdated),
      (HarnessId.claudeCode, HarnessStatus.ready),
    ]);
  });

  test('refreshOne before initial listHarnesses does not cause listHarnesses '
      'to return a partial cache', () async {
    final single = await service.refreshOne(HarnessId.claudeCode);
    expect(single.valueOrNull?.id, HarnessId.claudeCode);

    final all = await service.listHarnesses();
    expect(all.valueOrNull?.map((h) => h.id), [
      HarnessId.claudeCode,
      HarnessId.codex,
      HarnessId.geminiCli,
      HarnessId.antigravity,
    ]);
    expect(claude.calls, 2);
    expect(codex.calls, 1);
    expect(gemini.calls, 1);
    expect(agy.calls, 1);
  });

  group('skill management', () {
    final checkedAt = t0;
    HarnessInfo readyInfo(HarnessId id, {required String executablePath}) =>
        HarnessInfo(
          id: id,
          displayName: id.displayName,
          status: HarnessStatus.ready,
          executablePath: executablePath,
          checkedAt: checkedAt,
        );
    late String home;
    late PlatformPaths paths;
    late _FakeBundledSkillLoader loader;
    late HarnessSkillInstallerRegistry registry;

    setUp(() {
      final dir = Directory.systemTemp.createTempSync('hive_svc_skill_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      home = dir.path;
      paths = platformPathsFor(
        Platform.operatingSystem,
        environment: {'HOME': home, 'USERPROFILE': home, 'LOCALAPPDATA': home},
      );
      final files = <String, List<int>>{'SKILL.md': utf8.encode('# Skill\n')};
      loader = _FakeBundledSkillLoader(
        Success(
          BundledSkill(
            name: agenticHiveSkillName,
            files: files,
            contentHash: computeSkillContentHash(files),
          ),
        ),
      );
      registry = HarnessSkillInstallerRegistry([
        SharedAgentsSkillInstaller(
          platformPaths: paths,
          bundledSkillLoader: loader,
          appVersion: '1.0.0',
        ),
      ]);
    });

    test(
      'enriches installed CLI, clears notInstalled, and skips unsupported',
      () async {
        final codex = _FakeDetector(
          HarnessId.codex,
          readyInfo(HarnessId.codex, executablePath: '/usr/bin/codex'),
        );
        final gemini = _FakeDetector(
          HarnessId.geminiCli,
          HarnessInfo(
            id: HarnessId.geminiCli,
            displayName: 'Gemini CLI',
            status: HarnessStatus.notInstalled,
            checkedAt: checkedAt,
          ),
        );
        final claude = _FakeDetector(
          HarnessId.claudeCode,
          readyInfo(HarnessId.claudeCode, executablePath: '/usr/bin/claude'),
        );
        final service = DefaultHarnessService(
          detectors: [codex, gemini, claude],
          skillInstallers: registry,
        );
        addTearDown(service.dispose);

        final list = (await service.listHarnesses()).valueOrNull!;
        expect(list[0].skillStatus, HarnessSkillStatus.notInstalled);
        expect(list[1].skillStatus, isNull);
        expect(list[1].skillMessage, isNull);
        expect(list[2].skillStatus, isNull);
      },
    );

    test(
      'installSkill and removeSkill update shared harnesses without spawning '
      'detectors',
      () async {
        final codex = _FakeDetector(
          HarnessId.codex,
          readyInfo(HarnessId.codex, executablePath: '/usr/bin/codex'),
        );
        final gemini = _FakeDetector(
          HarnessId.geminiCli,
          readyInfo(HarnessId.geminiCli, executablePath: '/usr/bin/gemini'),
        );
        final service = DefaultHarnessService(
          detectors: [codex, gemini],
          skillInstallers: registry,
        );
        addTearDown(service.dispose);

        await service.listHarnesses();
        final callsBefore = codex.calls + gemini.calls;

        final updates = <HarnessInfo>[];
        final sub = service.statusUpdates.listen(updates.add);
        addTearDown(sub.cancel);

        final installed = await service.installSkill(HarnessId.codex);
        expect(
          installed.valueOrNull?.skillStatus,
          HarnessSkillStatus.installed,
        );
        expect(codex.calls + gemini.calls, callsBefore);

        await Future<void>.delayed(Duration.zero);
        expect(
          updates.map((u) => (u.id, u.skillStatus)),
          containsAll([
            (HarnessId.codex, HarnessSkillStatus.installed),
            (HarnessId.geminiCli, HarnessSkillStatus.installed),
          ]),
        );

        final removed = await service.removeSkill(HarnessId.codex);
        expect(
          removed.valueOrNull?.skillStatus,
          HarnessSkillStatus.notInstalled,
        );
        expect(codex.calls + gemini.calls, callsBefore);
      },
    );

    test('installSkill returns ConflictFailure when CLI is not installed or '
        'registry missing', () async {
      final gemini = _FakeDetector(
        HarnessId.geminiCli,
        HarnessInfo(
          id: HarnessId.geminiCli,
          displayName: 'Gemini CLI',
          status: HarnessStatus.notInstalled,
          checkedAt: checkedAt,
        ),
      );
      final service = DefaultHarnessService(
        detectors: [gemini],
        skillInstallers: registry,
      );
      addTearDown(service.dispose);

      final notInstalled = await service.installSkill(HarnessId.geminiCli);
      expect(notInstalled.failureOrNull, isA<ConflictFailure>());

      final noRegistry = DefaultHarnessService(detectors: [gemini]);
      addTearDown(noRegistry.dispose);
      expect(
        (await noRegistry.installSkill(HarnessId.geminiCli)).failureOrNull,
        isA<ConflictFailure>(),
      );
      expect(
        (await noRegistry.installSkill(HarnessId.claudeCode)).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

    test('installSkill requires overwriteModified when modified', () async {
      final codex = _FakeDetector(
        HarnessId.codex,
        readyInfo(HarnessId.codex, executablePath: '/usr/bin/codex'),
      );
      final service = DefaultHarnessService(
        detectors: [codex],
        skillInstallers: registry,
      );
      addTearDown(service.dispose);

      await service.installSkill(HarnessId.codex);
      File(p.join(home, '.agents', 'skills', agenticHiveSkillName, 'SKILL.md'))
          .writeAsStringSync('edited\n');

      final blocked = await service.installSkill(HarnessId.codex);
      expect(blocked.failureOrNull, isA<ConflictFailure>());

      final forced = await service.installSkill(
        HarnessId.codex,
        overwriteModified: true,
      );
      expect(forced.valueOrNull?.skillStatus, HarnessSkillStatus.installed);
    });
  });

  group('detections and cachedInfo', () {
    test(
      'emits on initial scan, refreshAll, refreshOne, and closes on dispose',
      () async {
        final d1 = _FakeDetector(
          HarnessId.claudeCode,
          HarnessInfo(
            id: HarnessId.claudeCode,
            displayName: 'Claude Code',
            status: HarnessStatus.ready,
            executablePath: '/usr/bin/claude',
            checkedAt: DateTime.utc(2026, 11, 24),
          ),
        );
        final d2 = _FakeDetector(
          HarnessId.codex,
          HarnessInfo(
            id: HarnessId.codex,
            displayName: 'Codex',
            status: HarnessStatus.ready,
            executablePath: '/usr/bin/codex',
            checkedAt: DateTime.utc(2026, 11, 24),
          ),
        );
        final service = DefaultHarnessService(detectors: [d1, d2]);

        expect(service.cachedInfo(HarnessId.claudeCode), isNull);

        final detections = <HarnessInfo>[];
        final cachedAtDelivery = <HarnessInfo?>[];
        final statusUpdates = <HarnessInfo>[];
        final subDet = service.detections.listen((info) {
          detections.add(info);
          cachedAtDelivery.add(service.cachedInfo(info.id));
        });
        final subStatus = service.statusUpdates.listen(statusUpdates.add);
        addTearDown(() async {
          await subDet.cancel();
          await subStatus.cancel();
        });

        await service.listHarnesses();
        await Future<void>.delayed(Duration.zero);
        expect(detections.map((i) => i.id), [
          HarnessId.claudeCode,
          HarnessId.codex,
        ]);
        expect(cachedAtDelivery, detections);
        expect(statusUpdates, isEmpty);

        detections.clear();
        await service.listHarnesses();
        await Future<void>.delayed(Duration.zero);
        expect(detections, isEmpty);

        await service.refreshAll();
        await Future<void>.delayed(Duration.zero);
        expect(detections.map((i) => i.id), [
          HarnessId.claudeCode,
          HarnessId.codex,
        ]);
        expect(statusUpdates, isEmpty);

        detections.clear();
        await service.refreshOne(HarnessId.codex);
        await Future<void>.delayed(Duration.zero);
        expect(detections.map((i) => i.id), [HarnessId.codex]);

        detections.clear();
        service.reportAuthError(HarnessId.claudeCode);
        await Future<void>.delayed(Duration.zero);
        expect(detections, isEmpty);

        final done = expectLater(service.detections, emitsDone);
        await service.dispose();
        await done;
      },
    );
  });
}

final class _FakeBundledSkillLoader implements BundledSkillLoader {
  new(this.result);
  final Result<BundledSkill> result;

  @override
  Result<BundledSkill> load(String name) => result;
}

final class _FakeDetector implements HarnessDetector {
  new(this.id, this.next);

  @override
  final HarnessId id;

  HarnessInfo next;
  int calls = 0;

  @override
  void setExecutableOverride(String? path) {}

  @override
  Future<HarnessInfo> detect() async {
    calls++;
    return next;
  }
}
