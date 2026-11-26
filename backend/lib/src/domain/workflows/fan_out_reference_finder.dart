import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Finds the workflows whose fan-out nodes reference a workflow (ADR 0029).
final class FanOutReferenceFinder {
  /// Creates a finder. Without [workspaceWorkflows] and [workspaces] only the
  /// global scope is scanned.
  const new({
    required this.repository,
    this.workspaceWorkflows,
    this.workspaces,
  });

  /// Global workflow repository.
  final WorkflowRepository repository;

  /// Workspace-scoped workflow repository.
  final WorkspaceWorkflowRepository? workspaceWorkflows;

  /// Registered workspaces repository.
  final WorkspaceRepository? workspaces;

  /// References to workflow [workflowId] in [scope], sorted by name (R13-R15).
  Future<Result<List<WorkflowReference>>> find(
    String workflowId, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final candidates = <({Workflow workflow, DefinitionScope scope})>[];

    final globalsResult = await repository.listAll();
    if (globalsResult case FailureResult<List<Workflow>>(:final failure)) {
      return FailureResult(failure);
    }
    for (final w in globalsResult.valueOrNull!) {
      if (w.id == workflowId && scope is GlobalScope) continue;
      candidates.add((workflow: w, scope: const GlobalScope()));
    }

    final wsRepo = workspaces;
    final wsWorkflowsRepo = workspaceWorkflows;
    if (wsRepo != null && wsWorkflowsRepo != null) {
      final workspacesToScan = <Workspace>[];
      switch (scope) {
        case WorkspaceScope(:final workspaceId):
          final wsResult = await wsRepo.getById(workspaceId);
          if (wsResult case FailureResult<Workspace>(:final failure)) {
            return FailureResult(failure);
          }
          workspacesToScan.add(wsResult.valueOrNull!);
        case GlobalScope():
          final listResult = await wsRepo.list();
          if (listResult case FailureResult<List<Workspace>>(:final failure)) {
            return FailureResult(failure);
          }
          for (final ws in listResult.valueOrNull!) {
            final shadowCheck = await wsWorkflowsRepo.getById(
              ws.rootPath,
              workflowId,
            );
            if (shadowCheck is Success<Workflow>) continue;
            workspacesToScan.add(ws);
          }
      }

      for (final ws in workspacesToScan) {
        final wsListResult = await wsWorkflowsRepo.listAll(ws.rootPath);
        if (wsListResult case FailureResult<List<Workflow>>(:final failure)) {
          return FailureResult(failure);
        }
        for (final w in wsListResult.valueOrNull!) {
          if (w.id == workflowId && scope.workspaceIdOrNull == ws.id) {
            continue;
          }
          candidates.add((workflow: w, scope: WorkspaceScope(ws.id)));
        }
      }
    }

    final refs = <WorkflowReference>[];
    for (final c in candidates) {
      final nodeIds = [
        for (final n in c.workflow.nodes)
          if (n.type == NodeTypeId.fanOut && _workflowIdOf(n) == workflowId)
            n.id,
      ]..sort();
      if (nodeIds.isNotEmpty) {
        refs.add(
          WorkflowReference(
            workflowId: c.workflow.id,
            workflowName: c.workflow.name,
            scope: c.scope,
            nodeIds: nodeIds,
          ),
        );
      }
    }

    refs.sort((a, b) {
      final byName = a.workflowName.toLowerCase().compareTo(
        b.workflowName.toLowerCase(),
      );
      if (byName != 0) return byName;
      final byScope = switch ((a.scope, b.scope)) {
        (GlobalScope(), WorkspaceScope()) => -1,
        (WorkspaceScope(), GlobalScope()) => 1,
        (
          WorkspaceScope(workspaceId: final aWs),
          WorkspaceScope(workspaceId: final bWs),
        ) =>
          aWs.compareTo(bWs),
        (GlobalScope(), GlobalScope()) => 0,
      };
      if (byScope != 0) return byScope;
      return a.workflowId.compareTo(b.workflowId);
    });

    return Success(refs);
  }

  static String? _workflowIdOf(WorkflowNode node) {
    final raw = node.config['workflowId'];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
