import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';
import 'support/fake_ports.dart';

void main() {
  late EngineHarness h;

  setUp(() => h = EngineHarness());

  Future<Result<Run>> startRun(Workflow workflow) async {
    await h.createRun(workflow);
    return await h.engine.start(runId);
  }

  group('GraphEngine routing', () {
    test('runs a linear workflow from the entry node to success', () async {
      final result = await startRun(
        buildWorkflow(
          nodeIds: ['a', 'b', 'c'],
          edges: [
            edge('a', NodeOutput.onSuccess, 'b'),
            edge('b', NodeOutput.onSuccess, 'c'),
          ],
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.startOrder, ['a', 'b', 'c']);
      expect(h.run.status, RunStatus.succeeded);
      expect(h.run.finishedAt, isNotNull);
      expect(h.eventTypes.first, RunEventType.runStarted);
      expect(h.eventTypes.last, RunEventType.runSucceeded);
    });

    test('starts at entryNodeId, not at the first listed node', () async {
      await startRun(
        buildWorkflow(
          nodeIds: ['a', 'b'],
          entry: 'b',
          edges: [edge('a', NodeOutput.onSuccess, 'b')],
        ),
      );

      expect(h.script.startOrder, ['b']);
    });

    test('follows only the edge matching the emitted outputLabel', () async {
      h.script.on('a', [outcome(NodeOutput.onFailure)]);

      final result = await startRun(
        buildWorkflow(
          nodeIds: ['a', 'ok', 'fix'],
          edges: [
            edge('a', NodeOutput.onSuccess, 'ok'),
            edge('a', NodeOutput.onFailure, 'fix'),
          ],
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.startOrder, ['a', 'fix']);
    });

    test('routes custom labels such as changesRequested', () async {
      h.script.on('review', [outcome(NodeOutput.changesRequested)]);

      await startRun(
        buildWorkflow(
          nodeIds: ['review', 'rework', 'ship'],
          edges: [
            edge('review', NodeOutput.approved, 'ship'),
            edge('review', NodeOutput.changesRequested, 'rework'),
          ],
        ),
      );

      expect(h.script.startOrder, ['review', 'rework']);
    });

    test('a terminal node emitting approved ends its branch cleanly', () async {
      h.script.on('a', [outcome(NodeOutput.approved)]);

      final result = await startRun(
        buildWorkflow(nodeIds: ['a'], edges: const []),
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
    });

    test('a terminal node emitting onFailure fails the run', () async {
      h.script.on('a', [outcome(NodeOutput.onFailure)]);

      final result = await startRun(
        buildWorkflow(nodeIds: ['a'], edges: const []),
      );

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.eventTypes.last, RunEventType.runFailed);
      expect(h.run.errorMessage, contains('onFailure'));
    });

    for (final label in [NodeOutput.rejected, NodeOutput.changesRequested]) {
      test('a terminal node emitting $label fails the run', () async {
        h.script.on('a', [outcome(label)]);

        final result = await startRun(
          buildWorkflow(nodeIds: ['a'], edges: const []),
        );

        expect(result.valueOrNull?.status, RunStatus.failed);
      });
    }

    test(
      'an outcome without a matching edge fails when others exist',
      () async {
        h.script.on('a', [outcome(NodeOutput.onFailure)]);

        final result = await startRun(
          buildWorkflow(
            nodeIds: ['a', 'b'],
            edges: [edge('a', NodeOutput.onSuccess, 'b')],
          ),
        );

        expect(result.valueOrNull?.status, RunStatus.failed);
        expect(h.script.startOrder, ['a']);
        expect(h.run.errorMessage, contains('no edge'));
      },
    );

    test('fails the run when the workflow has no entry node', () async {
      final result = await startRun(
        buildWorkflow(nodeIds: ['a'], edges: const [], noEntry: true),
      );

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.run.errorMessage, contains('entry'));
      expect(h.script.executions, isEmpty);
    });

    test('fails the run when a node type is not registered', () async {
      final workflow = buildWorkflow(nodeIds: ['a'], edges: const []);
      final unknown = workflow.copyWith(
        nodes: [workflow.nodes.single.copyWith(type: 'does.not.exist')],
      );

      final result = await startRun(unknown);

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.run.errorMessage, contains('does.not.exist'));
    });

    test('rejects starting a run that is not running', () async {
      await h.createRun(
        buildWorkflow(nodeIds: ['a'], edges: const []),
        status: RunStatus.paused,
      );

      final result = await h.engine.start(runId);

      expect(result.failureOrNull, isA<ConflictFailure>());
      expect(h.script.executions, isEmpty);
    });

    test('rejects starting a run that already has checkpoints', () async {
      final workflow = buildWorkflow(nodeIds: ['a'], edges: const []);
      await startRun(workflow);
      await h.runs.updateStatus(runId, status: RunStatus.running);

      final again = await h.engine.start(runId);

      expect(again.failureOrNull, isA<ConflictFailure>());
    });

    test('rejects a concurrent start of the same run', () async {
      final workflow = buildWorkflow(nodeIds: ['a'], edges: const []);
      await h.createRun(workflow);

      final first = h.engine.start(runId);
      final second = await h.engine.start(runId);
      await first;

      expect(second.failureOrNull, isA<ConflictFailure>());
    });

    test('returns NotFoundFailure for an unknown run', () async {
      final result = await h.engine.start('missing');

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('GraphEngine node context and persistence', () {
    test('accumulates nodeOutputs and passes immediate predecessors', () async {
      h.script
        ..on('a', [
          outcome(NodeOutput.onSuccess, data: {'plan': 'x'}),
        ])
        ..on('b', [
          outcome(NodeOutput.onSuccess, data: {'code': 'y'}),
        ]);

      await startRun(
        buildWorkflow(
          nodeIds: ['a', 'b', 'c'],
          edges: [
            edge('a', NodeOutput.onSuccess, 'b'),
            edge('b', NodeOutput.onSuccess, 'c'),
          ],
        ),
      );

      final inputs = h.script.executions.last.inputs;
      final outputs = inputs['nodeOutputs']! as Map<String, Object?>;
      expect(outputs.keys, containsAll(['a', 'b']));
      expect((outputs['a']! as Map)['data'], {'plan': 'x'});
      final predecessors = inputs['predecessors']! as Map<String, Object?>;
      expect(predecessors.keys, ['b']);
    });

    test(
      'predecessors come from this traversal, not a previous loop',
      () async {
        h.script
          ..on('p', [
            outcome(NodeOutput.onSuccess, data: {'round': 1}),
            outcome(NodeOutput.onSuccess, data: {'round': 2}),
          ])
          ..on('x', [
            outcome(NodeOutput.onFailure),
            outcome(NodeOutput.onSuccess),
          ]);

        await startRun(
          buildWorkflow(
            nodeIds: ['start', 'p', 'q', 'x', 'done'],
            edges: [
              edge('start', NodeOutput.onSuccess, 'p'),
              edge('start', NodeOutput.onSuccess, 'q'),
              edge('p', NodeOutput.onSuccess, 'x'),
              edge('q', NodeOutput.onSuccess, 'x'),
              edge('x', NodeOutput.onFailure, 'p', maxRetries: 2),
              edge('x', NodeOutput.onSuccess, 'done'),
            ],
          ),
        );

        final runs = h.script.executions.where((c) => c.nodeId == 'x').toList();
        expect(runs, hasLength(2));
        final first = runs[0].inputs['predecessors']! as Map<String, Object?>;
        final second = runs[1].inputs['predecessors']! as Map<String, Object?>;
        expect(first.keys, unorderedEquals(['p', 'q']));
        // q did not run again in the second loop: it must not appear as a
        // predecessor of that traversal.
        expect(second.keys, ['p']);
        expect(((second['p']! as Map)['data']! as Map)['round'], 2);
      },
    );

    test('passes the declared outputs, config and attempt number', () async {
      await startRun(buildWorkflow(nodeIds: ['a'], edges: const []));

      final context = h.script.executions.single;
      expect(context.runId, runId);
      expect(context.nodeId, 'a');
      expect(context.attempt, 1);
      expect(context.workspacePath, '/workspace');
      expect(context.availableOutputs, contains(NodeOutput.onSuccess));
    });

    test('uses the worktree path as workspace when isolated', () async {
      final workflow = buildWorkflow(nodeIds: ['a'], edges: const []);
      await h.createRun(workflow);
      h.runs.runs[runId] = h.run.copyWith(
        isolationMode: WorkspaceIsolationMode.worktree,
        worktreePath: '/worktree',
      );

      await h.engine.start(runId);

      expect(h.script.executions.single.workspacePath, '/worktree');
    });

    test('saves a checkpoint and checkpoint.saved after every node', () async {
      h.script.on('a', [
        outcome(NodeOutput.onSuccess, data: {'k': 1}),
      ]);

      await startRun(
        buildWorkflow(
          nodeIds: ['a', 'b'],
          edges: [edge('a', NodeOutput.onSuccess, 'b')],
        ),
      );

      final checkpoints = h.checkpoints.checkpoints;
      expect(checkpoints.map((c) => c.completedNodeId), ['a', 'b']);
      expect(checkpoints.first.pendingNodeIds, ['b']);
      expect(checkpoints.first.nodeOutputs['a']!['outputLabel'], 'onSuccess');
      expect(checkpoints.last.pendingNodeIds, isEmpty);
      expect(
        h.events.ofType(runId, RunEventType.checkpointSaved),
        hasLength(2),
      );
    });

    test('emits node.started and node.completed per node in order', () async {
      await startRun(
        buildWorkflow(
          nodeIds: ['a', 'b'],
          edges: [edge('a', NodeOutput.onSuccess, 'b')],
        ),
      );

      expect(
        h.eventTypes.where(
          (t) =>
              t == RunEventType.nodeStarted || t == RunEventType.nodeCompleted,
        ),
        [
          RunEventType.nodeStarted,
          RunEventType.nodeCompleted,
          RunEventType.nodeStarted,
          RunEventType.nodeCompleted,
        ],
      );
    });

    test('snapshots the workspace before each node', () async {
      await startRun(
        buildWorkflow(
          nodeIds: ['a', 'b'],
          edges: [edge('a', NodeOutput.onSuccess, 'b')],
        ),
      );

      expect(h.snapshots.captured, ['a', 'b']);
      expect(h.snapshots.restored, isEmpty);
    });

    test('continues without a snapshot and warns when capture fails', () async {
      h.snapshots.captureFailure = const NodeExecutionFailure('git missing');

      final result = await startRun(
        buildWorkflow(nodeIds: ['a'], edges: const []),
      );

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(
        h.events.ofType(runId, RunEventType.snapshotWarning),
        hasLength(1),
      );
    });

    test(
      'passes run.input only to the entry node, never to later nodes',
      () async {
        final workflow = buildWorkflow(
          nodeIds: ['a', 'b', 'c'],
          entry: 'b',
          edges: [edge('b', NodeOutput.onSuccess, 'c')],
        );
        await h.createRun(workflow, input: 'Audit auth middleware');

        final result = await h.engine.start(runId);

        expect(result.valueOrNull?.status, RunStatus.succeeded);
        expect(h.script.startOrder, ['b', 'c']);
        final entryCtx = h.script.executions.firstWhere((c) => c.nodeId == 'b');
        final nextCtx = h.script.executions.firstWhere((c) => c.nodeId == 'c');
        expect(entryCtx.runInput, 'Audit auth middleware');
        expect(nextCtx.runInput, isNull);
      },
    );

    test('passes runAttachments to every node (entry and non-entry) and empty '
        'when none', () async {
      final workflow = buildWorkflow(
        nodeIds: ['a', 'b'],
        entry: 'a',
        edges: [edge('a', NodeOutput.onSuccess, 'b')],
      );
      await h.createRun(
        workflow,
        attachments: const [
          RunAttachment(
            fileName: 'shot.png',
            mimeType: 'image/png',
            sizeBytes: 10,
          ),
          RunAttachment(
            fileName: 'photo.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 20,
          ),
        ],
      );

      final result = await h.engine.start(runId);

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      final entryCtx = h.script.executions.firstWhere((c) => c.nodeId == 'a');
      final nextCtx = h.script.executions.firstWhere((c) => c.nodeId == 'b');
      for (final ctx in [entryCtx, nextCtx]) {
        expect(ctx.runAttachments, hasLength(2));
        expect(ctx.runAttachments[0].path, '/runs/$runId/attachments/1.png');
        expect(ctx.runAttachments[0].fileName, 'shot.png');
        expect(ctx.runAttachments[1].path, '/runs/$runId/attachments/2.jpg');
        expect(ctx.runAttachments[1].fileName, 'photo.jpg');
      }
    });

    test('passes empty runAttachments when run has none', () async {
      final workflow = buildWorkflow(
        nodeIds: ['a'],
        entry: 'a',
        edges: const [],
      );
      await h.createRun(workflow);

      final result = await h.engine.start(runId);

      expect(result.valueOrNull?.status, RunStatus.succeeded);
      expect(h.script.executions.single.runAttachments, isEmpty);
    });
  });
}
