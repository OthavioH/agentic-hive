import 'package:test/test.dart';

import '../../../tool/src/hive/wave_plan.dart';

PullRequest _pr(String state, String body) =>
    PullRequest(number: 1, state: state, title: 'x', body: body);

void main() {
  group('PullRequest.closesIssue', () {
    test('matches closing keywords for that exact issue', () {
      expect(_pr('OPEN', 'Closes #116').closesIssue(116), isTrue);
      expect(_pr('OPEN', 'fixes #116.').closesIssue(116), isTrue);
      expect(_pr('OPEN', 'Resolved #116').closesIssue(116), isTrue);
    });

    test('ignores mentions and other numbers', () {
      expect(_pr('OPEN', 'Part of #116').closesIssue(116), isFalse);
      expect(_pr('OPEN', 'Closes #1160').closesIssue(116), isFalse);
    });
  });

  group('planWave', () {
    const a = Ticket(number: 1, title: 'a', isOpen: true);
    const b = Ticket(
      number: 2,
      title: 'b',
      isOpen: true,
      blockedBy: [Blocker(number: 1, isOpen: true)],
    );
    const c = Ticket(number: 3, title: 'c', isOpen: true);

    test('starts unblocked tickets and holds blocked ones', () {
      final plan = planWave([a, b, c], []);
      expect(plan.withStatus(.startable).map((t) => t.number), [1, 3]);
      expect(plan.statuses[2], TicketStatus.blocked);
      expect(plan.allDone, isFalse);
    });

    test('a PR merged into the spec branch unblocks dependents although '
        'the issue stays open', () {
      final plan = planWave([a, b, c], [_pr('MERGED', 'Closes #1')]);
      expect(plan.statuses[1], TicketStatus.done);
      expect(plan.statuses[2], TicketStatus.startable);
    });

    test('an open PR marks the ticket in flight; a closed one does not', () {
      final plan = planWave(
        [a, c],
        [_pr('OPEN', 'Closes #1'), _pr('CLOSED', 'Closes #3')],
      );
      expect(plan.statuses[1], TicketStatus.inFlight);
      expect(plan.statuses[3], TicketStatus.startable);
    });

    test('a blocker outside the spec counts by its GitHub state', () {
      const d = Ticket(
        number: 4,
        title: 'd',
        isOpen: true,
        blockedBy: [Blocker(number: 99, isOpen: false)],
      );
      expect(planWave([d], []).statuses[4], TicketStatus.startable);
    });

    test('closed tickets are done', () {
      const closed = Ticket(number: 5, title: 'e', isOpen: false);
      expect(planWave([closed], []).allDone, isTrue);
    });
  });

  group('planWave wireframe approval', () {
    const wire = Ticket(
      number: 10,
      title: '[Wireframe] Run list',
      isOpen: true,
    );
    const wireApproved = Ticket(
      number: 10,
      title: '[Wireframe] Run list',
      isOpen: true,
      labels: [wireframeApprovedLabel],
    );
    const style = Ticket(number: 11, title: '[Styling] Run list', isOpen: true);
    const styleWithBlocker = Ticket(
      number: 11,
      title: '[Styling] Run list',
      isOpen: true,
      blockedBy: [Blocker(number: 10, isOpen: true)],
    );
    const other = Ticket(number: 3, title: 'c', isOpen: true);

    test(
      'merged unlabelled wireframe puts styling ticket in awaitingApproval',
      () {
        final plan = planWave([wire, style], [_pr('MERGED', 'Closes #10')]);
        expect(plan.statuses[11], TicketStatus.awaitingApproval);
        expect(plan.withStatus(.startable), isEmpty);
        expect(plan.wireframesToApprove.map((t) => t.number), [10]);
      },
    );

    test('approved wireframe makes styling ticket startable', () {
      final plan = planWave(
        [wireApproved, style],
        [_pr('MERGED', 'Closes #10')],
      );
      expect(plan.statuses[11], TicketStatus.startable);
      expect(plan.wireframesToApprove, isEmpty);
    });

    test(
      'closed unlabelled wireframe puts styling ticket in awaitingApproval',
      () {
        const wireClosed = Ticket(
          number: 10,
          title: '[Wireframe] Run list',
          isOpen: false,
        );
        final plan = planWave([wireClosed, style], []);
        expect(plan.statuses[11], TicketStatus.awaitingApproval);
      },
    );

    test('open wireframe without merged PR blocks styling ticket', () {
      final withoutBlocker = planWave([wire, style], []);
      expect(withoutBlocker.statuses[11], TicketStatus.blocked);

      final withBlocker = planWave([wire, styleWithBlocker], []);
      expect(withBlocker.statuses[11], TicketStatus.blocked);
    });

    test(
      'non-styling tickets remain startable next to unapproved wireframe',
      () {
        const nonPrefix = Ticket(
          number: 12,
          title: 'Run list styling',
          isOpen: true,
        );
        final plan = planWave(
          [wire, style, other, nonPrefix],
          [_pr('MERGED', 'Closes #10')],
        );
        expect(plan.withStatus(.startable).map((t) => t.number), [3, 12]);
        expect(plan.statuses[11], TicketStatus.awaitingApproval);
      },
    );

    test('allDone is false when only awaitingApproval tickets remain', () {
      final plan = planWave([wire, style], [_pr('MERGED', 'Closes #10')]);
      expect(plan.allDone, isFalse);
    });

    test('styling ticket with no matching wireframe is startable', () {
      final plan = planWave([style], []);
      expect(plan.statuses[11], TicketStatus.startable);
    });
  });

  test('openTicketPullRequests keeps open PRs that close a spec ticket', () {
    const tickets = [Ticket(number: 1, title: 'a', isOpen: true)];
    final prs = [
      _pr('OPEN', 'Closes #1'),
      _pr('MERGED', 'Closes #1'),
      _pr('OPEN', 'Closes #2'),
      _pr('OPEN', 'Part of #1'),
    ];
    expect(openTicketPullRequests(tickets, prs), [prs.first]);
  });
}
