import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryHumanPauseGateway', () {
    late InMemoryHumanPauseGateway gateway;

    setUp(() {
      gateway = InMemoryHumanPauseGateway();
    });

    tearDown(() {
      gateway.dispose();
    });

    test('blocks until human submits answer by pauseId', () async {
      final answerFuture = gateway.requestHumanAnswer(
        runId: 'run-1',
        nodeId: 'node-1',
        attempt: 1,
        question: 'Which database?',
        options: const <String>['SQLite', 'Postgres'],
      );

      final pending = gateway.pendingForRun('run-1');
      expect(pending, hasLength(1));
      expect(pending.single.question, 'Which database?');
      expect(pending.single.options, const <String>['SQLite', 'Postgres']);

      final submit = gateway.submitAnswer(
        pauseId: pending.single.pauseId,
        answer: 'SQLite',
      );
      expect(submit.isSuccess, isTrue);

      final result = await answerFuture;
      expect(result.valueOrNull, 'SQLite');
      expect(gateway.pendingForRun('run-1'), isEmpty);
    });

    test(
      'supports multiple concurrent questions resolved independently',
      () async {
        final f1 = gateway.requestHumanAnswer(
          runId: 'run-1',
          nodeId: 'node-a',
          attempt: 1,
          question: 'Question A?',
        );
        final f2 = gateway.requestHumanAnswer(
          runId: 'run-1',
          nodeId: 'node-b',
          attempt: 1,
          question: 'Question B?',
        );

        final pending = gateway.allPending;
        expect(pending, hasLength(2));

        final pauseA = pending.firstWhere((p) => p.nodeId == 'node-a').pauseId;
        final pauseB = pending.firstWhere((p) => p.nodeId == 'node-b').pauseId;

        gateway
          ..submitAnswer(pauseId: pauseB, answer: 'Answer B')
          ..submitAnswer(pauseId: pauseA, answer: 'Answer A');

        expect((await f1).valueOrNull, 'Answer A');
        expect((await f2).valueOrNull, 'Answer B');
      },
    );

    test(
      'cancelRun unblocks all pending questions for that run only',
      () async {
        final run1FutureA = gateway.requestHumanAnswer(
          runId: 'run-1',
          nodeId: 'node-a',
          attempt: 1,
          question: 'Q1?',
        );
        final run1FutureB = gateway.requestHumanAnswer(
          runId: 'run-1',
          nodeId: 'node-b',
          attempt: 1,
          question: 'Q2?',
        );
        final run2Future = gateway.requestHumanAnswer(
          runId: 'run-2',
          nodeId: 'node-c',
          attempt: 1,
          question: 'Q3?',
        );

        final cancelledCount = gateway.cancelRun('run-1');
        expect(cancelledCount, 2);

        final resA = await run1FutureA;
        final resB = await run1FutureB;
        expect(resA.failureOrNull, isA<ConflictFailure>());
        expect(resB.failureOrNull, isA<ConflictFailure>());
        expect(gateway.pendingForRun('run-1'), isEmpty);
        expect(gateway.pendingForRun('run-2'), hasLength(1));

        final run2PauseId = gateway.pendingForRun('run-2').single.pauseId;
        gateway.submitAnswer(pauseId: run2PauseId, answer: 'Still alive');
        expect((await run2Future).valueOrNull, 'Still alive');
      },
    );

    test('rejects blank question and unknown pauseId', () async {
      final blankResult = await gateway.requestHumanAnswer(
        runId: 'run-1',
        nodeId: 'node-1',
        attempt: 1,
        question: '   ',
      );
      expect(blankResult.failureOrNull, isA<ValidationFailure>());

      final unknownSubmit = gateway.submitAnswer(
        pauseId: 'missing-id',
        answer: 'yes',
      );
      expect(unknownSubmit.failureOrNull, isA<NotFoundFailure>());
    });
  });
}
