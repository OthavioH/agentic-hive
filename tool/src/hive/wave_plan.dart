/// An issue that blocks a ticket.
final class Blocker {
  /// Creates a [Blocker].
  const new({required this.number, required this.isOpen});

  /// Issue number.
  final int number;

  /// Whether the blocking issue is still open on GitHub.
  final bool isOpen;
}

/// A sub-issue of a spec.
final class Ticket {
  /// Creates a [Ticket].
  const new({
    required this.number,
    required this.title,
    required this.isOpen,
    this.blockedBy = const <Blocker>[],
    this.labels = const <String>[],
  });

  /// Issue number.
  final int number;

  /// Issue title.
  final String title;

  /// Whether the issue is open on GitHub.
  final bool isOpen;

  /// Issues that block this one (GitHub native dependencies).
  final List<Blocker> blockedBy;

  /// Label names.
  final List<String> labels;
}

/// A pull request into the spec branch.
final class PullRequest {
  /// Creates a [PullRequest].
  const new({
    required this.number,
    required this.state,
    required this.title,
    required this.body,
  });

  /// PR number.
  final int number;

  /// `OPEN`, `MERGED` or `CLOSED`, as `gh pr list --json state` reports it.
  final String state;

  /// PR title.
  final String title;

  /// PR body.
  final String body;

  /// Whether this PR says it closes [issue] (`Closes #n`, `Fixes #n`, ...).
  bool closesIssue(int issue) => RegExp(
    r'\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#'
    '$issue'
    r'\b',
    caseSensitive: false,
  ).hasMatch('$title\n$body');
}

/// Where a ticket stands in the spec.
enum TicketStatus {
  /// Closed, or a PR that closes it was merged into the spec branch.
  done,

  /// A PR that closes it is open against the spec branch.
  inFlight,

  /// Not done, not in flight, and every blocker is done.
  startable,

  /// Waiting for a blocker that is not done.
  blocked,
}

/// The status of every ticket of a spec.
final class WavePlan {
  /// Creates a [WavePlan].
  const new(this.tickets, this.statuses);

  /// Tickets in spec order.
  final List<Ticket> tickets;

  /// Status per ticket number.
  final Map<int, TicketStatus> statuses;

  /// Tickets with [status], in spec order.
  List<Ticket> withStatus(TicketStatus status) =>
      tickets.where((t) => statuses[t.number] == status).toList();

  /// Whether every ticket is done.
  bool get allDone => tickets.every((t) => statuses[t.number] == .done);

  /// One line per ticket, for logs and summaries.
  String describe() => tickets
      .map((t) => '#${t.number} ${statuses[t.number]!.name}: ${t.title}')
      .join('\n');
}

/// Computes the status of each of [tickets] from the [pullRequests] into the
/// spec branch.
///
/// A merged PR into the spec branch counts as done even though GitHub keeps
/// the issue open (closing keywords only act on the default branch).
WavePlan planWave(List<Ticket> tickets, List<PullRequest> pullRequests) {
  bool hasPr(int issue, String state) =>
      pullRequests.any((pr) => pr.state == state && pr.closesIssue(issue));

  final done = <int>{
    for (final t in tickets)
      if (!t.isOpen || hasPr(t.number, 'MERGED')) t.number,
  };
  final inSpec = {for (final t in tickets) t.number};
  bool resolved(Blocker b) =>
      inSpec.contains(b.number) ? done.contains(b.number) : !b.isOpen;

  return WavePlan(tickets, {
    for (final t in tickets)
      t.number: done.contains(t.number)
          ? .done
          : hasPr(t.number, 'OPEN')
          ? .inFlight
          : t.blockedBy.every(resolved)
          ? .startable
          : .blocked,
  });
}
