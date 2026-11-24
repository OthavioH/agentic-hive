import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';

void main() {
  test('passes the workflow node label to the node context', () async {
    final h = EngineHarness();
    h.script.on('a', [
      (_) async => const Success(NodeOutcome(outputLabel: NodeOutput.onSuccess)),
    ]);
    final base = buildWorkflow(nodeIds: const ['a'], edges: const []);
    final workflow = base.copyWith(
      nodes: [base.nodes.single.copyWith(label: 'My label')],
    );
    await h.createRun(workflow, status: RunStatus.running);

    await h.engine.start('run-1');

    expect(h.script.executions.single.nodeLabel, 'My label');
  });
}
