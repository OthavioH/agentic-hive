import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for listing, answering, and observing pending pauses.
abstract interface class PauseRepository {
  /// Lists all currently pending pauses ordered by creation time ascending.
  Future<Result<List<Pause>>> listPendingPauses();

  /// Submits an approval decision or human answer for pause [id].
  Future<Result<Pause>> answerPause(String id, AnswerPauseRequest request);

  /// Broadcasts live pause events (`pause.created`, `pause.resolved`, sync).
  Stream<PauseEvent> watchPauseEvents();

  /// Emits the current count of pending pauses as it changes in real time.
  Stream<int> watchPendingPausesCount();
}
