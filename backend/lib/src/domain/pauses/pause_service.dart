import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_answer_handler.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

export 'package:agentic_hive_backend/src/domain/pauses/pause_answer_handler.dart'
    show
        AskHumanPauseAnswerHandler,
        HumanApprovalPauseAnswerHandler,
        PauseAnswerHandler,
        ResumePausedRunCallback;

/// Domain service coordinating listing, querying, and answering [Pause]s,
/// bridging live `ask_human` sessions and post-restart checkpoint recovery
/// (ADR 0019).
final class PauseService {
  /// Creates a pause service.
  new({
    required this._pauses,
    required this._pauseGateway,
    required this._resumePausedRun,
    List<PauseAnswerHandler> handlers = const <PauseAnswerHandler>[
      HumanApprovalPauseAnswerHandler(),
      AskHumanPauseAnswerHandler(),
    ],
    DateTime Function()? now,
  }) : _handlers = <PauseKind, PauseAnswerHandler>{
         for (final handler in handlers) handler.kind: handler,
       },
       _now = now ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  final PauseRepository _pauses;
  final HumanPauseGateway _pauseGateway;
  final ResumePausedRunCallback _resumePausedRun;
  final Map<PauseKind, PauseAnswerHandler> _handlers;
  final DateTime Function() _now;
  final Set<String> _answeringIds = <String>{};

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

  /// Validates [request] via the registered [PauseAnswerHandler] for the
  /// pause's [PauseKind], hands off execution (unblocking a live
  /// `HumanPauseGateway` waiter if present, or preparing/queueing a checkpoint
  /// resume via `GraphEngine` otherwise), and marks the pause `answered` once
  /// the resume handoff is accepted.
  Future<Result<Pause>> answerPause(
    String id,
    AnswerPauseRequest request,
  ) async {
    if (!_answeringIds.add(id)) {
      return const FailureResult(
        ConflictFailure('This pause was already resolved or cancelled.'),
      );
    }
    try {
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

      final handler = _handlers[pause.kind];
      if (handler == null) {
        return FailureResult(
          UnexpectedFailure(
            'No PauseAnswerHandler registered for "${pause.kind.name}".',
          ),
        );
      }

      return await handler.answer(
        pause: pause,
        request: request,
        answeredAt: _now().toUtc(),
        pauses: _pauses,
        pauseGateway: _pauseGateway,
        resumePausedRun: _resumePausedRun,
      );
    } finally {
      _answeringIds.remove(id);
    }
  }
}
