import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/overview/overview_repository.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [OverviewRepository] that aggregates [OverviewSnapshot] from the existing
/// [RunRepository], [RunEventRepository], [PauseRepository], and
/// [AgentRepository].
final class RepositoryOverviewRepository implements OverviewRepository {
  /// Creates an overview repository over the existing domain repositories.
  const new({
    required this._runs,
    required this._events,
    required this._pauses,
    required this._agents,
  });

  static const int _recentRunsLimit = 5;
  static const int _pausePageSize = 200;

  final RunRepository _runs;
  final RunEventRepository _events;
  final PauseRepository _pauses;
  final AgentRepository _agents;

  @override
  Future<Result<OverviewSnapshot>> getSnapshot({required DateTime now}) async {
    final utcNow = now.toUtc();
    final cutoff24h = utcNow.subtract(const Duration(hours: 24));

    final pausedResult = await _runs.listByStatus(RunStatus.paused);
    if (pausedResult case FailureResult<List<Run>>(:final failure)) {
      return FailureResult(failure);
    }
    final runningResult = await _runs.listByStatus(RunStatus.running);
    if (runningResult case FailureResult<List<Run>>(:final failure)) {
      return FailureResult(failure);
    }

    final activeRunRecords = <Run>[
      ...pausedResult.valueOrNull!,
      ...runningResult.valueOrNull!,
    ]..sort(_compareActiveRuns);

    final pendingPausesResult = await _loadAllPendingPauses();
    if (pendingPausesResult case FailureResult<List<Pause>>(:final failure)) {
      return FailureResult(failure);
    }
    final pendingPauseRecords = pendingPausesResult.valueOrNull!
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final agentsResult = await _agents.list();
    if (agentsResult case FailureResult<List<AgentSummary>>(:final failure)) {
      return FailureResult(failure);
    }
    final agentNamesById = <String, String>{
      for (final agent in agentsResult.valueOrNull!) agent.id: agent.name,
    };

    final pendingPausesByRunId = <String, List<Pause>>{};
    for (final pause in pendingPauseRecords) {
      pendingPausesByRunId.putIfAbsent(pause.runId, () => <Pause>[]).add(pause);
    }

    final activeRunIds = activeRunRecords
        .map((run) => run.id)
        .toList(growable: false);
    final executingNodesResult = await _events.findExecutingNodesForRuns(
      activeRunIds,
    );
    if (executingNodesResult
        case FailureResult<Map<String, Map<String, DateTime>>>(
          :final failure,
        )) {
      return FailureResult(failure);
    }
    final executingByRunId = executingNodesResult.valueOrNull!;

    final activeNodes = <ActiveNodeSummary>[];
    final activeNodeCountByRunId = <String, int>{};

    for (final run in activeRunRecords) {
      final nodesById = <String, WorkflowNode>{
        for (final node in run.workflowDefinition.nodes) node.id: node,
      };
      final seenNodeIds = <String>{};

      final runPauses = pendingPausesByRunId[run.id] ?? const <Pause>[];
      for (final pause in runPauses) {
        final workflowNode = nodesById[pause.nodeId];
        final agentId = _extractAgentId(workflowNode);
        activeNodes.add(
          ActiveNodeSummary(
            runId: run.id,
            workflowName: run.workflowName,
            nodeId: pause.nodeId,
            nodeType: workflowNode?.type ?? NodeTypeId.humanApproval,
            nodeLabel: workflowNode?.label ?? pause.nodeLabel,
            agentId: agentId,
            agentName: agentId == null ? null : agentNamesById[agentId],
            status: ActiveNodeStatus.paused,
            startedAt: pause.createdAt,
          ),
        );
        seenNodeIds.add(pause.nodeId);
      }

      final executingNodes =
          executingByRunId[run.id] ?? const <String, DateTime>{};
      for (final entry in executingNodes.entries) {
        final nodeId = entry.key;
        if (!seenNodeIds.add(nodeId)) continue;
        final workflowNode = nodesById[nodeId];
        final agentId = _extractAgentId(workflowNode);
        activeNodes.add(
          ActiveNodeSummary(
            runId: run.id,
            workflowName: run.workflowName,
            nodeId: nodeId,
            nodeType: workflowNode?.type ?? '',
            nodeLabel: workflowNode?.label ?? nodeId,
            agentId: agentId,
            agentName: agentId == null ? null : agentNamesById[agentId],
            status: ActiveNodeStatus.running,
            startedAt: entry.value,
          ),
        );
      }

      activeNodeCountByRunId[run.id] = seenNodeIds.length;
    }

    activeNodes.sort(_compareActiveNodes);

    final activeRuns = activeRunRecords
        .map(
          (run) => ActiveRunSummary(
            runId: run.id,
            workflowId: run.workflowId,
            workflowName: run.workflowName,
            status: run.status,
            startedAt: run.startedAt,
            activeNodeCount: activeNodeCountByRunId[run.id] ?? 0,
          ),
        )
        .toList(growable: false);

    final pendingPauses = pendingPauseRecords
        .map(
          (pause) => PendingPauseSummary(
            pauseId: pause.id,
            runId: pause.runId,
            workflowName: pause.workflowName,
            nodeId: pause.nodeId,
            nodeLabel: pause.nodeLabel,
            pauseKind: pause.kind,
            prompt: _pausePrompt(pause),
            // Pause only models optional `allowFeedback` and has no
            // required-feedback concept; keep `false` until the domain
            // supports mandatory feedback.
            requiresFeedback: false,
            createdAt: pause.createdAt,
          ),
        )
        .toList(growable: false);

    final succeeded24hResult = await _runs.countByStatusFinishedSince(
      RunStatus.succeeded,
      finishedSince: cutoff24h,
    );
    if (succeeded24hResult case FailureResult<int>(:final failure)) {
      return FailureResult(failure);
    }

    final failed24hResult = await _runs.countByStatusFinishedSince(
      RunStatus.failed,
      finishedSince: cutoff24h,
    );
    if (failed24hResult case FailureResult<int>(:final failure)) {
      return FailureResult(failure);
    }

    final recentRunsResult = await _loadRecentRuns(
      activeRunCount: activeRunRecords.length,
    );
    if (recentRunsResult case FailureResult<List<RunSummary>>(:final failure)) {
      return FailureResult(failure);
    }
    final recentRuns = recentRunsResult.valueOrNull!;

    return Success(
      OverviewSnapshot(
        metrics: OverviewMetrics(
          activeRunsCount: activeRuns.length,
          activeNodesCount: activeNodes.length,
          pendingPausesCount: pendingPauses.length,
          succeededLast24hCount: succeeded24hResult.valueOrNull!,
          failedLast24hCount: failed24hResult.valueOrNull!,
        ),
        activeRuns: activeRuns,
        activeNodes: activeNodes,
        pendingPauses: pendingPauses,
        recentRuns: recentRuns,
      ),
    );
  }

  Future<Result<List<Pause>>> _loadAllPendingPauses() async {
    final all = <Pause>[];
    var offset = 0;
    while (true) {
      final pageResult = await _pauses.list(
        status: PauseStatus.pending,
        limit: _pausePageSize,
        offset: offset,
      );
      if (pageResult case FailureResult<({List<Pause> items, int total})>(
        :final failure,
      )) {
        return FailureResult(failure);
      }
      final page = pageResult.valueOrNull!;
      all.addAll(page.items);
      if (all.length >= page.total || page.items.isEmpty) {
        return Success(all);
      }
      offset += page.items.length;
    }
  }

  Future<Result<List<RunSummary>>> _loadRecentRuns({
    required int activeRunCount,
  }) async {
    final queryLimit = activeRunCount + _recentRunsLimit + 10;
    final result = await _runs.list(limit: queryLimit);
    return result.map(
      (page) => page.items
          .where((run) => !run.status.isRunningOrPaused)
          .take(_recentRunsLimit)
          .toList(growable: false),
    );
  }

  static int _compareActiveRuns(Run a, Run b) {
    final aPaused = a.status == RunStatus.paused;
    final bPaused = b.status == RunStatus.paused;
    if (aPaused != bPaused) return aPaused ? -1 : 1;
    return b.startedAt.compareTo(a.startedAt);
  }

  static int _compareActiveNodes(ActiveNodeSummary a, ActiveNodeSummary b) {
    final aRunning = a.status == ActiveNodeStatus.running;
    final bRunning = b.status == ActiveNodeStatus.running;
    if (aRunning != bRunning) return aRunning ? -1 : 1;
    return b.startedAt.compareTo(a.startedAt);
  }

  static String? _extractAgentId(WorkflowNode? node) {
    final raw = node?.config['agentId'];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _pausePrompt(Pause pause) {
    for (final candidate in [pause.question, pause.instructions, pause.title]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate;
      }
    }
    return '';
  }
}
