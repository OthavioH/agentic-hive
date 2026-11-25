import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('Pause contracts', () {
    test(
      'PauseKind and PauseStatus parse by name (including legacy approval)',
      () {
        expect(PauseKind.fromName('humanApproval'), PauseKind.humanApproval);
        expect(PauseKind.fromName('approval'), PauseKind.humanApproval);
        expect(PauseKind.fromName('askHuman'), PauseKind.askHuman);
        expect(
          () => PauseKind.fromName('unknown'),
          throwsA(isA<FormatException>()),
        );

        expect(PauseStatus.fromName('pending'), PauseStatus.pending);
        expect(PauseStatus.fromName('answered'), PauseStatus.answered);
        expect(PauseStatus.fromName('cancelled'), PauseStatus.cancelled);
        expect(
          () => PauseStatus.fromName('unknown'),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('Pause round-trips humanApproval and askHuman JSON', () {
      final approval = Pause(
        id: 'pause-1',
        runId: 'run-1',
        nodeId: 'gate-1',
        kind: PauseKind.humanApproval,
        status: PauseStatus.pending,
        workflowName: 'Deploy',
        nodeLabel: 'Approve prod',
        title: 'Production gate',
        instructions: 'Check changelog before approving.',
        allowFeedback: false,
        createdAt: DateTime.utc(2026, 11, 21, 10),
      );
      final decodedApproval = Pause.fromJson(approval.toJson());
      expect(decodedApproval, approval);
      expect(approval.toJson().containsKey('proposal'), isFalse);
      expect(approval.toJson().containsKey('proposalSchema'), isFalse);
      expect(approval.toJson().containsKey('proposalSource'), isFalse);
      expect(approval.toJson().containsKey('editedProposal'), isFalse);

      for (final sample in <Object>[
        [
          {'id': 1},
        ],
        {'a': 'b'},
        'hello',
        42,
      ]) {
        final withProposal = Pause(
          id: 'pause-p',
          runId: 'run-1',
          nodeId: 'gate-1',
          kind: PauseKind.humanApproval,
          status: PauseStatus.answered,
          workflowName: 'Deploy',
          nodeLabel: 'Approve prod',
          instructions: 'Check.',
          proposal: sample,
          proposalSchema: '{"type":"object"}',
          proposalSource: 'Planner',
          editedProposal: sample,
          createdAt: DateTime.utc(2026, 11, 21, 10),
        );
        final wire = jsonDecode(
          jsonEncode(withProposal.toJson()),
        ) as Map<String, dynamic>;
        expect(Pause.fromJson(wire), withProposal);
      }

      final question = Pause(
        id: 'pause-2',
        runId: 'run-1',
        nodeId: 'coder',
        kind: PauseKind.askHuman,
        status: PauseStatus.answered,
        workflowName: 'Deploy',
        nodeLabel: 'Coder',
        question: 'Which region?',
        options: const ['us-east-1', 'eu-west-1'],
        answer: 'us-east-1',
        createdAt: DateTime.utc(2026, 11, 21, 10, 5),
        answeredAt: DateTime.utc(2026, 11, 21, 10, 6),
      );
      final decodedQuestion = Pause.fromJson(question.toJson());
      expect(decodedQuestion, question);
    });

    test('Pause.parentRunId round-trips JSON and defaults to null', () {
      final pause = Pause(
        id: 'pause-child-1',
        runId: 'child-1',
        nodeId: 'gate-1',
        kind: PauseKind.humanApproval,
        status: PauseStatus.pending,
        workflowName: 'Deploy',
        nodeLabel: 'Approve',
        createdAt: DateTime.utc(2026, 11, 21, 10),
        parentRunId: 'parent-1',
      );
      final json = pause.toJson();
      expect(json['parentRunId'], 'parent-1');
      expect(Pause.fromJson(json), pause);

      final withoutParent = Map<String, dynamic>.from(json)
        ..remove('parentRunId');
      expect(Pause.fromJson(withoutParent).parentRunId, isNull);
    });

    test('AnswerPauseRequest and PausesListResponse round-trip JSON', () {
      const approvalReq = AnswerPauseRequest(
        decision: 'approved',
        feedback: 'Ship it',
      );
      expect(AnswerPauseRequest.fromJson(approvalReq.toJson()), approvalReq);

      const proposalReq = AnswerPauseRequest(
        decision: 'approved',
        proposal: {
          'a': [1, 2],
        },
      );
      expect(AnswerPauseRequest.fromJson(proposalReq.toJson()), proposalReq);

      const questionReq = AnswerPauseRequest(answer: 'Use port 8080');
      expect(AnswerPauseRequest.fromJson(questionReq.toJson()), questionReq);

      final listResp = PausesListResponse(
        items: [
          Pause(
            id: 'p-1',
            runId: 'r-1',
            nodeId: 'n-1',
            kind: PauseKind.askHuman,
            status: PauseStatus.pending,
            workflowName: 'Flow',
            nodeLabel: 'Step',
            question: 'Ready?',
            createdAt: DateTime.utc(2026, 11, 21, 12),
          ),
        ],
        total: 1,
      );
      expect(PausesListResponse.fromJson(listResp.toJson()), listResp);
    });

    test('WS pause.created and pause.resolved payloads round-trip JSON', () {
      expect(WsMessageType.pauseCreated, 'pause.created');
      expect(WsMessageType.pauseResolved, 'pause.resolved');

      final pending = Pause(
        id: 'p-1',
        runId: 'r-1',
        nodeId: 'n-1',
        kind: PauseKind.humanApproval,
        status: PauseStatus.pending,
        workflowName: 'Flow',
        nodeLabel: 'Gate',
        instructions: 'Approve?',
        createdAt: DateTime.utc(2026, 11, 21, 12),
      );
      final created = PauseCreatedPayload(pause: pending);
      expect(PauseCreatedPayload.fromJson(created.toJson()), created);

      final resolvedPause = pending.copyWith(
        status: PauseStatus.answered,
        decision: 'approved',
        answeredAt: DateTime.utc(2026, 11, 21, 12, 1),
      );
      final resolved = PauseResolvedPayload(pause: resolvedPause);
      expect(PauseResolvedPayload.fromJson(resolved.toJson()), resolved);
    });
  });
}
