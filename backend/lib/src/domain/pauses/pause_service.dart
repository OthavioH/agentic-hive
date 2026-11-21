import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Callback used by [PauseService] to resume a paused run in the background
/// when no live `hive-mcp` waiter is holding the session open.
typedef ResumePausedRunCallback = Future<Result<Run>> Function(
  String runId, {
  required ResumeInput input,
});

/// Domain service coordinating listing, querying, and answering [Pause]s,
/// bridging live `ask_human` sessions and post-restart checkpoint recovery
/// (ADR 0019).
final class PauseService {
  /// Creates a pause service.
  new({
    required this._pauses,
    required this._pauseGateway,
    required this._resumePausedRun,
    DateTime Function()? now,
  }) : _now = now ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  final PauseRepository _pauses;
  final HumanPauseGateway _pauseGateway;
  final ResumePausedRunCallback _resumePausedRun;
  final DateTime Function() _now;

  /// Lists pauses ordered by `createdAt ASC`, defaulting to
  /// [PauseStatus.pending].
  Future<Result<PausesListResponse>> listPauses({
    PauseStatus? status = PauseStatus.pending,
    String? runId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 200) {
      return const FailureResult(
        ValidationFailure('Query parameter "limit" must be between 1 and 200.'),
      );
    }
    if (offset < 0) {
      return const FailureResult(
        ValidationFailure('Query parameter "offset" must be >= 0.'),
      );
    }

    final result = await _pauses.list(
      status: status,
      runId: runId,
      limit: limit,
      offset: offset,
    );
    return result.map(
      (page) => PausesListResponse(items: page.items, total: page.total),
    );
  }

  /// Loads a single pause by [id], or returns `NotFoundFailure`.
  Future<Result<Pause>> getPause(String id) => _pauses.getById(id);

  /// Validates [request] against the pause's [PauseKind], marks it `answered`,
  /// and resumes execution (unblocking a live `HumanPauseGateway` waiter if
  /// present, or resuming from checkpoint via `GraphEngine` otherwise).
  Future<Result<Pause>> answerPause(
    String id,
    AnswerPauseRequest request,
  ) async {
    final existingResult = await _pauses.getById(id);
    if (existingResult case FailureResult<Pause>(:final failure)) {
      return FailureResult(failure);
    }
    final pause = existingResult.valueOrNull!;
    if (pause.status != PauseStatus.pending) {
      return const FailureResult(
        ConflictFailure('This pause was already resolved or cancelled.'),
      );
    }

    switch (pause.kind) {
      case PauseKind.humanApproval:
        return await _answerApproval(pause, request);
      case PauseKind.askHuman:
        return await _answerQuestion(pause, request);
    }
  }

  Future<Result<Pause>> _answerApproval(
    Pause pause,
    AnswerPauseRequest request,
  ) async {
    final rawDecision = request.decision?.trim();
    final HumanApprovalDecision decision;
    if (rawDecision == HumanApprovalDecision.approved.name) {
      decision = HumanApprovalDecision.approved;
    } else if (rawDecision == HumanApprovalDecision.rejected.name) {
      decision = HumanApprovalDecision.rejected;
    } else {
      return const FailureResult(
        ValidationFailure(
          'Field "decision" must be "approved" or "rejected" for an approval '
          'pause.',
        ),
      );
    }

    final trimmedFeedback = request.feedback?.trim();
    final feedback = (trimmedFeedback == null || trimmedFeedback.isEmpty)
        ? null
        : trimmedFeedback;
    if (!pause.allowFeedback && feedback != null) {
      return const FailureResult(
        ValidationFailure('Feedback is not allowed for this approval pause.'),
      );
    }

    final updatedResult = await _pauses.markAnswered(
      pause.id,
      answeredAt: _now().toUtc(),
      decision: decision.name,
      feedback: feedback,
    );
    if (updatedResult case FailureResult<Pause>(:final failure)) {
      return FailureResult(failure);
    }

    final resumed = await _resumePausedRun(
      pause.runId,
      input: ApprovalDecisionInput(
        nodeId: pause.nodeId,
        decision: decision,
        feedback: feedback,
      ),
    );
    if (resumed case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    return updatedResult;
  }

  Future<Result<Pause>> _answerQuestion(
    Pause pause,
    AnswerPauseRequest request,
  ) async {
    final rawAnswer = request.answer;
    if (rawAnswer == null || rawAnswer.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure(
          'Field "answer" must be a non-blank string for an ask_human pause.',
        ),
      );
    }

    final updatedResult = await _pauses.markAnswered(
      pause.id,
      answeredAt: _now().toUtc(),
      answer: rawAnswer,
    );
    if (updatedResult case FailureResult<Pause>(:final failure)) {
      return FailureResult(failure);
    }

    // Live-waiter path (ADR 0019): unblock the active hive-mcp HTTP request
    // when the harness is still running in this backend process.
    final liveResult = _pauseGateway.submitAnswer(
      pauseId: pause.id,
      answer: rawAnswer,
    );
    if (liveResult.isSuccess) {
      return updatedResult;
    }

    // Post-restart fallback (ADR 0019): no live waiter exists, so resume from
    // checkpoint, roll back to pre-node snapshot, and re-run with humanAnswer.
    final resumed = await _resumePausedRun(
      pause.runId,
      input: HumanAnswerInput(nodeId: pause.nodeId, answer: rawAnswer),
    );
    if (resumed case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    return updatedResult;
  }
}
