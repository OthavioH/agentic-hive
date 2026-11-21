import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pauses_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [PauseRepository] backed by [PausesRemoteDataSource] and a live
/// [PauseEvent] stream from the backend WebSocket.
final class PauseRepositoryImpl implements PauseRepository {
  /// Creates a [PauseRepositoryImpl].
  new({required this._remoteDataSource, required this._eventsStream}) {
    _eventsSub = _eventsStream.listen(_onEvent);
  }

  final PausesRemoteDataSource _remoteDataSource;
  final Stream<PauseEvent> _eventsStream;
  final Set<String> _pendingIds = <String>{};
  final Map<String, Pause> _createdDuringFetch = <String, Pause>{};
  final Set<String> _resolvedDuringFetch = <String>{};
  final StreamController<int> _countController =
      StreamController<int>.broadcast();
  StreamSubscription<PauseEvent>? _eventsSub;
  int _inFlightFetches = 0;
  bool _disposed = false;
  int _lastEmittedCount = 0;

  @override
  Future<Result<List<Pause>>> listPendingPauses() async {
    _inFlightFetches++;
    final result = await _remoteDataSource.listPendingPauses();
    _inFlightFetches--;

    if (_disposed) return result;

    if (result case Success<List<Pause>>(:final value)) {
      final mergedById = <String, Pause>{
        for (final pause in value)
          if (pause.status == PauseStatus.pending &&
              !_resolvedDuringFetch.contains(pause.id))
            pause.id: pause,
        ..._createdDuringFetch,
      };
      if (_inFlightFetches == 0) {
        _createdDuringFetch.clear();
        _resolvedDuringFetch.clear();
      }
      _pendingIds
        ..clear()
        ..addAll(mergedById.keys);
      _emitCountIfChanged();
      final mergedList = mergedById.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return Success(mergedList);
    }

    if (_inFlightFetches == 0) {
      _createdDuringFetch.clear();
      _resolvedDuringFetch.clear();
    }
    return result;
  }

  @override
  Future<Result<Pause>> answerPause(
    String id,
    AnswerPauseRequest request,
  ) async {
    final result = await _remoteDataSource.answerPause(id, request);
    if (!_disposed && result is Success<Pause>) {
      if (_inFlightFetches > 0) {
        _resolvedDuringFetch.add(id);
        _createdDuringFetch.remove(id);
      }
      if (_pendingIds.remove(id)) {
        _emitCountIfChanged();
      }
    }
    return result;
  }

  @override
  Stream<PauseEvent> watchPauseEvents() => _eventsStream;

  @override
  Stream<int> watchPendingPausesCount() async* {
    yield _pendingIds.length;
    yield* _countController.stream;
  }

  /// Fetches pending pauses to synchronize the live badge count on connect or
  /// reconnect.
  Future<void> syncPendingCount() async {
    await listPendingPauses();
  }

  void _onEvent(PauseEvent event) {
    if (_disposed) return;
    switch (event) {
      case PauseCreatedEvent(:final pause):
        if (pause.status == PauseStatus.pending) {
          if (_inFlightFetches > 0) {
            _createdDuringFetch[pause.id] = pause;
            _resolvedDuringFetch.remove(pause.id);
          }
          if (_pendingIds.add(pause.id)) {
            _emitCountIfChanged();
          }
        }
      case PauseResolvedEvent(:final pause):
        if (_inFlightFetches > 0) {
          _resolvedDuringFetch.add(pause.id);
          _createdDuringFetch.remove(pause.id);
        }
        if (_pendingIds.remove(pause.id)) {
          _emitCountIfChanged();
        }
      case PauseSyncRequestedEvent():
        unawaited(syncPendingCount());
    }
  }

  void _emitCountIfChanged() {
    final next = _pendingIds.length;
    if (next != _lastEmittedCount && !_countController.isClosed) {
      _lastEmittedCount = next;
      _countController.add(next);
    }
  }

  /// Cancels internal subscriptions and closes the count stream.
  Future<void> dispose() async {
    _disposed = true;
    await _eventsSub?.cancel();
    _eventsSub = null;
    await _countController.close();
  }
}
