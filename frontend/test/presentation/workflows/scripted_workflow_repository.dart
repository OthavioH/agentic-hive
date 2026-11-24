import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// A deletion refused because the workflow has two active runs (BR4).
const WorkflowDeletionRejected activeRuns = WorkflowDeletionRejected(
  BackendFailure(
    'Workflow has 2 active runs.',
    code: ApiErrorCode.workflowHasActiveRuns,
    statusCode: 409,
    details: {'run-1': 'running', 'run-2': 'paused'},
  ),
);

/// In-memory [WorkflowRepository] for presentation tests. Each delete takes the
/// next scripted list of updates; without a script it returns a live stream
/// the test drives through [live].
final class ScriptedWorkflowRepository implements WorkflowRepository {
  /// Creates an empty repository.
  new();

  /// Timestamp of every seeded item.
  final DateTime now = DateTime.utc(2026, 11, 20, 12);

  /// Listed workflows.
  final List<WorkflowSummary> items = <WorkflowSummary>[];

  /// Every delete request, in call order.
  final List<({String id, String? workspaceId, String? revision, bool force})>
  deleteCalls = [];

  /// Scripted delete answers, consumed in call order.
  final List<List<WorkflowDeletionUpdate>> scripts = [];

  /// Live delete streams created without a script.
  final List<StreamController<WorkflowDeletionUpdate>> live = [];

  /// Ids of duplicated workflows.
  final List<String> duplicatedIds = <String>[];

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    String? workspaceId,
  }) async => Success(List<WorkflowSummary>.from(items));

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async {
    final wf = Workflow(
      id: 'wf-new',
      name: request.name,
      description: request.description,
      nodes: const <WorkflowNode>[],
      edges: const <WorkflowEdge>[],
      createdAt: now,
      updatedAt: now,
    );
    items.add(
      WorkflowSummary(
        id: wf.id,
        name: wf.name,
        description: wf.description,
        nodeCount: 0,
        edgeCount: 0,
        hasValidationErrors: true,
        updatedAt: now,
      ),
    );
    return Success(
      WorkflowResponse(
        workflow: wf,
        validation: const WorkflowValidationResult(isValid: false),
      ),
    );
  }

  /// Optional gate that pauses [duplicateWorkflow] until completed.
  Completer<void>? duplicateGate;

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) async {
    duplicatedIds.add(id);
    if (duplicateGate != null) {
      await duplicateGate!.future;
    }
    final source = items.firstWhere((w) => w.id == id);
    final copy = WorkflowSummary(
      id: '$id-copy',
      name: '${source.name} (Copy)',
      nodeCount: source.nodeCount,
      edgeCount: source.edgeCount,
      hasValidationErrors: source.hasValidationErrors,
      updatedAt: now,
    );
    items.add(copy);
    return Success(
      WorkflowResponse(
        workflow: Workflow(
          id: copy.id,
          name: copy.name,
          nodes: const <WorkflowNode>[],
          edges: const <WorkflowEdge>[],
          createdAt: now,
          updatedAt: now,
        ),
        validation: const WorkflowValidationResult(isValid: true),
      ),
    );
  }

  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    String? workspaceId,
    String? revision,
    bool force = false,
  }) {
    deleteCalls.add((
      id: id,
      workspaceId: workspaceId,
      revision: revision,
      force: force,
    ));
    if (scripts.isNotEmpty) {
      return Stream<WorkflowDeletionUpdate>.fromIterable(scripts.removeAt(0));
    }
    final controller = StreamController<WorkflowDeletionUpdate>();
    live.add(controller);
    return controller.stream;
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}
