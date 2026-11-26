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

  group('GraphEngine dead-end summary', () {
    test('appends trimmed summary when no edge matches the output', () async {
      h.script.on('a', [
        outcome(
          NodeOutput.onFailure,
          data: const {'summary': '  PR #226 already closes #118  '},
        ),
      ]);

      final result = await startRun(
        buildWorkflow(
          nodeIds: ['a', 'b'],
          edges: [edge('a', NodeOutput.onSuccess, 'b')],
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.run.errorMessage, contains('no edge'));
      expect(
        h.run.errorMessage,
        contains('Summary: PR #226 already closes #118'),
      );
    });

    test('keeps exact message when summary is absent', () async {
      h.script.on('a', [outcome(NodeOutput.onFailure)]);

      final result = await startRun(
        buildWorkflow(
          nodeIds: ['a', 'b'],
          edges: [edge('a', NodeOutput.onSuccess, 'b')],
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(
        h.run.errorMessage,
        'Node "a" emitted "onFailure" but no edge leaves it for that output.',
      );
    });

    test('keeps exact message when summary is blank', () async {
      h.script.on('a', [
        outcome(NodeOutput.onFailure, data: const {'summary': '   '}),
      ]);

      final result = await startRun(
        buildWorkflow(
          nodeIds: ['a', 'b'],
          edges: [edge('a', NodeOutput.onSuccess, 'b')],
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(
        h.run.errorMessage,
        'Node "a" emitted "onFailure" but no edge leaves it for that output.',
      );
    });

    test('truncates summary to 500 characters with ellipsis', () async {
      final longSummary = 'x' * 2000;
      h.script.on('a', [
        outcome(NodeOutput.onFailure, data: {'summary': longSummary}),
      ]);

      final result = await startRun(
        buildWorkflow(
          nodeIds: ['a', 'b'],
          edges: [edge('a', NodeOutput.onSuccess, 'b')],
        ),
      );

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.run.errorMessage, contains('${'x' * 500}…'));
      expect(h.run.errorMessage, isNot(contains('x' * 501)));
    });

    test('appends summary when terminal node has no outgoing edges', () async {
      h.script.on('a', [
        outcome(NodeOutput.onFailure, data: const {'summary': 'boom summary'}),
      ]);

      final result = await startRun(
        buildWorkflow(nodeIds: ['a'], edges: const []),
      );

      expect(result.valueOrNull?.status, RunStatus.failed);
      expect(h.run.errorMessage, contains('boom summary'));
    });
  });
}
