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

    test('announces every new request on the requests stream', () async {
      final seen = <HumanPauseRequest>[];
      final subscription = gateway.requests.listen(seen.add);

      final answer = gateway.requestHumanAnswer(
        runId: 'run-1',
        nodeId: 'node-1',
        attempt: 2,
        question: 'Which database?',
      );

      expect(seen.single.nodeId, 'node-1');
      expect(seen.single.attempt, 2);
      gateway.cancelRun('run-1');
      await answer;
      await subscription.cancel();
    });

    test('announces a request on the answered stream once answered', () async {
      final answered = <HumanPauseRequest>[];
      final subscription = gateway.answered.listen(answered.add);
      final answer = gateway.requestHumanAnswer(
        runId: 'run-1',
        nodeId: 'node-1',
        attempt: 1,
        question: 'Which database?',
      );
      final pauseId = gateway.pendingForRun('run-1').single.pauseId;

      expect(answered, isEmpty);
      gateway.submitAnswer(pauseId: pauseId, answer: 'SQLite');

      expect(answered.single.pauseId, pauseId);
      expect((await answer).valueOrNull, 'SQLite');
      await subscription.cancel();
    });

    test('a cancelled request is not announced as answered', () async {
      final answered = <HumanPauseRequest>[];
      final subscription = gateway.answered.listen(answered.add);
      final answer = gateway.requestHumanAnswer(
        runId: 'run-1',
        nodeId: 'node-1',
        attempt: 1,
        question: 'Which database?',
      );

      gateway.cancelRun('run-1');
      await answer;

      expect(answered, isEmpty);
      await subscription.cancel();
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

    test(
      'cancelAttempt unblocks only pending questions for that specific attempt',
      () async {
        final targetFuture = gateway.requestHumanAnswer(
          runId: 'run-1',
          nodeId: 'node-a',
          attempt: 1,
          question: 'Attempt 1?',
        );
        final otherAttemptFuture = gateway.requestHumanAnswer(
          runId: 'run-1',
          nodeId: 'node-a',
          attempt: 2,
          question: 'Attempt 2?',
        );

        final cancelled = gateway.cancelAttempt(
          runId: 'run-1',
          nodeId: 'node-a',
          attempt: 1,
        );
        expect(cancelled, 1);
        expect((await targetFuture).failureOrNull, isA<ConflictFailure>());
        expect(gateway.pendingForRun('run-1'), hasLength(1));

        final pauseId = gateway.pendingForRun('run-1').single.pauseId;
        gateway.submitAnswer(pauseId: pauseId, answer: 'Proceed');
        expect((await otherAttemptFuture).valueOrNull, 'Proceed');
      },
    );

    test(
      'generates collision-free random pauseIds across instances and enforces '
      'runId/nodeId match on submitAnswer',
      () async {
        final secondGateway = InMemoryHumanPauseGateway();
        addTearDown(secondGateway.dispose);

        final f1 = gateway.requestHumanAnswer(
          runId: 'run-1',
          nodeId: 'node-a',
          attempt: 1,
          question: 'First process question?',
        );
        final f2 = secondGateway.requestHumanAnswer(
          runId: 'run-2',
          nodeId: 'node-b',
          attempt: 1,
          question: 'Restarted process question?',
        );

        final id1 = gateway.pendingForRun('run-1').single.pauseId;
        final id2 = secondGateway.pendingForRun('run-2').single.pauseId;
        expect(id1, isNot(equals(id2)));

        // Mismatched runId or nodeId must be rejected without consuming the
        // waiter.
        expect(
          gateway
              .submitAnswer(
                pauseId: id1,
                answer: 'wrong run',
                runId: 'run-other',
                nodeId: 'node-a',
              )
              .failureOrNull,
          isA<NotFoundFailure>(),
        );
        expect(
          gateway
              .submitAnswer(
                pauseId: id1,
                answer: 'wrong node',
                runId: 'run-1',
                nodeId: 'node-other',
              )
              .failureOrNull,
          isA<NotFoundFailure>(),
        );
        expect(gateway.pendingForRun('run-1'), hasLength(1));

        expect(
          gateway
              .submitAnswer(
                pauseId: id1,
                answer: 'correct',
                runId: 'run-1',
                nodeId: 'node-a',
              )
              .isSuccess,
          isTrue,
        );
        expect((await f1).valueOrNull, 'correct');

        secondGateway.cancelRun('run-2');
        await f2;
      },
    );
  });
}
