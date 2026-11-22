import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/overview/overview_event.dart';
import 'package:agentic_hive_frontend/domain/overview/overview_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

final class FakeOverviewRepository implements OverviewRepository {
  new({Result<OverviewSnapshot>? initialResult})
    : nextResult =
          initialResult ??
          const Success<OverviewSnapshot>(
            OverviewSnapshot(
              metrics: OverviewMetrics(
                activeRunsCount: 0,
                activeNodesCount: 0,
                pendingPausesCount: 0,
                succeededLast24hCount: 0,
                failedLast24hCount: 0,
              ),
              activeRuns: <ActiveRunSummary>[],
              activeNodes: <ActiveNodeSummary>[],
              pendingPauses: <PendingPauseSummary>[],
              recentRuns: <RunSummary>[],
            ),
          );

  final StreamController<OverviewEvent> _eventsController =
      StreamController<OverviewEvent>.broadcast();

  Result<OverviewSnapshot> nextResult;
  Completer<Result<OverviewSnapshot>>? pendingGetCompleter;
  int getOverviewCalls = 0;

  @override
  Future<Result<OverviewSnapshot>> getOverview() {
    getOverviewCalls++;
    final completer = pendingGetCompleter;
    if (completer != null) {
      return completer.future;
    }
    return Future<Result<OverviewSnapshot>>.value(nextResult);
  }

  @override
  Stream<OverviewEvent> watchOverviewEvents() => _eventsController.stream;

  void emitRunEvent(RunEvent event) {
    _eventsController.add(OverviewRunEventReceived(event));
  }

  void emitPauseCreated(Pause pause) {
    _eventsController.add(OverviewPauseCreatedEvent(pause));
  }

  void emitPauseResolved(Pause pause) {
    _eventsController.add(OverviewPauseResolvedEvent(pause));
  }

  void emitReconnectSync() {
    _eventsController.add(const OverviewSyncRequestedEvent());
  }

  Future<void> dispose() => _eventsController.close();
}
