import 'package:agentic_hive_frontend/domain/runs/use_cases/build_run_output_messages.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 11, 21, 4, 30);

WorkflowNode _node(String id, String label) => WorkflowNode(
  id: id,
  type: 'command',
  label: label,
  position: const WorkflowPosition(x: 0, y: 0),
);

Checkpoint _checkpoint({
  required String id,
  required int sequence,
  required String? nodeId,
  Map<String, JsonMap>? outputs,
}) => Checkpoint(
  id: id,
  runId: 'run-1',
  sequence: sequence,
  completedNodeId: nodeId,
  pendingNodeIds: const <String>[],
  attemptsByEdge: const <String, int>{},
  circuitBreakerCount: 0,
  nodeOutputs: outputs ?? const <String, JsonMap>{},
  createdAt: _now,
);

Checkpoint _withSummary(String id, int sequence, String nodeId, Object? s) =>
    _checkpoint(
      id: id,
      sequence: sequence,
      nodeId: nodeId,
      outputs: <String, JsonMap>{
        nodeId: <String, Object?>{
          'data': <String, Object?>{'summary': s},
        },
      },
    );

void main() {
  const useCase = BuildRunOutputMessages();
  final nodes = <WorkflowNode>[_node('a', 'Plan'), _node('b', 'Build')];

  test('orders messages by checkpoint sequence', () {
    final messages = useCase(
      checkpoints: <Checkpoint>[
        _withSummary('cp-2', 2, 'b', 'built'),
        _withSummary('cp-1', 1, 'a', 'planned'),
      ],
      nodes: nodes,
    );

    expect(messages.map((m) => m.checkpointId), <String>['cp-1', 'cp-2']);
    expect(messages.map((m) => m.nodeLabel), <String>['Plan', 'Build']);
    expect(messages.map((m) => m.text), <String>['planned', 'built']);
  });

  test('skips nodes without a usable summary', () {
    final messages = useCase(
      checkpoints: <Checkpoint>[
        _checkpoint(id: 'cp-1', sequence: 1, nodeId: null),
        _checkpoint(id: 'cp-2', sequence: 2, nodeId: 'a'),
        _checkpoint(
          id: 'cp-3',
          sequence: 3,
          nodeId: 'a',
          outputs: <String, JsonMap>{
            'a': <String, Object?>{'prepared': true},
          },
        ),
        _withSummary('cp-4', 4, 'a', '   \n'),
        _withSummary('cp-5', 5, 'a', 42),
        _withSummary('cp-6', 6, 'b', 'kept'),
      ],
      nodes: nodes,
    );

    expect(messages.map((m) => m.checkpointId), <String>['cp-6']);
  });

  test('trims text, falls back to node id and emits no raw JSON', () {
    final messages = useCase(
      checkpoints: <Checkpoint>[_withSummary('cp-1', 1, 'ghost', '  hello  ')],
      nodes: nodes,
    );

    expect(messages.single.nodeLabel, 'ghost');
    expect(messages.single.text, 'hello');
    expect(messages.single.text, isNot(contains('{')));
    expect(messages.single.text, isNot(contains('summary')));
  });

  test('returns an empty list without checkpoints', () {
    expect(useCase(checkpoints: const <Checkpoint>[], nodes: nodes), isEmpty);
  });
}
