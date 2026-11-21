import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
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
}

final class _FakeDetector implements HarnessDetector {
  new(this.id, this.next);

  @override
  final HarnessId id;

  HarnessInfo next;
  int calls = 0;

  @override
  Future<HarnessInfo> detect() async {
    calls++;
    return next;
  }
}
