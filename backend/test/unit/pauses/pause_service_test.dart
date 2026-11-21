import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_service.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  late _FakePauseRepository repo;
  late InMemoryHumanPauseGateway gateway;
  late List<(String runId, ResumeInput input)> resumedCalls;
  late PauseService service;

  setUp(() {
    repo = _FakePauseRepository();
    gateway = InMemoryHumanPauseGateway();
    resumedCalls = <(String, ResumeInput)>[];
    service = PauseService(
      pauses: repo,
      pauseGateway: gateway,
      resumePausedRun: (runId, {required input}) async {
        resumedCalls.add((runId, input));
        return Success(
          Run(
            id: runId,
            workflowName: 'Flow',
            workflowDefinition: Workflow(
              id: 'wf-1',
              name: 'Flow',
              nodes: const [],
              edges: const [],
              createdAt: DateTime.utc(2026, 11, 21),
              updatedAt: DateTime.utc(2026, 11, 21),
            ),
            workspacePath: '/tmp/ws',
            status: RunStatus.running,
            startedAt: DateTime.utc(2026, 11, 21),
          ),
        );
      },
      now: () => DateTime.utc(2026, 11, 21, 12),
    );
  });

  tearDown(() {
    gateway.dispose();
  });

  group('PauseService', () {
    test('answers humanApproval pause and resumes GraphEngine', () async {
      await repo.create(
        Pause(
          id: 'p-app',
          runId: 'r-1',
          nodeId: 'gate',
          kind: PauseKind.humanApproval,
          status: PauseStatus.pending,
          workflowName: 'Flow',
          nodeLabel: 'Gate',
          instructions: 'Approve?',
          createdAt: DateTime.utc(2026, 11, 21, 11),
        ),
      );

      final result = await service.answerPause(
        'p-app',
        const AnswerPauseRequest(decision: 'approved', feedback: 'Looks good'),
      );
      expect(result.isSuccess, isTrue);
      final updated = result.valueOrNull!;
      expect(updated.status, PauseStatus.answered);
      expect(updated.decision, 'approved');
      expect(updated.feedback, 'Looks good');
      expect(resumedCalls, hasLength(1));
      expect(resumedCalls.single.$1, 'r-1');
      final input = resumedCalls.single.$2 as ApprovalDecisionInput;
      expect(input.nodeId, 'gate');
      expect(input.decision, HumanApprovalDecision.approved);
      expect(input.feedback, 'Looks good');
    });

    test(
      'rejects invalid decision or disallowed feedback on humanApproval',
      () async {
        await repo.create(
          Pause(
            id: 'p-app',
            runId: 'r-1',
            nodeId: 'gate',
            kind: PauseKind.humanApproval,
            status: PauseStatus.pending,
            workflowName: 'Flow',
            nodeLabel: 'Gate',
            allowFeedback: false,
            createdAt: DateTime.utc(2026, 11, 21, 11),
          ),
        );

        final badDecision = await service.answerPause(
          'p-app',
          const AnswerPauseRequest(decision: 'maybe'),
        );
        expect(badDecision.failureOrNull, isA<ValidationFailure>());

        final disallowedFeedback = await service.answerPause(
          'p-app',
          const AnswerPauseRequest(decision: 'approved', feedback: 'extra'),
        );
        expect(disallowedFeedback.failureOrNull, isA<ValidationFailure>());
      },
    );

    test(
      'unblocks live ask_human waiter without calling resumePausedRun',
      () async {
        final answerFuture = gateway.requestHumanAnswer(
          runId: 'r-live',
          nodeId: 'agent',
          attempt: 1,
          question: 'Which port?',
        );
        final req = gateway.allPending.single;

        await repo.create(
          Pause(
            id: req.pauseId,
            runId: 'r-live',
            nodeId: 'agent',
            kind: PauseKind.askHuman,
            status: PauseStatus.pending,
            workflowName: 'Flow',
            nodeLabel: 'Agent',
            question: req.question,
            createdAt: req.createdAt,
          ),
        );

        final result = await service.answerPause(
          req.pauseId,
          const AnswerPauseRequest(answer: '8080'),
        );
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.answer, '8080');
        expect(resumedCalls, isEmpty);
        expect((await answerFuture).valueOrNull, '8080');
      },
    );

    test(
      'falls back to resumePausedRun when ask_human has no live waiter',
      () async {
        await repo.create(
          Pause(
            id: 'p-restarted',
            runId: 'r-dead',
            nodeId: 'agent',
            kind: PauseKind.askHuman,
            status: PauseStatus.pending,
            workflowName: 'Flow',
            nodeLabel: 'Agent',
            question: 'Which port?',
            createdAt: DateTime.utc(2026, 11, 21, 11),
          ),
        );

        final result = await service.answerPause(
          'p-restarted',
          const AnswerPauseRequest(answer: '9090'),
        );
        expect(result.isSuccess, isTrue);
        expect(resumedCalls, hasLength(1));
        expect(resumedCalls.single.$1, 'r-dead');
        final input = resumedCalls.single.$2 as HumanAnswerInput;
        expect(input.nodeId, 'agent');
        expect(input.answer, '9090');
      },
    );

    test(
      'returns 404 when missing, 400 on blank answer, 409 when resolved',
      () async {
        final missing = await service.answerPause(
          'nope',
          const AnswerPauseRequest(answer: 'yes'),
        );
        expect(missing.failureOrNull, isA<NotFoundFailure>());

        await repo.create(
          Pause(
            id: 'p-q',
            runId: 'r-1',
            nodeId: 'agent',
            kind: PauseKind.askHuman,
            status: PauseStatus.pending,
            workflowName: 'Flow',
            nodeLabel: 'Agent',
            question: 'Q?',
            createdAt: DateTime.utc(2026, 11, 21, 11),
          ),
        );

        final blank = await service.answerPause(
          'p-q',
          const AnswerPauseRequest(answer: '   '),
        );
        expect(blank.failureOrNull, isA<ValidationFailure>());

        await service.answerPause(
          'p-q',
          const AnswerPauseRequest(answer: 'ok'),
        );
        final conflict = await service.answerPause(
          'p-q',
          const AnswerPauseRequest(answer: 'again'),
        );
        expect(conflict.failureOrNull, isA<ConflictFailure>());
      },
    );
  });
}

final class _FakePauseRepository implements PauseRepository {
  final Map<String, Pause> _items = <String, Pause>{};

  @override
  Future<Result<Pause>> create(Pause pause) async {
    _items[pause.id] = pause;
    return Success(pause);
  }

  @override
  Future<Result<Pause>> getById(String id) async {
    final found = _items[id];
    if (found == null) return FailureResult(NotFoundFailure('Missing $id'));
    return Success(found);
  }

  @override
  Future<Result<({List<Pause> items, int total})>> list({
    PauseStatus? status,
    String? runId,
    int limit = 50,
    int offset = 0,
  }) async {
    final filtered =
        _items.values
            .where((p) => status == null || p.status == status)
            .where((p) => runId == null || p.runId == runId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return Success((
      items: filtered.skip(offset).take(limit).toList(),
      total: filtered.length,
    ));
  }

  @override
  Future<Result<List<Pause>>> listPendingForRun(String runId) async => Success(
    _items.values
        .where((p) => p.runId == runId && p.status == PauseStatus.pending)
        .toList(),
  );

  @override
  Future<Result<Pause>> markAnswered(
    String id, {
    required DateTime answeredAt,
    String? decision,
    String? feedback,
    String? answer,
  }) async {
    final existing = _items[id];
    if (existing == null) return FailureResult(NotFoundFailure('Missing $id'));
    if (existing.status != PauseStatus.pending) {
      return const FailureResult(ConflictFailure('Already resolved'));
    }
    final updated = existing.copyWith(
      status: PauseStatus.answered,
      decision: decision,
      feedback: feedback,
      answer: answer,
      answeredAt: answeredAt,
    );
    _items[id] = updated;
    return Success(updated);
  }

  @override
  Future<Result<List<Pause>>> cancelPendingForRun(
    String runId, {
    required DateTime cancelledAt,
  }) async => const Success(<Pause>[]);
}
