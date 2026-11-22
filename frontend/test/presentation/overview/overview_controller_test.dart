import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/overview/overview_providers.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/presentation/overview/controllers/overview_controller.dart';
import 'package:agentic_hive_frontend/presentation/overview/controllers/overview_state.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pauses/fake_pause_repository.dart';
import 'fake_overview_repository.dart';

final class _FakePeriodicTimer implements Timer {
  new(this._callback);

  final void Function(Timer) _callback;
  int _tick = 0;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _tick++;
    _callback(this);
  }

  @override
  void cancel() {
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}

final class _FakeOneShotTimer implements Timer {
  new(this._callback);

  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() {
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

void main() {
  final baseTime = DateTime.utc(2026, 11, 21, 12);
  final startedAt = DateTime.utc(2026, 11, 21, 11, 59, 30);
  final pauseCreatedAt = DateTime.utc(2026, 11, 21, 11, 58);
  final tickedAt = DateTime.utc(2026, 11, 21, 12, 0, 1);

  OverviewSnapshot makeSnapshot({
    List<ActiveRunSummary> activeRuns = const <ActiveRunSummary>[],
    List<ActiveNodeSummary> activeNodes = const <ActiveNodeSummary>[],
    List<PendingPauseSummary> pendingPauses = const <PendingPauseSummary>[],
  }) {
    return OverviewSnapshot(
      metrics: OverviewMetrics(
        activeRunsCount: activeRuns.length,
        activeNodesCount: activeNodes.length,
        pendingPausesCount: pendingPauses.length,
        succeededLast24hCount: 4,
        failedLast24hCount: 1,
      ),
      activeRuns: activeRuns,
      activeNodes: activeNodes,
      pendingPauses: pendingPauses,
      recentRuns: const <RunSummary>[],
    );
  }

  ActiveRunSummary makeActiveRun() => ActiveRunSummary(
    runId: 'run-1',
    workflowName: 'Deploy Pipeline',
    status: RunStatus.running,
    startedAt: startedAt,
    activeNodeCount: 1,
  );

  PendingPauseSummary makePendingPause({String id = 'pause-1'}) =>
      PendingPauseSummary(
        pauseId: id,
        runId: 'run-1',
        workflowName: 'Deploy Pipeline',
        nodeId: 'node-approve',
        nodeLabel: 'Approve Deploy',
        pauseKind: PauseKind.humanApproval,
        prompt: 'Ship to production?',
        requiresFeedback: false,
        createdAt: pauseCreatedAt,
      );

  Pause makePauseModel({String id = 'pause-1'}) => Pause(
    id: id,
    runId: 'run-1',
    nodeId: 'node-approve',
    kind: PauseKind.humanApproval,
    status: PauseStatus.pending,
    workflowName: 'Deploy Pipeline',
    nodeLabel: 'Approve Deploy',
    createdAt: pauseCreatedAt,
    title: 'Ship to production?',
  );

  test('loads initial snapshot on build', () async {
    final snapshot = makeSnapshot(
      activeRuns: <ActiveRunSummary>[makeActiveRun()],
    );
    final overviewRepo = FakeOverviewRepository(
      initialResult: Success<OverviewSnapshot>(snapshot),
    );
    final pauseRepo = FakePauseRepository();
    addTearDown(() async {
      await overviewRepo.dispose();
      await pauseRepo.dispose();
    });

    final container = ProviderContainer.test(
      overrides: [
        overviewRepositoryProvider.overrideWithValue(overviewRepo),
        pauseRepositoryProvider.overrideWithValue(pauseRepo),
      ],
    );

    final sub = container.listen(overviewControllerProvider, (_, _) {});
    addTearDown(sub.close);

    final initial = container.read(overviewControllerProvider);
    expect(initial.snapshot.isLoading, isTrue);

    await Future<void>.delayed(Duration.zero);
    final loaded = container.read(overviewControllerProvider);
    expect(loaded.snapshot.asData?.value, snapshot);
    expect(overviewRepo.getOverviewCalls, 1);
  });

  test(
    'debounces run/node WS events and refetches immediately on reconnect',
    () async {
      final overviewRepo = FakeOverviewRepository(
        initialResult: Success<OverviewSnapshot>(makeSnapshot()),
      );
      final pauseRepo = FakePauseRepository();
      final oneShotTimers = <_FakeOneShotTimer>[];
      addTearDown(() async {
        await overviewRepo.dispose();
        await pauseRepo.dispose();
      });

      final container = ProviderContainer.test(
        overrides: [
          overviewRepositoryProvider.overrideWithValue(overviewRepo),
          pauseRepositoryProvider.overrideWithValue(pauseRepo),
          overviewClockConfigProvider.overrideWithValue(
            OverviewClockConfig(
              now: () => baseTime,
              createOneShotTimer: (_, callback) {
                final timer = _FakeOneShotTimer(callback);
                oneShotTimers.add(timer);
                return timer;
              },
            ),
          ),
        ],
      );

      final sub = container.listen(overviewControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final controller = container.read(overviewControllerProvider.notifier);
      expect(controller, isNotNull);
      await Future<void>.delayed(Duration.zero);
      expect(overviewRepo.getOverviewCalls, 1);

      // Burst of run + node events coalesces into one debounced resync.
      overviewRepo
        ..emitRunEvent(
          RunEvent(
            id: 'evt-1',
            runId: 'run-1',
            sequence: 1,
            type: RunEventType.runStarted,
            createdAt: baseTime,
          ),
        )
        ..emitRunEvent(
          RunEvent(
            id: 'evt-2',
            runId: 'run-1',
            sequence: 2,
            type: RunEventType.nodeStarted,
            nodeId: 'node-1',
            createdAt: baseTime,
          ),
        );
      await Future<void>.delayed(Duration.zero);
      expect(oneShotTimers.length, 2);
      expect(oneShotTimers.first.isActive, isFalse);
      expect(oneShotTimers.last.isActive, isTrue);
      expect(overviewRepo.getOverviewCalls, 1);

      oneShotTimers.last.fire();
      await Future<void>.delayed(Duration.zero);
      expect(overviewRepo.getOverviewCalls, 2);

      // Reconnect immediately refetches without waiting for debounce.
      overviewRepo.emitReconnectSync();
      await Future<void>.delayed(Duration.zero);
      expect(overviewRepo.getOverviewCalls, 3);
    },
  );

  test('starts 1-second timer only when active runs/nodes exist, stops when '
      'empty, and disposes cleanly', () async {
    var currentTime = baseTime;
    final periodicTimers = <_FakePeriodicTimer>[];
    final overviewRepo = FakeOverviewRepository(
      initialResult: Success<OverviewSnapshot>(makeSnapshot()),
    );
    final pauseRepo = FakePauseRepository();
    addTearDown(() async {
      await overviewRepo.dispose();
      await pauseRepo.dispose();
    });

    final container = ProviderContainer.test(
      overrides: [
        overviewRepositoryProvider.overrideWithValue(overviewRepo),
        pauseRepositoryProvider.overrideWithValue(pauseRepo),
        overviewClockConfigProvider.overrideWithValue(
          OverviewClockConfig(
            now: () => currentTime,
            createPeriodicTimer: (_, callback) {
              final timer = _FakePeriodicTimer(callback);
              periodicTimers.add(timer);
              return timer;
            },
            createOneShotTimer: (_, callback) => _FakeOneShotTimer(callback),
          ),
        ),
      ],
    );

    final sub = container.listen(overviewControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final controller = container.read(overviewControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    // Empty snapshot -> no periodic timer started.
    expect(periodicTimers, isEmpty);

    // Load active run -> starts 1-second timer.
    overviewRepo.nextResult = Success<OverviewSnapshot>(
      makeSnapshot(activeRuns: <ActiveRunSummary>[makeActiveRun()]),
    );
    await controller.refresh();
    expect(periodicTimers.length, 1);
    expect(periodicTimers.single.isActive, isTrue);

    // Tick updates `now` without polling the backend.
    currentTime = tickedAt;
    periodicTimers.single.fire();
    expect(container.read(overviewControllerProvider).now, currentTime);
    expect(overviewRepo.getOverviewCalls, 2);

    // Transition back to empty -> cancels timer.
    overviewRepo.nextResult = Success<OverviewSnapshot>(makeSnapshot());
    await container.read(overviewControllerProvider.notifier).refresh();
    expect(periodicTimers.single.isActive, isFalse);

    // Re-activate and verify disposal cancels the timer.
    overviewRepo.nextResult = Success<OverviewSnapshot>(
      makeSnapshot(activeRuns: <ActiveRunSummary>[makeActiveRun()]),
    );
    await container.read(overviewControllerProvider.notifier).refresh();
    expect(periodicTimers.length, 2);
    expect(periodicTimers.last.isActive, isTrue);

    container.dispose();
    expect(periodicTimers.last.isActive, isFalse);
  });

  test('inline approve tracks loading state, removes pause on success, and '
      'shows inline error on 409', () async {
    final pauseSummary = makePendingPause();
    final overviewRepo = FakeOverviewRepository(
      initialResult: Success<OverviewSnapshot>(
        makeSnapshot(pendingPauses: <PendingPauseSummary>[pauseSummary]),
      ),
    );
    final pauseRepo = FakePauseRepository(initial: <Pause>[makePauseModel()]);
    addTearDown(() async {
      await overviewRepo.dispose();
      await pauseRepo.dispose();
    });

    final container = ProviderContainer.test(
      overrides: [
        overviewRepositoryProvider.overrideWithValue(overviewRepo),
        pauseRepositoryProvider.overrideWithValue(pauseRepo),
      ],
    );

    final sub = container.listen(overviewControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final controller = container.read(overviewControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    // 409 conflict surfaces inline card error.
    pauseRepo.onAnswerPause = (_, _) async =>
        const FailureResult<Pause>(ConflictFailure('Already resolved'));
    final failed = await controller.approvePause('pause-1');
    expect(failed, isFalse);
    final errorState = container.read(overviewControllerProvider);
    expect(errorState.errorForPause('pause-1'), isA<ConflictFailure>());
    expect(errorState.submittingActionFor('pause-1'), isNull);

    controller.dismissPauseError('pause-1');
    expect(
      container.read(overviewControllerProvider).errorForPause('pause-1'),
      isNull,
    );

    // Pending answer shows loading state, then removes pause on success.
    final answerCompleter = Completer<Result<Pause>>();
    pauseRepo.onAnswerPause = (_, _) => answerCompleter.future;

    final pendingFuture = controller.approvePause('pause-1');
    expect(
      container.read(overviewControllerProvider).submittingActionFor('pause-1'),
      OverviewPauseAction.approve,
    );

    overviewRepo.nextResult = Success<OverviewSnapshot>(makeSnapshot());
    answerCompleter.complete(
      Success<Pause>(makePauseModel().copyWith(status: PauseStatus.answered)),
    );
    final succeeded = await pendingFuture;
    expect(succeeded, isTrue);
    final afterState = container.read(overviewControllerProvider);
    expect(afterState.submittingActionFor('pause-1'), isNull);
    expect(afterState.snapshot.asData?.value.pendingPauses, isEmpty);
  });
}
