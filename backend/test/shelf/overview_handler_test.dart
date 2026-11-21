import 'package:agentic_hive_backend/src/api/overview/overview_handler.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/overview/repository_overview_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/overview/overview_service.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _FakeRunRepository implements RunRepository {
  final List<Run> runs = <Run>[];
  Failure? failOnListByStatus;

  @override
  Future<Result<Run>> create(Run run) async {
    runs.add(run);
    return Success(run);
  }

  @override
  Future<Result<Run>> getById(String id) async =>
      FailureResult(NotFoundFailure('Run "$id" not found.'));

  @override
  Future<Result<({List<RunSummary> items, int total})>> list({
    RunStatus? status,
    String? workflowId,
    int limit = 50,
    int offset = 0,
  }) async {
    final filtered =
        runs
            .where((r) => status == null || r.status == status)
            .where((r) => workflowId == null || r.workflowId == workflowId)
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final page = filtered.skip(offset).take(limit).map((r) {
      return RunSummary(
        id: r.id,
        workflowId: r.workflowId,
        workflowName: r.workflowName,
        status: r.status,
        startedAt: r.startedAt,
        finishedAt: r.finishedAt,
        checkpointCount: 0,
      );
    }).toList();
    return Success((items: page, total: filtered.length));
  }

  @override
  Future<Result<List<Run>>> listByStatus(RunStatus status) async {
    if (failOnListByStatus != null) {
      return FailureResult(failOnListByStatus!);
    }
    return Success(runs.where((r) => r.status == status).toList());
  }

  @override
  Future<Result<Run>> updateStatus(
    String id, {
    required RunStatus status,
    DateTime? finishedAt,
    String? errorMessage,
    bool clearFinishedAt = false,
    bool clearErrorMessage = false,
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> markInterruptedWithEvent(
    String runId, {
    required String eventId,
    required DateTime createdAt,
    JsonMap payload = const {},
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> markCancellationUncertainWithEvent(
    String runId, {
    required String eventId,
    required DateTime createdAt,
    JsonMap payload = const {},
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> delete(String id) => throw UnimplementedError();
}

final class _FakeRunEventRepository implements RunEventRepository {
  final Map<String, List<RunEvent>> eventsByRun = <String, List<RunEvent>>{};

  @override
  Future<Result<RunEvent>> append({
    required String id,
    required String runId,
    required RunEventType type,
    required DateTime createdAt,
    String? nodeId,
    String? edgeId,
    JsonMap payload = const {},
    int? sequence,
  }) => throw UnimplementedError();

  @override
  Future<Result<({List<RunEvent> items, int lastSequence})>> listForRun(
    String runId, {
    int? afterSequence,
    int? limit,
  }) async {
    final items = eventsByRun[runId] ?? const <RunEvent>[];
    return Success((items: items, lastSequence: items.length));
  }
}

final class _FakePauseRepository implements PauseRepository {
  final List<Pause> pauses = <Pause>[];

  @override
  Future<Result<Pause>> create(Pause pause) async {
    pauses.add(pause);
    return Success(pause);
  }

  @override
  Future<Result<Pause>> getById(String id) => throw UnimplementedError();

  @override
  Future<Result<({List<Pause> items, int total})>> list({
    PauseStatus? status,
    String? runId,
    int limit = 50,
    int offset = 0,
  }) async {
    final filtered =
        pauses
            .where((p) => status == null || p.status == status)
            .where((p) => runId == null || p.runId == runId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final page = filtered.skip(offset).take(limit).toList();
    return Success((items: page, total: filtered.length));
  }

  @override
  Future<Result<List<Pause>>> listPendingForRun(String runId) async => Success(
    pauses
        .where((p) => p.runId == runId && p.status == PauseStatus.pending)
        .toList(),
  );

  @override
  Future<Result<Pause>> markAnswered(
    String id, {
    required DateTime answeredAt,
    String? decision,
    String? feedback,
    String? answer,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<Pause>>> cancelPendingForRun(
    String runId, {
    required DateTime cancelledAt,
  }) => throw UnimplementedError();

  @override
  Future<Result<List<Pause>>> cancelPendingForNode(
    String runId,
    String nodeId, {
    required DateTime cancelledAt,
  }) => throw UnimplementedError();
}

final class _FakeAgentRepository implements AgentRepository {
  final List<AgentSummary> agents = <AgentSummary>[];

  @override
  Future<Result<List<AgentSummary>>> list() async => Success(agents);

  @override
  Future<Result<AgentDetail>> getById(String id) => throw UnimplementedError();

  @override
  Future<Result<AgentDetail>> create(CreateAgentRequest request) =>
      throw UnimplementedError();

  @override
  Future<Result<AgentDetail>> update(String id, UpdateAgentRequest request) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> delete(String id) => throw UnimplementedError();
}

Workflow _workflow(String id, String name, List<WorkflowNode> nodes) =>
    Workflow(
      id: id,
      name: name,
      nodes: nodes,
      edges: const [],
      entryNodeId: nodes.first.id,
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 20),
    );

void main() {
  final now = DateTime.utc(2026, 11, 21, 12);

  late _FakeRunRepository runsRepo;
  late _FakeRunEventRepository eventsRepo;
  late _FakePauseRepository pausesRepo;
  late _FakeAgentRepository agentsRepo;
  late Handler handler;

  setUp(() {
    runsRepo = _FakeRunRepository();
    eventsRepo = _FakeRunEventRepository();
    pausesRepo = _FakePauseRepository();
    agentsRepo = _FakeAgentRepository();

    final overviewRepo = RepositoryOverviewRepository(
      runs: runsRepo,
      events: eventsRepo,
      pauses: pausesRepo,
      agents: agentsRepo,
    );
    final overviewService = OverviewService(overviewRepo, now: () => now);
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 6),
        ),
        version: '1.0.0',
        dataDir: '/data',
        startedAt: now,
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (_) => Response(418),
      overviewHandler: OverviewHandler(service: overviewService),
    );
  });

  test(
    'returns empty snapshot when no runs, pauses, or agents exist',
    () async {
      final response = await handler(buildRequest('/api/v1/overview'));
      expect(response.statusCode, 200);

      final snapshot = OverviewSnapshot.fromJson(await readJson(response));
      expect(
        snapshot.metrics,
        const OverviewMetrics(
          activeRunsCount: 0,
          activeNodesCount: 0,
          pendingPausesCount: 0,
          succeededLast24hCount: 0,
          failedLast24hCount: 0,
        ),
      );
      expect(snapshot.activeRuns, isEmpty);
      expect(snapshot.activeNodes, isEmpty);
      expect(snapshot.pendingPauses, isEmpty);
      expect(snapshot.recentRuns, isEmpty);
    },
  );

  test('aggregates active runs, active nodes, FIFO pauses, 24h metrics, '
      'and recent runs cap', () async {
    agentsRepo.agents.add(
      AgentSummary(
        id: 'senior-dev',
        name: 'Senior Developer',
        contentHash: 'hash-1',
        updatedAt: now,
      ),
    );

    final wfDeploy = _workflow('wf-deploy', 'Deploy Flow', const [
      WorkflowNode(
        id: 'coder',
        type: NodeTypeId.claudeCode,
        label: 'Implement Fix',
        position: WorkflowPosition(x: 0, y: 0),
        config: {'agentId': 'senior-dev'},
      ),
      WorkflowNode(
        id: 'gate',
        type: NodeTypeId.humanApproval,
        label: 'Prod Gate',
        position: WorkflowPosition(x: 100, y: 0),
        config: {'instructions': 'Approve rollout'},
      ),
    ]);

    final wfTest = _workflow('wf-test', 'Test Flow', const [
      WorkflowNode(
        id: 'cmd',
        type: NodeTypeId.command,
        label: 'Run Suite',
        position: WorkflowPosition(x: 0, y: 0),
        config: {'command': 'dart test'},
      ),
    ]);

    // Active runs: 1 running (newer), 1 paused (older)
    runsRepo.runs.addAll([
      Run(
        id: 'run-running',
        workflowId: wfTest.id,
        workflowName: wfTest.name,
        workflowDefinition: wfTest,
        workspacePath: '/ws/1',
        status: RunStatus.running,
        startedAt: now.subtract(const Duration(minutes: 5)),
      ),
      Run(
        id: 'run-paused',
        workflowId: wfDeploy.id,
        workflowName: wfDeploy.name,
        workflowDefinition: wfDeploy,
        workspacePath: '/ws/2',
        status: RunStatus.paused,
        startedAt: now.subtract(const Duration(minutes: 15)),
      ),
      // Non-active runs (must be excluded from activeRuns)
      Run(
        id: 'run-interrupted',
        workflowId: wfTest.id,
        workflowName: wfTest.name,
        workflowDefinition: wfTest,
        workspacePath: '/ws/3',
        status: RunStatus.interrupted,
        startedAt: now.subtract(const Duration(minutes: 20)),
      ),
      Run(
        id: 'run-cancelling',
        workflowId: wfTest.id,
        workflowName: wfTest.name,
        workflowDefinition: wfTest,
        workspacePath: '/ws/4',
        status: RunStatus.cancelling,
        startedAt: now.subtract(const Duration(minutes: 25)),
      ),
    ]);

    // 7 terminal runs across inside/outside the 24h window to test counts &
    // recentRuns cap of 5.
    for (var i = 0; i < 4; i++) {
      runsRepo.runs.add(
        Run(
          id: 'run-ok-$i',
          workflowId: wfTest.id,
          workflowName: wfTest.name,
          workflowDefinition: wfTest,
          workspacePath: '/ws/ok/$i',
          status: RunStatus.succeeded,
          startedAt: now.subtract(Duration(hours: 2 + i)),
          finishedAt: now.subtract(Duration(hours: 1 + i)),
        ),
      );
    }
    runsRepo.runs.addAll([
      // Exactly 24h ago -> included
      Run(
        id: 'run-fail-in',
        workflowId: wfTest.id,
        workflowName: wfTest.name,
        workflowDefinition: wfTest,
        workspacePath: '/ws/fail/in',
        status: RunStatus.failed,
        startedAt: now.subtract(const Duration(hours: 25)),
        finishedAt: now.subtract(const Duration(hours: 24)),
      ),
      // 24h + 1s ago -> excluded from 24h metric
      Run(
        id: 'run-ok-old',
        workflowId: wfTest.id,
        workflowName: wfTest.name,
        workflowDefinition: wfTest,
        workspacePath: '/ws/ok/old',
        status: RunStatus.succeeded,
        startedAt: now.subtract(const Duration(hours: 26)),
        finishedAt: now.subtract(const Duration(hours: 24, seconds: 1)),
      ),
      Run(
        id: 'run-fail-old',
        workflowId: wfTest.id,
        workflowName: wfTest.name,
        workflowDefinition: wfTest,
        workspacePath: '/ws/fail/old',
        status: RunStatus.failed,
        startedAt: now.subtract(const Duration(hours: 30)),
        finishedAt: now.subtract(const Duration(hours: 29)),
      ),
    ]);

    // Events: run-running has cmd executing; run-paused has coder completed.
    eventsRepo.eventsByRun['run-running'] = [
      RunEvent(
        id: 'ev-1',
        runId: 'run-running',
        sequence: 1,
        type: RunEventType.nodeStarted,
        nodeId: 'cmd',
        createdAt: now.subtract(const Duration(minutes: 4)),
      ),
    ];
    eventsRepo.eventsByRun['run-paused'] = [
      RunEvent(
        id: 'ev-2',
        runId: 'run-paused',
        sequence: 1,
        type: RunEventType.nodeStarted,
        nodeId: 'coder',
        createdAt: now.subtract(const Duration(minutes: 14)),
      ),
      RunEvent(
        id: 'ev-3',
        runId: 'run-paused',
        sequence: 2,
        type: RunEventType.nodeCompleted,
        nodeId: 'coder',
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
      // Simulate ask_human on coder started again? No, gate is paused below.
    ];

    // Pauses: 2 pending (out of order in list to test FIFO sort) + 1 answered
    pausesRepo.pauses.addAll([
      Pause(
        id: 'pause-newer',
        runId: 'run-paused',
        nodeId: 'coder',
        kind: PauseKind.askHuman,
        status: PauseStatus.pending,
        workflowName: wfDeploy.name,
        nodeLabel: 'Implement Fix',
        question: 'Which branch?',
        createdAt: now.subtract(const Duration(minutes: 2)),
      ),
      Pause(
        id: 'pause-older',
        runId: 'run-paused',
        nodeId: 'gate',
        kind: PauseKind.humanApproval,
        status: PauseStatus.pending,
        workflowName: wfDeploy.name,
        nodeLabel: 'Prod Gate',
        instructions: 'Approve rollout',
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
      Pause(
        id: 'pause-answered',
        runId: 'run-paused',
        nodeId: 'gate',
        kind: PauseKind.humanApproval,
        status: PauseStatus.answered,
        workflowName: wfDeploy.name,
        nodeLabel: 'Prod Gate',
        decision: 'approved',
        createdAt: now.subtract(const Duration(minutes: 30)),
        answeredAt: now.subtract(const Duration(minutes: 25)),
      ),
    ]);

    final response = await handler(buildRequest('/api/v1/overview'));
    expect(response.statusCode, 200);

    final snapshot = OverviewSnapshot.fromJson(await readJson(response));
    expect(
      snapshot.metrics,
      const OverviewMetrics(
        activeRunsCount: 2,
        activeNodesCount: 3,
        pendingPausesCount: 2,
        succeededLast24hCount: 4,
        failedLast24hCount: 1,
      ),
    );

    // Active runs: paused first, then running
    expect(
      snapshot.activeRuns.map((r) => (r.runId, r.activeNodeCount)).toList(),
      [('run-paused', 2), ('run-running', 1)],
    );

    // Active nodes: running first, then paused newest-first
    expect(
      snapshot.activeNodes
          .map((n) => (n.nodeId, n.status, n.nodeType, n.agentName))
          .toList(),
      [
        ('cmd', ActiveNodeStatus.running, NodeTypeId.command, null),
        (
          'coder',
          ActiveNodeStatus.paused,
          NodeTypeId.claudeCode,
          'Senior Developer',
        ),
        ('gate', ActiveNodeStatus.paused, NodeTypeId.humanApproval, null),
      ],
    );

    // Pending pauses: FIFO (oldest first)
    expect(snapshot.pendingPauses.map((p) => p.pauseId).toList(), [
      'pause-older',
      'pause-newer',
    ]);
    expect(snapshot.pendingPauses.first.prompt, 'Approve rollout');
    expect(snapshot.pendingPauses.last.prompt, 'Which branch?');

    // Recent runs: capped at 5, non-active only, newest startedAt first
    expect(snapshot.recentRuns.length, 5);
    expect(snapshot.recentRuns.map((r) => r.id).toList(), [
      'run-interrupted',
      'run-ok-0',
      'run-ok-1',
      'run-ok-2',
      'run-ok-3',
    ]);
  });

  test('rejects requests with an Origin header', () async {
    final response = await handler(
      buildRequest('/api/v1/overview', headers: {'origin': 'http://evil.test'}),
    );
    expect(response.statusCode, 403);
    final error = ApiError.fromJson(await readJson(response));
    expect(error.code, ApiErrorCode.originNotAllowed);
  });

  test('maps repository failures to 500 ApiError', () async {
    runsRepo.failOnListByStatus = const PersistenceFailure('db offline');
    final response = await handler(buildRequest('/api/v1/overview'));
    expect(response.statusCode, 500);
    final error = ApiError.fromJson(await readJson(response));
    expect(error.code, ApiErrorCode.internalError);
  });
}
