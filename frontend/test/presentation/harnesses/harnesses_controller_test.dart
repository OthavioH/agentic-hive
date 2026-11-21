import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeHarnessRepository implements HarnessRepository {
  Completer<Result<List<HarnessInfo>>>? pendingGet;
  Completer<Result<List<HarnessInfo>>>? pendingRefreshAll;
  Completer<Result<HarnessInfo>>? pendingRefreshOne;

  Result<List<HarnessInfo>> getResult = const Success(<HarnessInfo>[]);
  Result<List<HarnessInfo>> refreshAllResult = const Success(<HarnessInfo>[]);
  Result<HarnessInfo> refreshOneResult = const FailureResult<HarnessInfo>(
    NotFoundFailure('missing'),
  );
  final StreamController<HarnessInfo> updates =
      StreamController<HarnessInfo>.broadcast();

  @override
  Future<Result<List<HarnessInfo>>> getHarnesses() =>
      pendingGet?.future ?? Future<Result<List<HarnessInfo>>>.value(getResult);

  @override
  Future<Result<List<HarnessInfo>>> refreshAll() =>
      pendingRefreshAll?.future ??
      Future<Result<List<HarnessInfo>>>.value(refreshAllResult);

  @override
  Future<Result<HarnessInfo>> refreshHarness(HarnessId id) =>
      pendingRefreshOne?.future ??
      Future<Result<HarnessInfo>>.value(refreshOneResult);

  @override
  Stream<HarnessInfo> watchHarnessUpdates() => updates.stream;

  Future<void> dispose() => updates.close();
}

void main() {
  final claudeReady = HarnessInfo(
    id: HarnessId.claudeCode,
    displayName: 'Claude Code',
    status: HarnessStatus.ready,
    version: '1.0.0',
    executablePath: '/usr/local/bin/claude',
    checkedAt: DateTime.utc(2026, 11, 20),
  );
  final codexAuthError = HarnessInfo(
    id: HarnessId.codex,
    displayName: 'Codex',
    status: HarnessStatus.authError,
    version: '0.9.0',
    executablePath: '/usr/local/bin/codex',
    errorMessage: 'Not logged in',
    checkedAt: DateTime.utc(2026, 11, 20),
  );

  group('HarnessesController', () {
    test('loads initial harnesses into AsyncData', () async {
      final repo = _FakeHarnessRepository()
        ..getResult = Success(<HarnessInfo>[claudeReady, codexAuthError]);
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
      );

      final state = await container.read(harnessesControllerProvider.future);
      expect(state.harnesses, <HarnessInfo>[claudeReady, codexAuthError]);
      expect(state.isRefreshingAll, isFalse);
      expect(state.refreshingIds, isEmpty);
    });

    test('surfaces initial load Failure as AsyncError', () async {
      final repo = _FakeHarnessRepository()
        ..getResult = const FailureResult(NetworkFailure('unreachable'));
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
      );

      final sub = container.listen(harnessesControllerProvider, (_, _) {});
      addTearDown(sub.close);

      await expectLater(
        container.read(harnessesControllerProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('refreshAll tracks loading state, updates list, and preserves data on '
        'error', () async {
      final pending = Completer<Result<List<HarnessInfo>>>();
      final repo = _FakeHarnessRepository()
        ..getResult = Success(<HarnessInfo>[claudeReady])
        ..pendingRefreshAll = pending;
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
      );
      final sub = container.listen(harnessesControllerProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(harnessesControllerProvider.future);

      final refreshFuture = container
          .read(harnessesControllerProvider.notifier)
          .refreshAll();

      expect(
        container.read(harnessesControllerProvider).value?.isRefreshingAll,
        isTrue,
      );

      pending.complete(const FailureResult(NetworkFailure('timeout')));
      final failureResult = await refreshFuture;

      expect(failureResult.failureOrNull, isA<NetworkFailure>());
      final afterError = container.read(harnessesControllerProvider).value!;
      expect(afterError.isRefreshingAll, isFalse);
      expect(afterError.harnesses, <HarnessInfo>[claudeReady]);

      repo
        ..pendingRefreshAll = null
        ..refreshAllResult = Success(<HarnessInfo>[
          claudeReady,
          codexAuthError,
        ]);
      final okResult = await container
          .read(harnessesControllerProvider.notifier)
          .refreshAll();
      expect(okResult.isSuccess, isTrue);
      expect(
        container.read(harnessesControllerProvider).value?.harnesses,
        <HarnessInfo>[claudeReady, codexAuthError],
      );
    });

    test(
      'refreshHarness isolates per-card loading and updates only target card',
      () async {
        final pending = Completer<Result<HarnessInfo>>();
        final repo = _FakeHarnessRepository()
          ..getResult = Success(<HarnessInfo>[claudeReady, codexAuthError])
          ..pendingRefreshOne = pending;
        addTearDown(repo.dispose);

        final container = ProviderContainer.test(
          overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
        );
        final sub = container.listen(harnessesControllerProvider, (_, _) {});
        addTearDown(sub.close);

        await container.read(harnessesControllerProvider.future);

        final future = container
            .read(harnessesControllerProvider.notifier)
            .refreshHarness(HarnessId.codex);

        expect(
          container.read(harnessesControllerProvider).value?.refreshingIds,
          <HarnessId>{HarnessId.codex},
        );

        final codexReady = codexAuthError.copyWith(
          status: HarnessStatus.ready,
          errorMessage: null,
        );
        pending.complete(Success(codexReady));

        final result = await future;
        expect(result.isSuccess, isTrue);
        final after = container.read(harnessesControllerProvider).value!;
        expect(after.refreshingIds, isEmpty);
        expect(after.harnesses, <HarnessInfo>[claudeReady, codexReady]);
      },
    );

    test('updates matching harness when WS update arrives', () async {
      final repo = _FakeHarnessRepository()
        ..getResult = Success(<HarnessInfo>[claudeReady, codexAuthError]);
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
      );
      final sub = container.listen(harnessesControllerProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(harnessesControllerProvider.future);

      final updatedCodex = codexAuthError.copyWith(
        status: HarnessStatus.ready,
        errorMessage: null,
      );
      repo.updates.add(updatedCodex);
      await pumpEventQueue();

      expect(
        container.read(harnessesControllerProvider).value?.harnesses,
        <HarnessInfo>[claudeReady, updatedCodex],
      );
    });
  });
}
