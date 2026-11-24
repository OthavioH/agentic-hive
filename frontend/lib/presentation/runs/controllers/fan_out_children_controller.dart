import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fan_out_children_controller.g.dart';

const Set<RunStatus> _finalRunStatuses = <RunStatus>{
  RunStatus.succeeded,
  RunStatus.failed,
  RunStatus.cancelled,
  RunStatus.cancellationUncertain,
};

/// Loads and keeps fresh the child runs of parent run [runId].
@riverpod
class FanOutChildrenController extends _$FanOutChildrenController {
  final Set<String> _knownIds = <String>{};

  @override
  Future<List<Run>> build(String runId) async {
    final previous = state.asData?.value ?? const <Run>[];
    final cachedFinal = <String, Run>{
      for (final run in previous)
        if (_finalRunStatuses.contains(run.status)) run.id: run,
    };

    ref.listen<AsyncValue<WsEnvelope>>(backendWsMessagesProvider, (_, next) {
      final envelope = next.asData?.value;
      if (envelope == null || envelope.type != WsMessageType.runEvent) {
        return;
      }
      try {
        final event = RunEventPayload.fromJson(envelope.payload).event;
        if (event.runId == runId ||
            _knownIds.contains(event.runId) ||
            event.type == RunEventType.runStarted) {
          ref.invalidateSelf();
        }
      } on FormatException {
        // Ignore malformed event payloads.
      }
    });

    const pageSize = 200;
    final listRuns = ref.read(listRunsProvider);
    final childSummaries = <RunSummary>[];
    var offset = 0;

    while (true) {
      final result = await listRuns(limit: pageSize, offset: offset);
      switch (result) {
        case FailureResult<RunsListResponse>(:final failure):
          Error.throwWithStackTrace(failure, StackTrace.current);
        case Success<RunsListResponse>(:final value):
          if (value.items.isEmpty) break;
          for (final summary in value.items) {
            if (summary.parentRunId == runId) {
              childSummaries.add(summary);
            }
          }
          offset += value.items.length;
          if (offset >= value.total) break;
          continue;
      }
      break;
    }

    final getRun = ref.read(getRunProvider);
    final fetched = await Future.wait(
      childSummaries.map((summary) async {
        final cached = cachedFinal[summary.id];
        if (cached != null) return cached;
        final result = await getRun(summary.id);
        return result.valueOrNull;
      }),
    );

    final children = fetched.whereType<Run>().toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    _knownIds
      ..clear()
      ..addAll(children.map((run) => run.id));
    return children;
  }

  /// Reloads the child runs (used by Retry).
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
