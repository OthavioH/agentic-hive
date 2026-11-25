import 'dart:async';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/graph_engine.dart';
import 'package:agentic_hive_backend/src/domain/nodes/child_run_port.dart';
import 'package:agentic_hive_backend/src/domain/nodes/fan_out_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/human_approval_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_backend/src/domain/runs/pausing_human_approval_port.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_recovery_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

import 'fake_ports.dart';
import 'in_memory_repositories.dart';

/// Id of the run created by [EngineHarness.createRun].
const String runId = 'run-1';

/// Builds a command-typed (fake) workflow node.
WorkflowNode fakeNode(String id) => WorkflowNode(
  id: id,
  type: NodeTypeId.command,
  label: id,
  position: const WorkflowPosition(x: 0, y: 0),
);

/// Builds a `human_approval` workflow node.
WorkflowNode approvalNode(String id) => WorkflowNode(
  id: id,
  type: NodeTypeId.humanApproval,
  label: id,
  position: const WorkflowPosition(x: 0, y: 0),
  config: const <String, Object?>{'instructions': 'Please review.'},
);

/// Builds an edge `from --output--> to`, optionally limited by [maxRetries].
WorkflowEdge edge(String from, String output, String to, {int? maxRetries}) =>
    WorkflowEdge(
      id: '$from-$output-$to',
      sourceNodeId: from,
      sourceOutput: output,
      targetNodeId: to,
      maxRetries: maxRetries,
    );

/// Builds a workflow. Every id in [nodeIds] is a fake node unless it is listed
/// in [approvals].
Workflow buildWorkflow({
  required List<String> nodeIds,
  required List<WorkflowEdge> edges,
  Set<String> approvals = const <String>{},
  String? entry,
  bool noEntry = false,
}) {
  final at = DateTime.utc(2026);
  return Workflow(
    id: 'wf-1',
    name: 'Test workflow',
    nodes: [
      for (final id in nodeIds)
        if (approvals.contains(id)) approvalNode(id) else fakeNode(id),
    ],
    edges: edges,
    createdAt: at,
    updatedAt: at,
    entryNodeId: noEntry ? null : (entry ?? nodeIds.first),
  );
}

/// Counts approval requests and delegates to [PausingHumanApprovalPort].
final class CountingApprovalPort implements HumanApprovalPort {
  /// Creates a counting port.
  new();

  /// Number of approval requests received.
  int requests = 0;

  @override
  Future<Result<HumanApprovalResponse>> requestApproval(
    HumanApprovalRequest request,
  ) {
    requests++;
    return const PausingHumanApprovalPort().requestApproval(request);
  }
}

/// Wires a [GraphEngine] to in-memory repositories and fake ports.
final class EngineHarness {
  /// Creates a harness.
  new({
    int maxConcurrency = GraphEngine.defaultMaxConcurrency,
    int circuitBreakerThreshold = GraphEngine.defaultCircuitBreakerThreshold,
    Duration cancelGracePeriod = const Duration(seconds: 1),
    ChildRunPort Function()? childRuns,
    void Function(NodeRegistry registry)? registerNodes,
    bool registerFakeCommand = true,
  }) {
    snapshots.clock = tick;
    final registry = NodeRegistry()
      ..register(
        NodeDescriptors.humanApproval,
        () => HumanApprovalNode(approvalPort: approvalPort),
      );
    if (registerFakeCommand) {
      registry.register(NodeDescriptors.command, () => FakeNode(script));
    }
    if (childRuns != null) {
      registry.register(
        NodeDescriptors.fanOut,
        () => FanOutNode(
          childRuns: childRuns(),
          pollInterval: const Duration(milliseconds: 1),
        ),
      );
    }
    registerNodes?.call(registry);
    recovery = RunRecoveryService(
      runs: runs,
      checkpoints: checkpoints,
      generateId: nextId,
      now: tick,
    );
    engine = GraphEngine(
      registry: registry,
      runs: runs,
      checkpoints: checkpoints,
      events: events,
      recovery: recovery,
      snapshots: snapshots,
      pauseGateway: gateway,
      processTreeKiller: killer,
      pauses: pauses,
      maxConcurrency: maxConcurrency,
      circuitBreakerThreshold: circuitBreakerThreshold,
      cancelGracePeriod: cancelGracePeriod,
      generateId: nextId,
      now: tick,
    );
  }

  /// Script for the fake nodes.
  final NodeScript script = NodeScript();

  /// In-memory run repository.
  final InMemoryRunRepository runs = InMemoryRunRepository();

  /// In-memory checkpoint repository.
  final InMemoryCheckpointRepository checkpoints =
      InMemoryCheckpointRepository();

  /// In-memory event repository.
  final InMemoryRunEventRepository events = InMemoryRunEventRepository();

  /// In-memory pause repository.
  final InMemoryPauseRepository pauses = InMemoryPauseRepository();

  /// Fake snapshot service.
  final FakeSnapshotService snapshots = FakeSnapshotService();

  /// Fake process tree killer.
  final FakeProcessTreeKiller killer = FakeProcessTreeKiller();

  /// The real in-memory `ask_human` gateway.
  final InMemoryHumanPauseGateway gateway = InMemoryHumanPauseGateway();

  /// Approval port used by `human_approval` nodes.
  final CountingApprovalPort approvalPort = CountingApprovalPort();

  /// Recovery service over the in-memory repositories.
  late final RunRecoveryService recovery;

  /// The engine under test.
  late final GraphEngine engine;

  int _ids = 0;
  int _seconds = 0;

  /// A new unique id.
  String nextId() => 'id-${_ids++}';

  /// A strictly increasing deterministic timestamp.
  DateTime tick() => DateTime.utc(2026).add(Duration(seconds: _seconds++));

  /// Persists a run of [workflow] in [status].
  Future<Run> createRun(
    Workflow workflow, {
    RunStatus status = RunStatus.running,
    String? input,
  }) async {
    final run = Run(
      id: runId,
      workflowName: workflow.name,
      workflowDefinition: workflow,
      workspacePath: '/workspace',
      status: status,
      startedAt: DateTime.utc(2026),
      input: input,
    );
    await runs.create(run);
    return run;
  }

  /// The persisted run.
  Run get run => runs.runs[runId]!;

  /// Event types of the run in order.
  List<RunEventType> get eventTypes => events.typesOf(runId);

  /// Waits until all queued microtasks and timers at the current time ran.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));
}
