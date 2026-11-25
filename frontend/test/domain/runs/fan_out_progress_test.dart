import 'package:agentic_hive_frontend/domain/runs/fan_out_progress.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _baseTime = DateTime.utc(2026, 11, 21, 10);

Workflow _minimalWorkflow() => Workflow(
  id: 'wf-child',
  name: 'Child Workflow',
  nodes: const <WorkflowNode>[],
  edges: const <WorkflowEdge>[],
  createdAt: _baseTime,
  updatedAt: _baseTime,
);

Run _childRun({
  required String id,
  required int index,
  RunStatus status = RunStatus.running,
  String parentNodeId = 'fan',
  String? childName,
  DateTime? startedAt,
  String? errorMessage,
}) => Run(
  id: id,
  workflowId: 'wf-child',
  workflowName: 'Child Workflow',
  workflowDefinition: _minimalWorkflow(),
  workspacePath: '/tmp/ws',
  status: status,
  startedAt: startedAt ?? _baseTime,
  parentRunId: 'parent-1',
  parentNodeId: parentNodeId,
  childIndex: index,
  childName: childName,
  errorMessage: errorMessage,
);

void main() {
  group('FanOutProgress', () {
    test('live children make items, ordered by index', () {
      final children = <Run>[
        _childRun(id: 'r2', index: 2, childName: 'Two'),
        _childRun(id: 'r0', index: 0, childName: 'Zero'),
        _childRun(id: 'r1', index: 1, childName: 'One'),
      ];

      final progress = FanOutProgress.of(
        nodeId: 'fan',
        children: children,
        nodeOutputEntry: null,
      );

      expect(progress.items.map((i) => i.index).toList(), <int>[0, 1, 2]);
      expect(progress.items.map((i) => i.name).toList(), <String>[
        'Zero',
        'One',
        'Two',
      ]);
      expect(progress.items.map((i) => i.runId).toList(), <String?>[
        'r0',
        'r1',
        'r2',
      ]);
    });

    test('children of another node are ignored', () {
      final progress = FanOutProgress.of(
        nodeId: 'fan',
        children: <Run>[_childRun(id: 'r0', index: 0, parentNodeId: 'other')],
        nodeOutputEntry: null,
      );

      expect(progress.isEmpty, isTrue);
    });

    test('retry: the latest startedAt per index is current', () {
      final progress = FanOutProgress.of(
        nodeId: 'fan',
        children: <Run>[
          _childRun(
            id: 'r-old',
            index: 0,
            status: RunStatus.failed,
            startedAt: _baseTime,
          ),
          _childRun(
            id: 'r-new',
            index: 0,
            startedAt: DateTime.utc(2026, 11, 21, 10, 1),
          ),
        ],
        nodeOutputEntry: null,
      );

      expect(progress.total, 1);
      expect(progress.items.single.status, RunStatus.running);
      expect(progress.items.single.runId, 'r-new');
    });

    test('counts final, failed, needsHuman, and non-final interrupted', () {
      final progress = FanOutProgress.of(
        nodeId: 'fan',
        children: <Run>[
          _childRun(id: 'r0', index: 0, status: RunStatus.succeeded),
          _childRun(id: 'r1', index: 1, status: RunStatus.failed),
          _childRun(id: 'r2', index: 2, status: RunStatus.cancelled),
          _childRun(id: 'r3', index: 3),
          _childRun(id: 'r4', index: 4, status: RunStatus.paused),
          _childRun(id: 'r5', index: 5, status: RunStatus.interrupted),
        ],
        nodeOutputEntry: null,
      );

      expect(progress.total, 6);
      expect(progress.done, 3);
      expect(progress.failed, 2);
      expect(progress.needsHuman, 1);
      expect(progress.items[5].isFinal, isFalse);
    });

    test('output entry without a live child: runId set means deleted', () {
      final progress = FanOutProgress.of(
        nodeId: 'fan',
        children: const <Run>[],
        nodeOutputEntry: const <String, Object?>{
          'data': <String, Object?>{
            'total': 1,
            'children': <Object?>[
              <String, Object?>{
                'index': 0,
                'name': 'a',
                'status': 'succeeded',
                'runId': 'r1',
              },
            ],
          },
        },
      );

      expect(progress.total, 1);
      final item = progress.items.single;
      expect(item.deleted, isTrue);
      expect(item.isFinal, isTrue);
      expect(item.isOpenable, isFalse);
      expect(item.isFailure, isFalse);
    });

    test('output entry without a runId is a not-started failure', () {
      final progress = FanOutProgress.of(
        nodeId: 'fan',
        children: const <Run>[],
        nodeOutputEntry: const <String, Object?>{
          'data': <String, Object?>{
            'total': 1,
            'children': <Object?>[
              <String, Object?>{
                'index': 0,
                'name': 'a',
                'status': 'failed',
                'runId': null,
                'error': 'x',
              },
            ],
          },
        },
      );

      expect(progress.total, 1);
      final item = progress.items.single;
      expect(item.deleted, isFalse);
      expect(item.isFailure, isTrue);
      expect(item.isOpenable, isFalse);
      expect(item.error, 'x');
    });

    test('a live child wins over the output entry of the same index', () {
      final progress = FanOutProgress.of(
        nodeId: 'fan',
        children: <Run>[
          _childRun(id: 'r-live', index: 0, childName: 'Live Name'),
        ],
        nodeOutputEntry: const <String, Object?>{
          'data': <String, Object?>{
            'total': 1,
            'children': <Object?>[
              <String, Object?>{
                'index': 0,
                'name': 'Old Name',
                'status': 'failed',
                'runId': 'r-old',
              },
            ],
          },
        },
      );

      expect(progress.total, 1);
      final item = progress.items.single;
      expect(item.runId, 'r-live');
      expect(item.name, 'Live Name');
      expect(item.status, RunStatus.running);
      expect(item.deleted, isFalse);
    });

    test('empty output sets emptyList', () {
      final progress = FanOutProgress.of(
        nodeId: 'fan',
        children: const <Run>[],
        nodeOutputEntry: const <String, Object?>{
          'data': <String, Object?>{'total': 0, 'children': <Object?>[]},
        },
      );

      expect(progress.emptyList, isTrue);
      expect(progress.isEmpty, isTrue);
    });

    test('malformed output is ignored', () {
      for (final bad in const <Object?>[
        'x',
        <String, Object?>{'data': 3},
        <String, Object?>{
          'data': <String, Object?>{'children': 5},
        },
        <String, Object?>{
          'data': <String, Object?>{
            'children': <Object?>[
              'x',
              <String, Object?>{'index': 'a'},
            ],
          },
        },
      ]) {
        final progress = FanOutProgress.of(
          nodeId: 'fan',
          children: const <Run>[],
          nodeOutputEntry: bad,
        );
        expect(progress.isEmpty, isTrue);
      }
    });

    test('unknown output status falls back to failed', () {
      final progress = FanOutProgress.of(
        nodeId: 'fan',
        children: const <Run>[],
        nodeOutputEntry: const <String, Object?>{
          'data': <String, Object?>{
            'total': 1,
            'children': <Object?>[
              <String, Object?>{
                'index': 0,
                'name': 'a',
                'status': 'mystery',
                'runId': null,
              },
            ],
          },
        },
      );

      expect(progress.items.single.status, RunStatus.failed);
      expect(progress.items.single.isFailure, isTrue);
    });
  });
}
