import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Submits a human approval decision or answer for a pending pause.
final class AnswerPauseUseCase {
  /// Creates an [AnswerPauseUseCase].
  const new(this._repository);

  final PauseRepository _repository;

  /// Answers pause [id] with [request].
  Future<Result<Pause>> call(String id, AnswerPauseRequest request) =>
      _repository.answerPause(id, request);
}
