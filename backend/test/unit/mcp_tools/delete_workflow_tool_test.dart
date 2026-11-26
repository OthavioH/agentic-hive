import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/delete_workflow_tool.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_registry.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_revision.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_runs_deleter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fakes.dart';

final class _Events implements WorkflowEvents {
  final calls =
      <
        (
          WorkflowChangeKind kind,
          String id,
          String? workspaceId,
          WorkflowSummary? summary,
        )
      >[];

  @override
  void workflowChanged(
    WorkflowChangeKind kind,
    String id, {
    DefinitionScope scope = const GlobalScope(),
    WorkflowSummary? workflow,
  }) {
    calls.add((kind, id, scope.workspaceIdOrNull, workflow));
  }
}

const _globalHeader = 'Scope: Global (from the workspace argument)';

String _bodyOf(Result<String> result) => (result as Success<String>).value;

Failure _failureOf(Result<String> result) =>
    (result as FailureResult<String>).failure;

void main() {
  late MemoryWorkflows global;
  late MemoryWorkspaceWorkflows workspaceFiles;
  late MemoryWorkspaces workspaces;
  late WorkflowService service;
  late WorkflowDeletionRegistry deletions;
  late GatedRunsDeleter deleter;
  late _Events events;
  late DeleteWorkflowTool tool;
  var counter = 0;
  final workspace = Workspace(
    id: 'ws-1',
    name: 'App',
    rootPath: hostTestPath('repos', 'app'),
    isGit: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  Workflow fixture([String id = 'review-loop']) => Workflow(
    id: id,
    name: 'Review loop',
    nodes: const [
      WorkflowNode(
        id: 'plan',
        type: NodeTypeId.claudeCode,
        label: 'Plan',
        position: WorkflowPosition(x: 120, y: 120),
        config: {'agentId': 'planner'},
      ),
      WorkflowNode(
        id: 'review',
        type: NodeTypeId.reviewValidator,
        label: 'Review',
        position: WorkflowPosition(x: 440, y: 120),
        config: {
          'harnessType': NodeTypeId.claudeCode,
          'reviewCriteria': 'correctness',
        },
      ),
    ],
    edges: const [
      WorkflowEdge(
        id: 'edge_1',
        sourceNodeId: 'plan',
        sourceOutput: NodeOutput.onSuccess,
        targetNodeId: 'review',
      ),
      WorkflowEdge(
        id: 'edge_2',
        sourceNodeId: 'review',
        sourceOutput: NodeOutput.changesRequested,
        targetNodeId: 'plan',
        maxRetries: 2,
      ),
    ],
    entryNodeId: 'plan',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  String revisionOf(Workflow w) => workflowRevision(w);

  DeleteWorkflowTool buildTool({
    Duration maxWait = const Duration(milliseconds: 200),
  }) => DeleteWorkflowTool(
    scopes: McpScopeResolver(
      workspaces: workspaces,
      worktreesDir: hostTestPath('data', 'worktrees'),
      path: p.context,
    ),
    workflows: service,
    events: events,
    maxWait: maxWait,
    pollInterval: const Duration(milliseconds: 10),
  );

  Future<Result<String>> call(Map<String, Object?> args) =>
      tool.call(McpToolInput(arguments: {'workspace': 'global', ...args}));

  setUp(() {
    global = MemoryWorkflows();
    workspaceFiles = MemoryWorkspaceWorkflows();
    workspaces = MemoryWorkspaces([workspace]);
    deletions = WorkflowDeletionRegistry();
    deleter = GatedRunsDeleter();
    counter = 0;
    service = WorkflowService(
      repository: global,
      validator: const WorkflowValidator(),
      workspaceWorkflows: workspaceFiles,
      workspaces: workspaces,
      runsDeleter: deleter,
      deletions: deletions,
      generateId: () => 'op-${++counter}',
    );
    events = _Events();
    global.store['review-loop'] = fixture();
    tool = buildTool();
  });

  tearDown(() async {
    final gate = deleter.gate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
    await pumpEventQueue();
  });

  test('the tool name is delete_workflow', () {
    expect(tool.name, 'delete_workflow');
  });

  test('R6 R7 deletes the workflow and reports the deleted runs', () async {
    deleter.outcome = const Success(WorkflowRunsDeletion(deletedRuns: 3));

    final result = await call({
      'id': 'review-loop',
      'revision': revisionOf(fixture()),
    });

    expect(
      _bodyOf(result),
      '$_globalHeader\nDeleted workflow "review-loop" and 3 runs '
      '(operation op-1).',
    );
    expect(global.store.containsKey('review-loop'), isFalse);
  });

  test('R11 one deleted run is singular', () async {
    deleter.outcome = const Success(WorkflowRunsDeletion(deletedRuns: 1));

    final result = await call({
      'id': 'review-loop',
      'revision': revisionOf(fixture()),
    });

    expect(_bodyOf(result), endsWith('and 1 run (operation op-1).'));
  });

  test('R7 orphaned runs are reported on a second line', () async {
    deleter.outcome = const Success(
      WorkflowRunsDeletion(deletedRuns: 2, orphanedRuns: ['r8', 'r9']),
    );

    final result = await call({
      'id': 'review-loop',
      'revision': revisionOf(fixture()),
    });

    final lines = _bodyOf(result).split('\n');
    expect(lines, hasLength(3));
    expect(
      lines[2],
      'Kept 2 runs that could not be confirmed as stopped: r8, r9. The user '
      'can retry their cancel in Agentic Hive.',
    );
  });

  test('R5 never forces', () async {
    await call({'id': 'review-loop', 'revision': revisionOf(fixture())});

    expect(deleter.forceCalls, [false]);
  });

  test(
    'R1 R5 a force argument is ignored and active runs still refuse',
    () async {
      deleter.activeRuns = {'r1': RunStatus.running};

      final result = await call({
        'id': 'review-loop',
        'revision': revisionOf(fixture()),
        'force': true,
      });

      expect(_failureOf(result), isA<WorkflowHasActiveRunsFailure>());
      expect(global.store.containsKey('review-loop'), isTrue);
      expect(deleter.forceCalls, isEmpty);
    },
  );

  test('R3 active runs are refused, listed, and nothing is deleted', () async {
    deleter.activeRuns = {'r1': RunStatus.running, 'r2': RunStatus.paused};

    final failure = _failureOf(
      await call({'id': 'review-loop', 'revision': revisionOf(fixture())}),
    ) as WorkflowHasActiveRunsFailure;

    expect(failure.activeRuns, {
      'r1': RunStatus.running,
      'r2': RunStatus.paused,
    });
    expect(
      failure.message,
      'Workflow "review-loop" has 2 active runs: r1 (running), r2 (paused). '
      'Ask the user to stop them in Agentic Hive, then call delete_workflow '
      'again. Nothing was deleted.',
    );
    expect(global.store.containsKey('review-loop'), isTrue);
    expect(deletions.runningFor('review-loop'), isNull);
    expect(events.calls, isEmpty);
  });

  test('R3 one active run is singular', () async {
    deleter.activeRuns = {'r1': RunStatus.running};

    final failure = _failureOf(
      await call({'id': 'review-loop', 'revision': revisionOf(fixture())}),
    ) as WorkflowHasActiveRunsFailure;

    expect(
      failure.message,
      startsWith('Workflow "review-loop" has 1 active run: r1 (running).'),
    );
  });

  test(
    'R4 a stale revision is refused and tells the model to re-read',
    () async {
      final current = revisionOf(fixture());

      final failure = _failureOf(
        await call({'id': 'review-loop', 'revision': 'stale'}),
      ) as StaleRevisionFailure;

      expect(failure.currentRevision, current);
      expect(
        failure.message,
        'Workflow "review-loop" changed since you read it (you sent revision '
        'stale, it is now $current). Call get_workflow to read it again, check '
        'it is still the one to delete, then call delete_workflow with the new '
        'revision. Nothing was deleted.',
      );
      expect(global.store.containsKey('review-loop'), isTrue);
      expect(events.calls, isEmpty);
    },
  );

  test('R4 a stale revision wins over active runs', () async {
    deleter.activeRuns = {'r1': RunStatus.running};

    final failure = _failureOf(
      await call({'id': 'review-loop', 'revision': 'stale'}),
    );

    expect(failure, isA<StaleRevisionFailure>());
  });

  test(
    'R6 a slow deletion answers deletion in progress with the operation id',
    () async {
      deleter.gate = Completer<void>();

      final result = await call({
        'id': 'review-loop',
        'revision': revisionOf(fixture()),
      });

      expect(
        _bodyOf(result),
        '$_globalHeader\nWorkflow "review-loop": deletion in progress '
        '(operation op-1). It finishes on its own; call delete_workflow again '
        'with the same id to wait for the result.',
      );
      expect(global.store.containsKey('review-loop'), isTrue);
      expect(events.calls, isEmpty);
    },
  );

  test(
    'R9 a slow deletion still announces the delete when it finishes',
    () async {
      deleter.gate = Completer<void>();
      await call({'id': 'review-loop', 'revision': revisionOf(fixture())});

      deleter.gate!.complete();
      await service.whenDeletionFinished('op-1')!;
      await pumpEventQueue();

      expect(events.calls, [
        (WorkflowChangeKind.deleted, 'review-loop', null, null),
      ]);
    },
  );

  test('R6 the wait ends as soon as the operation finishes', () async {
    tool = buildTool(maxWait: const Duration(seconds: 5));
    deleter.gate = Completer<void>();
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 50),
        () => deleter.gate!.complete(),
      ),
    );

    final watch = Stopwatch()..start();
    final result = await call({
      'id': 'review-loop',
      'revision': revisionOf(fixture()),
    });
    watch.stop();

    expect(_bodyOf(result), endsWith('and 0 runs (operation op-1).'));
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test(
    'R6 R7 an operation evicted before its answer says the result is gone',
    () async {
      // op-1 runs and stays blocked while the tool polls it.
      final gate = Completer<void>();
      deleter.gate = gate;
      final pending = call({
        'id': 'review-loop',
        'revision': revisionOf(fixture()),
      });
      await pumpEventQueue();

      // Finish 50 other deletions while op-1 is still running; the registry
      // only evicts finished operations, so op-1 survives this churn.
      deleter.gate = null;
      for (var i = 1; i <= 50; i++) {
        global.store['churn-$i'] = fixture('churn-$i');
        await service.deleteWorkflow('churn-$i');
        await service.whenDeletionFinished('op-${i + 1}')!;
      }

      // Finish op-1, then one more finished deletion pushes the registry past
      // its cap: op-1, the oldest finished operation, is evicted. All of this
      // runs on microtasks, so the tool's timer-based poll cannot observe
      // op-1 finished before it is evicted.
      gate.complete();
      await service.whenDeletionFinished('op-1')!;
      global.store['churn-51'] = fixture('churn-51');
      await service.deleteWorkflow('churn-51');
      await service.whenDeletionFinished('op-52')!;
      expect(service.getDeletion('op-1').valueOrNull, isNull);

      final result = await pending;

      expect(
        _bodyOf(result),
        '$_globalHeader\nWorkflow "review-loop": deletion finished '
        '(operation op-1) but its result is no longer available. Call '
        'list_workflows to confirm it is gone.',
      );
      expect(events.calls, [
        (WorkflowChangeKind.deleted, 'review-loop', null, null),
      ]);
    },
  );

  test(
    'R8 R2 a repeated call while the deletion runs joins the same operation',
    () async {
      final gate = Completer<void>();
      deleter.gate = gate;
      final first = await call({
        'id': 'review-loop',
        'revision': revisionOf(fixture()),
      });
      final second = await call({
        'id': 'review-loop',
        'revision': revisionOf(fixture()),
      });

      expect(_bodyOf(first), contains('(operation op-1)'));
      expect(
        _bodyOf(second),
        contains('deletion in progress (operation op-1)'),
      );
      expect(counter, 1);
      gate.complete();
      await service.whenDeletionFinished('op-1')!;
    },
  );

  test('R8 a repeated call after the delete answers already deleted', () async {
    await call({'id': 'review-loop', 'revision': revisionOf(fixture())});

    final result = await call({
      'id': 'review-loop',
      'revision': revisionOf(fixture()),
    });

    expect(
      _bodyOf(result),
      '$_globalHeader\nWorkflow "review-loop" is already deleted: it is not in '
      'the Global scope. Nothing to do. If it should exist, check the id and '
      'workspace with list_workflows.',
    );
    expect(events.calls, hasLength(1));
  });

  test('R8 an unknown id answers already deleted', () async {
    final result = await call({'id': 'missing', 'revision': 'r'});

    expect(
      _bodyOf(result),
      '$_globalHeader\nWorkflow "missing" is already deleted: it is not in the '
      'Global scope. Nothing to do. If it should exist, check the id and '
      'workspace with list_workflows.',
    );
  });

  test('R7 a failed operation is an error and keeps the workflow', () async {
    deleter.outcome = const FailureResult<WorkflowRunsDeletion>(
      PersistenceFailure('db'),
    );

    final failure = _failureOf(
      await call({'id': 'review-loop', 'revision': revisionOf(fixture())}),
    );

    expect(failure, isA<ConflictFailure>());
    expect(
      failure.message,
      'Deleting workflow "review-loop" failed (operation op-1) after deleting '
      '0 runs. The workflow was not deleted. Tell the user to check the '
      'Workflows page in Agentic Hive before you try again.',
    );
    expect(failure.message, isNot(contains('db')));
    expect(global.store.containsKey('review-loop'), isTrue);
    expect(events.calls, isEmpty);
  });

  test('R1 missing id', () async {
    final failure = _failureOf(await call({'revision': 'r'}));

    expect(failure, isA<ValidationFailure>());
    expect(
      failure.message,
      'Missing "id": pass a workflow id from list_workflows.',
    );
  });

  test('R1 missing revision', () async {
    final failure = _failureOf(await call({'id': 'review-loop'}));

    expect(failure, isA<ValidationFailure>());
    expect(
      failure.message,
      'Missing "revision": pass the revision from your last get_workflow or '
      'list_workflows.',
    );
  });

  test('R1 a blank revision counts as missing', () async {
    final failure = _failureOf(
      await call({'id': 'review-loop', 'revision': '  '}),
    );

    expect(
      failure.message,
      'Missing "revision": pass the revision from your last get_workflow or '
      'list_workflows.',
    );
  });

  test('R1 revision not a string', () async {
    final failure = _failureOf(
      await call({'id': 'review-loop', 'revision': 3}),
    );

    expect(failure, isA<ValidationFailure>());
    expect(failure.message, '"revision" must be a string.');
  });

  test('R10 a workspace workflow is deleted from its workspace', () async {
    workspaceFiles.byRoot[workspace.rootPath] = {'review-loop': fixture()};

    final result = await tool.call(
      McpToolInput(
        arguments: {
          'workspace': 'ws-1',
          'id': 'review-loop',
          'revision': revisionOf(fixture()),
        },
      ),
    );

    final lines = _bodyOf(result).split('\n');
    expect(lines.first, startsWith('Scope: workspace "App"'));
    expect(lines.last, endsWith('and 0 runs (operation op-1).'));
    expect(
      workspaceFiles.byRoot[workspace.rootPath]!.containsKey('review-loop'),
      isFalse,
    );
    await pumpEventQueue();
    expect(events.calls, [
      (WorkflowChangeKind.deleted, 'review-loop', 'ws-1', null),
    ]);
  });

  group('fan-out references', () {
    Workflow childWorkflow() => fixture().copyWith(id: 'child', name: 'Child');

    Workflow referencingWorkflow({
      String id = 'planner',
      String name = 'Planner',
      List<String> nodeIds = const ['fan'],
    }) {
      final now = DateTime.utc(2026);
      return Workflow(
        id: id,
        name: name,
        nodes: [
          for (final nodeId in nodeIds)
            WorkflowNode(
              id: nodeId,
              type: NodeTypeId.fanOut,
              label: nodeId,
              position: const WorkflowPosition(x: 0, y: 0),
              config: const {
                'workflowId': 'child',
                'itemsNodeId': 'plan',
                'itemsPath': 'items',
              },
            ),
        ],
        edges: const [],
        entryNodeId: nodeIds.first,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('lists referencing workflows after the delete', () async {
      global.store['child'] = childWorkflow();
      global.store['planner'] = referencingWorkflow();

      final result = await call({
        'id': 'child',
        'revision': revisionOf(childWorkflow()),
      });

      final body = _bodyOf(result);
      expect(body, contains('Deleted workflow "child"'));
      expect(
        body,
        contains(
          'Used by fan-out nodes in 1 workflow: "Planner" (id planner, global, '
          'nodes: fan).',
        ),
      );
    });

    test(
      'lists a workspace referencing workflow with its workspace id',
      () async {
        global.store['child'] = childWorkflow();
        workspaceFiles.byRoot[workspace.rootPath] = {
          'planner': referencingWorkflow(),
        };

        final result = await call({
          'id': 'child',
          'revision': revisionOf(childWorkflow()),
        });

        expect(_bodyOf(result), contains('workspace ws-1'));
      },
    );

    test('lists several nodes of one workflow joined by comma', () async {
      global.store['child'] = childWorkflow();
      global.store['planner'] = referencingWorkflow(nodeIds: ['b', 'a']);

      final result = await call({
        'id': 'child',
        'revision': revisionOf(childWorkflow()),
      });

      expect(_bodyOf(result), contains('nodes: a, b'));
    });

    test('no references appends nothing', () async {
      final result = await call({
        'id': 'review-loop',
        'revision': revisionOf(fixture()),
      });

      expect(_bodyOf(result), isNot(contains('fan-out')));
    });

    test('in progress answer also lists the references', () async {
      global.store['child'] = childWorkflow();
      global.store['planner'] = referencingWorkflow();
      deleter.gate = Completer<void>();
      addTearDown(() {
        if (!deleter.gate!.isCompleted) deleter.gate!.complete();
      });

      final slowTool = DeleteWorkflowTool(
        workflows: service,
        scopes: McpScopeResolver(
          workspaces: workspaces,
          worktreesDir: '/worktrees',
          path: p.context,
        ),
        events: events,
        maxWait: const Duration(milliseconds: 5),
        pollInterval: const Duration(milliseconds: 1),
      );

      final result = await slowTool.call(
        McpToolInput(
          arguments: {'id': 'child', 'revision': revisionOf(childWorkflow())},
        ),
      );

      final body = _bodyOf(result);
      expect(body, contains('deletion in progress'));
      expect(body, contains('Used by fan-out nodes in'));
    });

    test('refusal on active runs does not list references', () async {
      global.store['child'] = childWorkflow();
      global.store['planner'] = referencingWorkflow();
      deleter.activeRuns = {'r1': RunStatus.running};

      final failure = _failureOf(
        await call({'id': 'child', 'revision': revisionOf(childWorkflow())}),
      ) as WorkflowHasActiveRunsFailure;

      expect(failure.message, isNot(contains('Used by fan-out')));
    });
  });
}
