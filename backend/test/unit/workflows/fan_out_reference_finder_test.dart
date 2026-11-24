import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/fan_out_reference_finder.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final Map<String, Workflow> store = {};
  Failure? failOnListAll;

  @override
  Future<Result<List<Workflow>>> listAll() async {
    if (failOnListAll != null) return FailureResult(failOnListAll!);
    return Success(store.values.toList());
  }

  @override
  Future<Result<Workflow>> getById(String id) async {
    final w = store[id];
    return w == null
        ? FailureResult(NotFoundFailure('Workflow "$id" not found.'))
        : Success(w);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final class _FakeWorkspaceRepository implements WorkspaceRepository {
  final Map<String, Workspace> store = {};

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
  final Map<String, Map<String, Workflow>> store = {};

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

Workflow _fanOutWorkflow(
  String id,
  String name,
  Object? childId, {
  List<String> nodeIds = const ['fan-1'],
}) => Workflow(
  id: id,
  name: name,
  nodes: [
    for (final nodeId in nodeIds)
      WorkflowNode(
        id: nodeId,
        type: NodeTypeId.fanOut,
        label: 'Fan-out',
        position: const WorkflowPosition(x: 0, y: 0),
        config: {if (childId != null) 'workflowId': childId},
      ),
  ],
  edges: const [],
  entryNodeId: nodeIds.first,
  createdAt: DateTime.utc(2026, 11, 20),
  updatedAt: DateTime.utc(2026, 11, 20),
);

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
  createdAt: DateTime.utc(2026, 11, 20),
  updatedAt: DateTime.utc(2026, 11, 20),
);

Workspace _ws(String id) => Workspace(
  id: id,
  name: id,
  rootPath: '/tmp/$id',
  isGit: false,
  createdAt: DateTime.utc(2026, 11, 20),
  updatedAt: DateTime.utc(2026, 11, 20),
);

void main() {
  late _FakeWorkflowRepository globals;
  late _FakeWorkspaceRepository workspaces;
  late _FakeWorkspaceWorkflowRepository wsWorkflows;
  late FanOutReferenceFinder finder;

  setUp(() {
    globals = _FakeWorkflowRepository();
    workspaces = _FakeWorkspaceRepository();
    wsWorkflows = _FakeWorkspaceWorkflowRepository();
    finder = FanOutReferenceFinder(
      repository: globals,
      workspaces: workspaces,
      workspaceWorkflows: wsWorkflows,
    );
  });

  test(
    'global workflow referencing X is listed with its fan-out node ids sorted',
    () async {
      globals.store['wf-x'] = _plainWorkflow('wf-x', 'X');
      globals.store['wf-p'] = _fanOutWorkflow(
        'wf-p',
        'Parent',
        ' wf-x ',
        nodeIds: const ['fan-b', 'fan-a'],
      );

      final res = await finder.find('wf-x');
      expect(res.valueOrNull, [
        const WorkflowReference(
          workflowId: 'wf-p',
          workflowName: 'Parent',
          scope: WorkflowScope.global,
          nodeIds: ['fan-a', 'fan-b'],
        ),
      ]);
    },
  );

  test(
    'workflows without a fan-out node or referencing another workflow are not listed',
    () async {
      globals.store['wf-x'] = _plainWorkflow('wf-x', 'X');
      globals.store['wf-plain'] = _plainWorkflow('wf-plain', 'Plain');
      globals.store['wf-other'] = _fanOutWorkflow('wf-other', 'Other', 'wf-y');

      final res = await finder.find('wf-x');
      expect(res.valueOrNull, isEmpty);
    },
  );

  test('blank or non-string workflowId config is ignored', () async {
    globals.store['wf-x'] = _plainWorkflow('wf-x', 'X');
    globals.store['wf-blank'] = _fanOutWorkflow('wf-blank', 'Blank', '   ');
    globals.store['wf-int'] = _fanOutWorkflow('wf-int', 'Int', 42);
    globals.store['wf-null'] = _fanOutWorkflow('wf-null', 'Null', null);

    final res = await finder.find('wf-x');
    expect(res.valueOrNull, isEmpty);
  });

  test('the workflow itself is not listed', () async {
    globals.store['wf-x'] = _fanOutWorkflow('wf-x', 'X', 'wf-x');

    final res = await finder.find('wf-x');
    expect(res.valueOrNull, isEmpty);
  });

  test(
    'deleting a workspace workflow scans that workspace and the global scope, not other workspaces',
    () async {
      workspaces.store['ws-1'] = _ws('ws-1');
      workspaces.store['ws-2'] = _ws('ws-2');
      globals.store['wf-g'] = _fanOutWorkflow('wf-g', 'GlobalRef', 'wf-x');
      wsWorkflows.store['/tmp/ws-1'] = {
        'wf-x': _plainWorkflow('wf-x', 'X'),
        'wf-w1': _fanOutWorkflow('wf-w1', 'Ws1Ref', 'wf-x'),
      };
      wsWorkflows.store['/tmp/ws-2'] = {
        'wf-w2': _fanOutWorkflow('wf-w2', 'Ws2Ref', 'wf-x'),
      };

      final res = await finder.find('wf-x', workspaceId: 'ws-1');
      expect(res.valueOrNull!.map((r) => r.workflowId), ['wf-g', 'wf-w1']);
    },
  );

  test(
    'deleting a global workflow scans global and every workspace',
    () async {
      workspaces.store['ws-1'] = _ws('ws-1');
      globals.store['wf-x'] = _plainWorkflow('wf-x', 'X');
      globals.store['wf-g'] = _fanOutWorkflow('wf-g', 'GlobalRef', 'wf-x');
      wsWorkflows.store['/tmp/ws-1'] = {
        'wf-w1': _fanOutWorkflow('wf-w1', 'Ws1Ref', 'wf-x'),
      };

      final res = await finder.find('wf-x');
      expect(res.valueOrNull!.map((r) => r.workflowId), ['wf-g', 'wf-w1']);
    },
  );

  test(
    'a workspace with its own copy of X is skipped when deleting the global X',
    () async {
      workspaces.store['ws-1'] = _ws('ws-1');
      globals.store['wf-x'] = _plainWorkflow('wf-x', 'X');
      wsWorkflows.store['/tmp/ws-1'] = {
        'wf-x': _plainWorkflow('wf-x', 'Local X'),
        'wf-w1': _fanOutWorkflow('wf-w1', 'Ws1Ref', 'wf-x'),
      };

      final res = await finder.find('wf-x');
      expect(res.valueOrNull, isEmpty);
    },
  );

  test('references are sorted by name, then workspace, then id', () async {
    workspaces.store['ws-a'] = _ws('ws-a');
    workspaces.store['ws-b'] = _ws('ws-b');
    globals.store['wf-g2'] = _fanOutWorkflow('wf-g2', 'alpha', 'wf-x');
    globals.store['wf-g1'] = _fanOutWorkflow('wf-g1', 'Alpha', 'wf-x');
    wsWorkflows.store['/tmp/ws-b'] = {
      'wf-b': _fanOutWorkflow('wf-b', 'Alpha', 'wf-x'),
    };
    wsWorkflows.store['/tmp/ws-a'] = {
      'wf-a': _fanOutWorkflow('wf-a', 'Alpha', 'wf-x'),
    };

    final res = await finder.find('wf-x');
    expect(res.valueOrNull!.map((r) => '${r.workflowId}@${r.workspaceId}'), [
      'wf-g1@null',
      'wf-g2@null',
      'wf-a@ws-a',
      'wf-b@ws-b',
    ]);
  });

  test('a failing repository list returns the failure', () async {
    globals.failOnListAll = const PersistenceFailure('db error');

    final res = await finder.find('wf-x');
    expect(res.failureOrNull, isA<PersistenceFailure>());
  });
}
