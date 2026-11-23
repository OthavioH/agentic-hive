import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// In-memory fake [PauseRepository] for unit and widget tests.
final class FakePauseRepository implements PauseRepository {
  /// Creates a [FakePauseRepository] seeded with [initial].
  new({List<Pause>? initial}) {
    for (final item in initial ?? const <Pause>[]) {
      _store[item.id] = item;
    }
  }

  final Map<String, Pause> _store = <String, Pause>{};
  final StreamController<PauseEvent> _events =
      StreamController<PauseEvent>.broadcast();
  final StreamController<int> _count = StreamController<int>.broadcast();

  /// Optional custom handler for [listPendingPauses].
  Future<Result<List<Pause>>> Function()? onListPendingPauses;

  /// Optional custom handler for [answerPause].
  Future<Result<Pause>> Function(String id, AnswerPauseRequest request)?
  onAnswerPause;

  /// Recorded calls to [answerPause].
  final List<({String id, AnswerPauseRequest request})> recordedAnswers =
      <({String id, AnswerPauseRequest request})>[];

  /// Number of times [listPendingPauses] was called.
  int listCallCount = 0;

  @override
  Future<Result<List<Pause>>> listPendingPauses() async {
    listCallCount++;
    final handler = onListPendingPauses;
    if (handler != null) {
      return await handler();
    }
    final items = _store.values
        .where((p) => p.status == PauseStatus.pending)
        .toList();
    return Success(items);
  }

  @override
  Future<Result<Pause>> answerPause(
    String id,
    AnswerPauseRequest request,
  ) async {
    recordedAnswers.add((id: id, request: request));
    final handler = onAnswerPause;
    if (handler != null) {
      return await handler(id, request);
    }
    final existing = _store[id];
    if (existing == null || existing.status != PauseStatus.pending) {
      return const FailureResult(
        ConflictFailure('This pause was already resolved or cancelled.'),
      );
    }
    final updated = existing.copyWith(
      status: PauseStatus.answered,
      decision: request.decision,
      feedback: request.feedback,
      answer: request.answer,
      answeredAt: DateTime.utc(2026, 11, 21, 12),
    );
    _store.remove(id);
    _emitCount();
    return Success(updated);
  }

  @override
  Stream<PauseEvent> watchPauseEvents() => _events.stream;

  @override
  Stream<int> watchPendingPausesCount() async* {
    yield _pendingCount;
    yield* _count.stream;
  }

  /// Adds or updates a pause and emits a [PauseCreatedEvent].
  void emitCreated(Pause pause) {
    _store[pause.id] = pause;
    _events.add(PauseCreatedEvent(pause));
    _emitCount();
  }

  /// Removes a pause and emits a [PauseResolvedEvent].
  void emitResolved(Pause pause) {
    _store.remove(pause.id);
    _events.add(PauseResolvedEvent(pause));
    _emitCount();
  }

  /// Emits a [PauseSyncRequestedEvent].
  void emitSyncRequested() {
    _events.add(const PauseSyncRequestedEvent());
  }

  /// Emits an explicit pending count on [watchPendingPausesCount].
  void emitCount(int count) {
    if (!_count.isClosed) {
      _count.add(count);
    }
  }

  int get _pendingCount =>
      _store.values.where((p) => p.status == PauseStatus.pending).length;

  void _emitCount() {
    if (!_count.isClosed) {
      _count.add(_pendingCount);
    }
  }

  /// Closes internal stream controllers.
  Future<void> dispose() async {
    await _events.close();
    await _count.close();
  }
}
