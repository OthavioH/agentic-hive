import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/harnesses/get_harnesses_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_frontend/domain/harnesses/refresh_harness_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/refresh_harnesses_use_case.dart';
import 'package:agentic_hive_frontend/domain/harnesses/watch_harness_updates_use_case.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeHarnessRepository implements HarnessRepository {
  Result<List<HarnessInfo>> getResult = const Success(<HarnessInfo>[]);
  Result<List<HarnessInfo>> refreshAllResult = const Success(<HarnessInfo>[]);
  Result<HarnessInfo> refreshOneResult = const FailureResult<HarnessInfo>(
    NotFoundFailure('missing'),
  );
  final StreamController<HarnessInfo> updates =
      StreamController<HarnessInfo>.broadcast();

  int getCalls = 0;
  int refreshAllCalls = 0;
  final List<HarnessId> refreshedIds = <HarnessId>[];

  @override
  Future<Result<List<HarnessInfo>>> getHarnesses() async {
    getCalls++;
    return getResult;
  }

  @override
  Future<Result<List<HarnessInfo>>> refreshAll() async {
    refreshAllCalls++;
    return refreshAllResult;
  }

  @override
  Future<Result<HarnessInfo>> refreshHarness(HarnessId id) async {
    refreshedIds.add(id);
    return refreshOneResult;
  }

  @override
  Stream<HarnessInfo> watchHarnessUpdates() => updates.stream;

  Future<void> dispose() => updates.close();
}

void main() {
  final sample = HarnessInfo(
    id: HarnessId.claudeCode,
    displayName: 'Claude Code',
    status: HarnessStatus.ready,
    version: '1.0.0',
    executablePath: '/usr/local/bin/claude',
    checkedAt: DateTime.utc(2026, 11, 20),
  );

  group('Harness use cases', () {
    test('GetHarnessesUseCase delegates to repository', () async {
      final repo = _FakeHarnessRepository()
        ..getResult = Success(<HarnessInfo>[sample]);
      addTearDown(repo.dispose);

      final result = await GetHarnessesUseCase(repo)();
      expect(repo.getCalls, 1);
      expect(result.valueOrNull, <HarnessInfo>[sample]);
    });

    test('RefreshHarnessesUseCase delegates to repository', () async {
      final repo = _FakeHarnessRepository()
        ..refreshAllResult = const FailureResult(NetworkFailure('offline'));
      addTearDown(repo.dispose);

      final result = await RefreshHarnessesUseCase(repo)();
      expect(repo.refreshAllCalls, 1);
      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test('RefreshHarnessUseCase passes HarnessId to repository', () async {
      final repo = _FakeHarnessRepository()..refreshOneResult = Success(sample);
      addTearDown(repo.dispose);

      final result = await RefreshHarnessUseCase(repo)(HarnessId.claudeCode);
      expect(repo.refreshedIds, <HarnessId>[HarnessId.claudeCode]);
      expect(result.valueOrNull, sample);
    });

    test(
      'WatchHarnessUpdatesUseCase exposes repository update stream',
      () async {
        final repo = _FakeHarnessRepository();
        addTearDown(repo.dispose);

        final received = <HarnessInfo>[];
        final sub = WatchHarnessUpdatesUseCase(repo)().listen(received.add);
        addTearDown(sub.cancel);

        repo.updates.add(sample);
        await pumpEventQueue();
        expect(received, <HarnessInfo>[sample]);
      },
    );
  });
}
