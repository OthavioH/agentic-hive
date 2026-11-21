import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/engine/resume_input.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Callback used to resume a paused run (or supply an answer to a run that is
/// already resuming another paused branch) when no live `hive-mcp` waiter holds
/// the session open.
typedef ResumePausedRunCallback = Future<Result<Run>> Function(
  String runId, {
  required ResumeInput input,
});

/// Per-[PauseKind] strategy that validates an [AnswerPauseRequest], hands the
/// response off to the live `HumanPauseGateway` or `GraphEngine` resume path,
/// and marks the [Pause] answered in [PauseRepository] once the resume step is
/// accepted.
abstract base class PauseAnswerHandler {
  /// Creates a pause answer handler.
  const new();

  /// The [PauseKind] handled by this strategy.
  PauseKind get kind;

  /// Validates [request] against [pause], triggers the resume or live waiter
  /// delivery, and persists the answered [Pause].
  Future<Result<Pause>> answer({
    required Pause pause,
    required AnswerPauseRequest request,
    required DateTime answeredAt,
    required PauseRepository pauses,
    required HumanPauseGateway pauseGateway,
    required ResumePausedRunCallback resumePausedRun,
  });
}

/// Strategy for answering [PauseKind.humanApproval] pauses.
final class HumanApprovalPauseAnswerHandler extends PauseAnswerHandler {
  /// Creates a human-approval pause answer handler.
  const new();

  @override
  PauseKind get kind => PauseKind.humanApproval;

  @override
  Future<Result<Pause>> answer({
    required Pause pause,
    required AnswerPauseRequest request,
    required DateTime answeredAt,
    required PauseRepository pauses,
    required HumanPauseGateway pauseGateway,
    required ResumePausedRunCallback resumePausedRun,
  }) async {
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

    final resumed = await resumePausedRun(
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

    return await pauses.markAnswered(
      pause.id,
      answeredAt: answeredAt,
      decision: decision.name,
      feedback: feedback,
    );
  }
}

/// Strategy for answering [PauseKind.askHuman] pauses (ADR 0019).
final class AskHumanPauseAnswerHandler extends PauseAnswerHandler {
  /// Creates an `ask_human` pause answer handler.
  const new();

  @override
  PauseKind get kind => PauseKind.askHuman;

  @override
  Future<Result<Pause>> answer({
    required Pause pause,
    required AnswerPauseRequest request,
    required DateTime answeredAt,
    required PauseRepository pauses,
    required HumanPauseGateway pauseGateway,
    required ResumePausedRunCallback resumePausedRun,
  }) async {
    final rawAnswer = request.answer;
    if (rawAnswer == null || rawAnswer.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure(
          'Field "answer" must be a non-blank string for an ask_human pause.',
        ),
      );
    }

    // Live-waiter path (ADR 0019): unblock the active hive-mcp HTTP request
    // when the harness is still running in this backend process, verifying
    // (runId, nodeId) so an answer can never be delivered across runs.
    final liveResult = pauseGateway.submitAnswer(
      pauseId: pause.id,
      answer: rawAnswer,
      runId: pause.runId,
      nodeId: pause.nodeId,
    );
    if (liveResult.isSuccess) {
      return await pauses.markAnswered(
        pause.id,
        answeredAt: answeredAt,
        answer: rawAnswer,
      );
    }

    // Post-restart fallback (ADR 0019): no live waiter exists, so prepare the
    // checkpoint resume (including pre-node snapshot rollback) first and only
    // mark the pause answered once the resume handoff succeeds.
    final resumed = await resumePausedRun(
      pause.runId,
      input: HumanAnswerInput(nodeId: pause.nodeId, answer: rawAnswer),
    );
    if (resumed case FailureResult<Run>(:final failure)) {
      return FailureResult(failure);
    }

    return await pauses.markAnswered(
      pause.id,
      answeredAt: answeredAt,
      answer: rawAnswer,
    );
  }
}
