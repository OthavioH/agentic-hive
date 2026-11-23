import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';

/// Metadata describing an active `ask_human` pause request.
final class HumanPauseRequest {
  /// Creates a human pause request.
  const new({
    required this.pauseId,
    required this.runId,
    required this.nodeId,
    required this.attempt,
    required this.question,
    required this.createdAt,
    this.options = const <String>[],
  });

  /// Unique identifier for this pause request.
  final String pauseId;

  /// Run identifier.
  final String runId;

  /// Node identifier.
  final String nodeId;

  /// 1-based attempt number.
  final int attempt;

  /// Question posed to the human.
  final String question;

  /// Optional suggested answers.
  final List<String> options;

  /// Timestamp when the request was opened.
  final DateTime createdAt;
}

/// Port coordinating blocking `ask_human` pauses between `hive-mcp` HTTP
/// requests and human responses or run cancellation (ADR 0019).
abstract interface class HumanPauseGateway {
  /// Emits every new pending request, so the graph engine can pause the run
  /// (ADR 0019) while the harness waits.
  Stream<HumanPauseRequest> get requests;

  /// Emits a request once a human answered it through [submitAnswer], so the
  /// graph engine can move the run from `paused` back to `running` while the
  /// live harness continues (ADR 0019).
  Stream<HumanPauseRequest> get answered;

  /// Suspends until a human answers [question] via [submitAnswer] or the run
  /// is cancelled via [cancelRun].
  Future<Result<String>> requestHumanAnswer({
    required String runId,
    required String nodeId,
    required int attempt,
    required String question,
    List<String> options = const <String>[],
  });

  /// Delivers [answer] to the pending request identified by [pauseId].
  ///
  /// When [runId] or [nodeId] is provided, the pending request must also match
  /// those identifiers so an answer is never delivered across runs or nodes.
  Result<void> submitAnswer({
    required String pauseId,
    required String answer,
    String? runId,
    String? nodeId,
  });

  /// Cancels all pending requests for [runId], unblocking their waiters with a
  /// cancellation failure, and returns the number of cancelled requests.
  int cancelRun(String runId);

  /// Cancels all pending requests for `(runId, nodeId, attempt)`, unblocking
  /// their waiters with a cancellation failure, and returns the number of
  /// cancelled requests.
  int cancelAttempt({
    required String runId,
    required String nodeId,
    required int attempt,
  });

  /// Pending pause requests for [runId].
  List<HumanPauseRequest> pendingForRun(String runId);

  /// All currently pending pause requests.
  List<HumanPauseRequest> get allPending;
}

final class _PendingPause {
  new({required this.request, required this.completer});

  final HumanPauseRequest request;
  final Completer<Result<String>> completer;
}

/// In-memory [HumanPauseGateway] supporting concurrent pending questions,
/// answer delivery by `pauseId`, and per-run cancellation.
final class InMemoryHumanPauseGateway implements HumanPauseGateway {
  /// Creates an in-memory human pause gateway; [generateId] defaults to a
  /// collision-free 128-bit random identifier so IDs never collide across
  /// backend restarts.
  new({String Function()? generateId}) : _generateId = generateId ?? randomId;

  final String Function() _generateId;
  final Map<String, _PendingPause> _pending = <String, _PendingPause>{};
  final StreamController<HumanPauseRequest> _requests =
      StreamController<HumanPauseRequest>.broadcast(sync: true);
  final StreamController<HumanPauseRequest> _answered =
      StreamController<HumanPauseRequest>.broadcast(sync: true);

  @override
  Stream<HumanPauseRequest> get requests => _requests.stream;

  @override
  Stream<HumanPauseRequest> get answered => _answered.stream;

  @override
  List<HumanPauseRequest> get allPending =>
      _pending.values.map((entry) => entry.request).toList(growable: false);

  @override
  List<HumanPauseRequest> pendingForRun(String runId) => _pending.values
      .where((entry) => entry.request.runId == runId)
      .map((entry) => entry.request)
      .toList(growable: false);

  @override
  Future<Result<String>> requestHumanAnswer({
    required String runId,
    required String nodeId,
    required int attempt,
    required String question,
    List<String> options = const <String>[],
  }) {
    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) {
      return Future<Result<String>>.value(
        const FailureResult(
          ValidationFailure('question is required and must be non-blank.'),
        ),
      );
    }

    final pauseId = 'pause-${_generateId()}';
    final request = HumanPauseRequest(
      pauseId: pauseId,
      runId: runId,
      nodeId: nodeId,
      attempt: attempt,
      question: trimmedQuestion,
      options: List<String>.unmodifiable(options),
      createdAt: DateTime.now().toUtc(),
    );
    final completer = Completer<Result<String>>();
    _pending[pauseId] = _PendingPause(request: request, completer: completer);
    _requests.add(request);
    return completer.future;
  }

  @override
  Result<void> submitAnswer({
    required String pauseId,
    required String answer,
    String? runId,
    String? nodeId,
  }) {
    final pending = _pending[pauseId];
    if (pending == null ||
        (runId != null && pending.request.runId != runId) ||
        (nodeId != null && pending.request.nodeId != nodeId)) {
      return FailureResult(
        NotFoundFailure('No pending pause request "$pauseId".'),
      );
    }
    _pending.remove(pauseId);
    if (!pending.completer.isCompleted) {
      pending.completer.complete(Success(answer));
    }
    _answered.add(pending.request);
    return const Success(null);
  }

  @override
  int cancelRun(String runId) => _cancelMatching(
    (req) => req.runId == runId,
    'Run "$runId" was cancelled while waiting for a human answer.',
  );

  @override
  int cancelAttempt({
    required String runId,
    required String nodeId,
    required int attempt,
  }) => _cancelMatching(
    (req) =>
        req.runId == runId && req.nodeId == nodeId && req.attempt == attempt,
    'Node attempt ($runId, $nodeId, $attempt) ended while waiting for a '
    'human answer.',
  );

  int _cancelMatching(
    bool Function(HumanPauseRequest) predicate,
    String reason,
  ) {
    final matchingIds = _pending.entries
        .where((entry) => predicate(entry.value.request))
        .map((entry) => entry.key)
        .toList(growable: false);

    for (final pauseId in matchingIds) {
      final pending = _pending.remove(pauseId);
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.complete(FailureResult(ConflictFailure(reason)));
      }
    }
    return matchingIds.length;
  }

  /// Cancels all remaining pending pause requests on shutdown.
  void dispose() {
    unawaited(_requests.close());
    unawaited(_answered.close());
    final ids = _pending.keys.toList(growable: false);
    for (final pauseId in ids) {
      final pending = _pending.remove(pauseId);
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.complete(
          const FailureResult(
            ConflictFailure('Backend shut down while waiting for human input.'),
          ),
        );
      }
    }
  }
}
