import 'dart:convert';

import 'package:agentic_hive_backend/src/api/workflows/workflow_handler.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final _store = <String, Workflow>{};

  @override
  Future<Result<Workflow>> create(Workflow workflow) async {
    _store[workflow.id] = workflow;
    return Success(workflow);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (_store.remove(id) == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Workflow>> getById(String id) async {
    final wf = _store[id];
    if (wf == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return Success(wf);
  }

  @override
  Future<Result<List<Workflow>>> listAll() async =>
      Success(_store.values.toList());

  @override
  Future<Result<Workflow>> update(Workflow workflow) async {
    _store[workflow.id] = workflow;
    return Success(workflow);
  }
}

final class _FakeWorkspaceRepository implements WorkspaceRepository {
  final store = <String, Workspace>{};

  @override
  Future<Result<Workspace>> getById(String id) async {
    final w = store[id];
    return w == null
        ? FailureResult(NotFoundFailure('Workspace "$id" not found.'))
        : Success(w);
  }

  @override
  Future<Result<List<Workspace>>> list() async =>
      Success(store.values.toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final class _FakeWorkspaceWorkflowRepository
    implements WorkspaceWorkflowRepository {
  final store = <String, Map<String, Workflow>>{};

  @override
  Future<Result<Workflow>> getById(String workspacePath, String id) async {
    final w = store[workspacePath]?[id];
    return w == null
        ? FailureResult(NotFoundFailure('Workflow "$id" not found.'))
        : Success(w);
  }

  @override
  Future<Result<List<Workflow>>> listAll(String workspacePath) async =>
      Success(store[workspacePath]?.values.toList() ?? const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Workflow _plainWorkflow(String id, String name) => Workflow(
  id: id,
  name: name,
  nodes: const [
    WorkflowNode(
      id: 'n1',
      type: 'harness',
      label: 'Step',
      position: WorkflowPosition(x: 0, y: 0),
    ),
  ],
  edges: const [],
  entryNodeId: 'n1',
  createdAt: DateTime.utc(2026, 11, 23, 10),
  updatedAt: DateTime.utc(2026, 11, 23, 10),
);

Workflow _fanOutWorkflow(String id, String name, String targetId) => Workflow(
  id: id,
  name: name,
  nodes: [
    WorkflowNode(
      id: 'fan-1',
      type: NodeTypeId.fanOut,
      label: 'Fan-out',
      position: const WorkflowPosition(x: 0, y: 0),
      config: {'workflowId': targetId},
    ),
  ],
  edges: const [],
  entryNodeId: 'fan-1',
  createdAt: DateTime.utc(2026, 11, 23, 10),
  updatedAt: DateTime.utc(2026, 11, 23, 10),
);

void main() {
  late _FakeWorkflowRepository workflows;
  late _FakeWorkspaceRepository workspaces;
  late _FakeWorkspaceWorkflowRepository wsWorkflows;
  late WorkflowHandler handler;

  setUp(() {
    workflows = _FakeWorkflowRepository();
    workspaces = _FakeWorkspaceRepository();
    wsWorkflows = _FakeWorkspaceWorkflowRepository();
    final service = WorkflowService(
      repository: workflows,
      validator: const WorkflowValidator(),
      workspaces: workspaces,
      workspaceWorkflows: wsWorkflows,
      generateId: () => 'op-1',
      now: () => DateTime.utc(2026, 11, 23, 10),
    );
    handler = WorkflowHandler(service: service);
  });

  test('GET /<id>/references answers 200 with the references json', () async {
    await workflows.create(_plainWorkflow('wf-child', 'Child'));
    await workflows.create(_fanOutWorkflow('wf-parent', 'Parent', 'wf-child'));

    final res = await handler(
      Request('GET', Uri.parse('http://localhost/wf-child/references')),
    );
    expect(res.statusCode, 200);
    final decoded = WorkflowReferencesResponse.fromJson(
      jsonDecode(await res.readAsString()) as JsonMap,
    );
    expect(decoded.references, [
      const WorkflowReference(
        workflowId: 'wf-parent',
        workflowName: 'Parent',
        nodeIds: ['fan-1'],
      ),
    ]);
  });

  test(
    'GET /<id>/references?workspaceId=... answers for a workspace workflow',
    () async {
      workspaces.store['ws-1'] = Workspace(
        id: 'ws-1',
        name: 'WS1',
        rootPath: '/tmp/ws-1',
        isGit: false,
        createdAt: DateTime.utc(2026, 11, 23, 10),
        updatedAt: DateTime.utc(2026, 11, 23, 10),
      );
      wsWorkflows.store['/tmp/ws-1'] = {
        'wf-child': _plainWorkflow('wf-child', 'Child'),
        'wf-ws-parent': _fanOutWorkflow('wf-ws-parent', 'WsParent', 'wf-child'),
      };

      final res = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/wf-child/references?workspaceId=ws-1'),
        ),
      );
      expect(res.statusCode, 200);
      final decoded = WorkflowReferencesResponse.fromJson(
        jsonDecode(await res.readAsString()) as JsonMap,
      );
      expect(decoded.references.map((r) => r.workflowId), ['wf-ws-parent']);
    },
  );

  test('GET /<id>/references answers 404 for an unknown workflow', () async {
    final res = await handler(
      Request('GET', Uri.parse('http://localhost/missing/references')),
    );
    expect(res.statusCode, 404);
  });

  test('DELETE /<id> answers 202 with a references array', () async {
    await workflows.create(_plainWorkflow('wf-child', 'Child'));
    await workflows.create(_fanOutWorkflow('wf-parent', 'Parent', 'wf-child'));

    final res = await handler(
      Request('DELETE', Uri.parse('http://localhost/wf-child')),
    );
    expect(res.statusCode, 202);
    final decoded = WorkflowDeletionAccepted.fromJson(
      jsonDecode(await res.readAsString()) as JsonMap,
    );
    expect(decoded.references, hasLength(1));
    expect(decoded.references.first.workflowId, 'wf-parent');
  });
}
