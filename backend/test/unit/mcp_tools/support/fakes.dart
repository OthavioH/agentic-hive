import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

final class MemoryWorkflows implements WorkflowRepository {
  final store = <String, Workflow>{};

  @override
  Future<Result<Workflow>> create(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }

  @override
  Future<Result<void>> delete(String id) async => store.remove(id) == null
      ? FailureResult(NotFoundFailure('Workflow "$id" not found.'))
      : const Success<void>(null);

  @override
  Future<Result<Workflow>> getById(String id) async => store[id] == null
      ? FailureResult(NotFoundFailure('Workflow "$id" not found.'))
      : Success(store[id]!);

  @override
  Future<Result<List<Workflow>>> listAll() async =>
      Success(store.values.toList());

  @override
  Future<Result<Workflow>> update(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }
}

final class MemoryWorkspaceWorkflows implements WorkspaceWorkflowRepository {
  final byRoot = <String, Map<String, Workflow>>{};
  final failingRoots = <String>{};

  @override
  Future<Result<List<Workflow>>> listAll(String workspaceRoot) async {
    if (failingRoots.contains(workspaceRoot)) {
      return const FailureResult(PersistenceFailure('disk error'));
    }
    final map = byRoot[workspaceRoot] ?? const <String, Workflow>{};
    return Success(map.values.toList());
  }

  @override
  Future<Result<Workflow>> getById(String workspaceRoot, String id) async {
    if (failingRoots.contains(workspaceRoot)) {
      return const FailureResult(PersistenceFailure('disk error'));
    }
    final wf = byRoot[workspaceRoot]?[id];
    return wf == null
        ? FailureResult(NotFoundFailure('Workflow "$id" not found.'))
        : Success(wf);
  }

  @override
  Future<Result<Workflow>> create(
    String workspaceRoot,
    Workflow workflow,
  ) async {
    byRoot.putIfAbsent(workspaceRoot, () => <String, Workflow>{})[workflow.id] =
        workflow;
    return Success(workflow);
  }

  @override
  Future<Result<Workflow>> update(
    String workspaceRoot,
    Workflow workflow,
  ) async {
    byRoot.putIfAbsent(workspaceRoot, () => <String, Workflow>{})[workflow.id] =
        workflow;
    return Success(workflow);
  }

  @override
  Future<Result<void>> delete(String workspaceRoot, String id) async =>
      (byRoot[workspaceRoot]?.remove(id) == null)
      ? FailureResult(NotFoundFailure('Workflow "$id" not found.'))
      : const Success<void>(null);
}

final class MemoryWorkspaces implements WorkspaceRepository {
  new([List<Workspace>? items]) : _items = items ?? <Workspace>[];

  final List<Workspace> _items;

  @override
  Future<Result<List<Workspace>>> list() async => Success(_items);

  @override
  Future<Result<Workspace>> getById(String id) async {
    for (final ws in _items) {
      if (ws.id == id) {
        return Success(ws);
      }
    }
    return FailureResult(NotFoundFailure('Workspace "$id" not found.'));
  }

  @override
  Future<Result<Workspace>> create(Workspace workspace) async {
    _items.add(workspace);
    return Success(workspace);
  }

  @override
  Future<Result<void>> delete(String id) async {
    _items.removeWhere((ws) => ws.id == id);
    return const Success<void>(null);
  }

  @override
  Future<Result<Workspace>> rename(
    String id, {
    required String name,
    required DateTime updatedAt,
  }) async => throw UnimplementedError();
}
