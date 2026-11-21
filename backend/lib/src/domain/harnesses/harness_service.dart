import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Manages in-memory harness availability, probing, and status broadcasts.
abstract interface class HarnessService {
  /// Broadcast stream of updated [HarnessInfo] entries.
  Stream<HarnessInfo> get statusUpdates;

  /// Returns cached harnesses, running initial detection if not yet scanned.
  Future<Result<List<HarnessInfo>>> listHarnesses();

  /// Re-runs detection for all harnesses and broadcasts any status changes.
  Future<Result<List<HarnessInfo>>> refreshAll();

  /// Re-runs detection for [id], updates cache, and broadcasts the result.
  Future<Result<HarnessInfo>> refreshOne(HarnessId id);

  /// Records an observed authentication error for [id] and broadcasts it.
  void reportAuthError(HarnessId id, {String? message});

  /// Records an observed outdated-version error for [id] and broadcasts it.
  void reportOutdated(HarnessId id, {String? message});

  /// Releases stream resources.
  Future<void> dispose();
}

/// Default in-memory implementation of [HarnessService].
final class DefaultHarnessService implements HarnessService {
  /// Creates a harness service backed by [detectors].
  new({required List<HarnessDetector> detectors, DateTime Function()? now})
    : _detectors = {for (final detector in detectors) detector.id: detector},
      _now = now ?? DateTime.now;

  final Map<HarnessId, HarnessDetector> _detectors;
  final DateTime Function() _now;
  final Map<HarnessId, HarnessInfo> _cache = {};
  final StreamController<HarnessInfo> _statusController =
      StreamController<HarnessInfo>.broadcast();

  bool _scanned = false;
  Future<List<HarnessInfo>>? _inFlightInitialScan;

  @override
  Stream<HarnessInfo> get statusUpdates => _statusController.stream;

  @override
  Future<Result<List<HarnessInfo>>> listHarnesses() async {
    if (_scanned) {
      return Success(_orderedCache());
    }
    final scan = _inFlightInitialScan ??= _scanAll(broadcastChanges: false);
    try {
      final results = await scan;
      return Success(results);
    } finally {
      if (identical(_inFlightInitialScan, scan)) {
        _inFlightInitialScan = null;
      }
    }
  }

  @override
  Future<Result<List<HarnessInfo>>> refreshAll() async {
    final results = await _scanAll(broadcastChanges: true);
    return Success(results);
  }

  @override
  Future<Result<HarnessInfo>> refreshOne(HarnessId id) async {
    final detector = _detectors[id];
    if (detector == null) {
      return FailureResult(
        NotFoundFailure('Unknown harness "${id.wireName}".'),
      );
    }
    final updated = await detector.detect();
    _cache[id] = updated;
    _emit(updated);
    return Success(updated);
  }

  @override
  void reportAuthError(HarnessId id, {String? message}) {
    _reportObservedStatus(
      id,
      status: HarnessStatus.authError,
      errorMessage:
          message ??
          'Authentication required. Sign in with ${id.displayName} CLI and '
              're-check.',
    );
  }

  @override
  void reportOutdated(HarnessId id, {String? message}) {
    _reportObservedStatus(
      id,
      status: HarnessStatus.outdated,
      errorMessage:
          message ??
          'Update required. Update ${id.displayName} CLI and re-check.',
    );
  }

  @override
  Future<void> dispose() => _statusController.close();

  Future<List<HarnessInfo>> _scanAll({required bool broadcastChanges}) async {
    final detectors = _detectors.values.toList();
    final results = await Future.wait([
      for (final detector in detectors) detector.detect(),
    ]);

    for (final updated in results) {
      final previous = _cache[updated.id];
      _cache[updated.id] = updated;
      if (broadcastChanges && _hasMeaningfulChange(previous, updated)) {
        _emit(updated);
      }
    }
    _scanned = true;
    return _orderedCache();
  }

  void _reportObservedStatus(
    HarnessId id, {
    required HarnessStatus status,
    required String errorMessage,
  }) {
    final previous = _cache[id];
    final updated = HarnessInfo(
      id: id,
      displayName: id.displayName,
      status: status,
      version: previous?.version,
      executablePath: previous?.executablePath,
      errorMessage: errorMessage,
      checkedAt: _now(),
    );
    _cache[id] = updated;
    _emit(updated);
  }

  List<HarnessInfo> _orderedCache() => [
    for (final id in _detectors.keys) ?_cache[id],
  ];

  void _emit(HarnessInfo info) {
    if (!_statusController.isClosed) {
      _statusController.add(info);
    }
  }

  static bool _hasMeaningfulChange(HarnessInfo? previous, HarnessInfo next) {
    if (previous == null) return true;
    return previous.status != next.status ||
        previous.version != next.version ||
        previous.executablePath != next.executablePath ||
        previous.errorMessage != next.errorMessage;
  }
}
