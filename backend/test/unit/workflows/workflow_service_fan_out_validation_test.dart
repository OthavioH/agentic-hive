import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../mcp_tools/support/fakes.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final store = <String, Workflow>{};

  @override
  Future<Result<Workflow>> create(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (store.remove(id) == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Workflow>> getById(String id) async {
    final workflow = store[id];
    if (workflow == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return Success(workflow);
  }

  @override
  Future<Result<List<Workflow>>> listAll() async =>
      Success(store.values.toList());

  @override
  Future<Result<Workflow>> update(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }
}

Workflow _plainWorkflow(String id) {
  final now = DateTime.utc(2026);
  return Workflow(
    id: id,
    name: id,
    nodes: const [
      WorkflowNode(
        id: 'step',
        type: NodeTypeId.command,
        label: 'step',
        position: WorkflowPosition(x: 0, y: 0),
        config: {'command': 'echo'},
      ),
    ],
    edges: const [],
    entryNodeId: 'step',
    createdAt: now,
    updatedAt: now,
  );
}

Workflow _parentWorkflow({String id = 'parent', String childId = 'child'}) {
  final now = DateTime.utc(2026);
  return Workflow(
    id: id,
    name: id,
    nodes: [
      const WorkflowNode(
        id: 'plan',
        type: NodeTypeId.command,
        label: 'plan',
        position: WorkflowPosition(x: 0, y: 0),
        config: {'command': 'echo'},
      ),
      WorkflowNode(
        id: 'fan',
        type: NodeTypeId.fanOut,
        label: 'fan',
        position: const WorkflowPosition(x: 100, y: 0),
        config: {
          'workflowId': childId,
          'itemsNodeId': 'plan',
          'itemsPath': 'items',
        },
      ),
    ],
    edges: const [
      WorkflowEdge(
        id: 'e1',
        sourceNodeId: 'plan',
        sourceOutput: 'onSuccess',
        targetNodeId: 'fan',
      ),
    ],
    entryNodeId: 'plan',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late _FakeWorkflowRepository globalRepo;
  late MemoryWorkspaceWorkflows workspaceWorkflows;
  late MemoryWorkspaces workspaces;
  late WorkflowService service;

  setUp(() {
    globalRepo = _FakeWorkflowRepository();
    workspaceWorkflows = MemoryWorkspaceWorkflows();
    workspaces = MemoryWorkspaces([
      Workspace(
        id: 'ws-1',
        name: 'WS 1',
        rootPath: '/ws-1',
        isGit: false,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ]);
    service = WorkflowService(
      repository: globalRepo,
      validator: WorkflowValidator(),
      workspaceWorkflows: workspaceWorkflows,
      workspaces: workspaces,
    );
  });

  group('WorkflowService fan-out validation', () {
    test('global parent with an unresolved child reports a warning', () async {
      globalRepo.store['parent'] = _parentWorkflow();

      final result = await service.getWorkflow('parent');
      final response = result.valueOrNull!;

      expect(response.validation.isValid, isTrue);
      expect(
        response.validation.issues,
        contains(
          isA<WorkflowValidationIssue>()
              .having(
                (i) => i.code,
                'code',
                WorkflowValidationCode.unresolvedChildWorkflow,
              )
              .having(
                (i) => i.severity,
                'severity',
                WorkflowValidationSeverity.warning,
              )
              .having((i) => i.nodeId, 'nodeId', 'fan'),
        ),
      );
    });

    test('global parent with a resolvable child reports nothing', () async {
      globalRepo.store['parent'] = _parentWorkflow();
      globalRepo.store['child'] = _plainWorkflow('child');

      final result = await service.getWorkflow('parent');
      final response = result.valueOrNull!;

      expect(response.validation.isValid, isTrue);
      expect(
        response.validation.issues.where(
          (i) => i.code == WorkflowValidationCode.unresolvedChildWorkflow,
        ),
        isEmpty,
      );
    });

    test('child containing a fan-out node is an error', () async {
      globalRepo.store['parent'] = _parentWorkflow();
      globalRepo.store['child'] = _parentWorkflow(
        id: 'child',
        childId: 'grandchild',
      );

      final result = await service.getWorkflow('parent');
      final response = result.valueOrNull!;

      expect(response.validation.isValid, isFalse);
      expect(
        response.validation.issues,
        contains(
          isA<WorkflowValidationIssue>()
              .having((i) => i.code, 'code', WorkflowValidationCode.nestedFanOut)
              .having(
                (i) => i.severity,
                'severity',
                WorkflowValidationSeverity.error,
              ),
        ),
      );
    });

    test('workspace parent resolves the child in the workspace first', () async {
      await workspaceWorkflows.create('/ws-1', _parentWorkflow());
      await workspaceWorkflows.create('/ws-1', _plainWorkflow('child'));

      final result = await service.getWorkflow('parent', workspaceId: 'ws-1');
      final response = result.valueOrNull!;

      expect(response.validation.isValid, isTrue);
      expect(
        response.validation.issues.where(
          (i) => i.code == WorkflowValidationCode.unresolvedChildWorkflow,
        ),
        isEmpty,
      );
    });

    test('workspace parent falls back to the global child', () async {
      await workspaceWorkflows.create('/ws-1', _parentWorkflow());
      globalRepo.store['child'] = _plainWorkflow('child');

      final result = await service.getWorkflow('parent', workspaceId: 'ws-1');
      final response = result.valueOrNull!;

      expect(response.validation.isValid, isTrue);
      expect(
        response.validation.issues.where(
          (i) => i.code == WorkflowValidationCode.unresolvedChildWorkflow,
        ),
        isEmpty,
      );
    });

    test('global parent does not see a workspace-only child', () async {
      globalRepo.store['parent'] = _parentWorkflow();
      await workspaceWorkflows.create('/ws-1', _plainWorkflow('child'));

      final result = await service.getWorkflow('parent');
      final response = result.valueOrNull!;

      expect(
        response.validation.issues,
        contains(
          isA<WorkflowValidationIssue>().having(
            (i) => i.code,
            'code',
            WorkflowValidationCode.unresolvedChildWorkflow,
          ),
        ),
      );
    });

    test('createWorkflow response carries the issue', () async {
      final parent = _parentWorkflow();
      final result = await service.createWorkflow(
        CreateWorkflowRequest(
          name: parent.name,
          nodes: parent.nodes,
          edges: parent.edges,
          entryNodeId: parent.entryNodeId,
        ),
      );
      final response = result.valueOrNull!;

      expect(
        response.validation.issues,
        contains(
          isA<WorkflowValidationIssue>().having(
            (i) => i.code,
            'code',
            WorkflowValidationCode.unresolvedChildWorkflow,
          ),
        ),
      );
      final fetched = await service.getWorkflow(response.workflow.id);
      expect(fetched, isA<Success<WorkflowResponse>>());
    });

    test('updateWorkflow response carries the issue', () async {
      final parent = _parentWorkflow();
      globalRepo.store['parent'] = parent;

      final result = await service.updateWorkflow(
        'parent',
        UpdateWorkflowRequest(
          name: parent.name,
          nodes: parent.nodes,
          edges: parent.edges,
          entryNodeId: parent.entryNodeId,
        ),
      );
      final response = result.valueOrNull!;

      expect(
        response.validation.issues,
        contains(
          isA<WorkflowValidationIssue>().having(
            (i) => i.code,
            'code',
            WorkflowValidationCode.unresolvedChildWorkflow,
          ),
        ),
      );
    });

    test('listWorkflows summary is unchanged by fan-out issues', () async {
      globalRepo.store['parent'] = _parentWorkflow();
      globalRepo.store['child'] = _parentWorkflow(
        id: 'child',
        childId: 'grandchild',
      );

      final result = await service.listWorkflows();
      final summary = result.valueOrNull!.workflows.firstWhere(
        (s) => s.id == 'parent',
      );

      expect(summary.hasValidationErrors, isFalse);
    });
  });
}
