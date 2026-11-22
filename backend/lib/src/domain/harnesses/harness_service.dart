import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_detector.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_mcp_installer.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
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

  /// Installs or updates the `hive` MCP server in [id]'s user configuration
  /// and returns the refreshed [HarnessInfo].
  Future<Result<HarnessInfo>> installMcp(HarnessId id);

  /// Applies custom executable path overrides for all harnesses.
  ///
  /// When [triggerRefresh] is `true`, any harness whose override changed is
  /// immediately re-detected and broadcast.
  Future<void> applyExecutableOverrides(
    Map<HarnessId, String> overrides, {
    bool triggerRefresh = true,
  });

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
  new({
    required List<HarnessDetector> detectors,
    this._mcpInstallers,
    this._mcpLocator,
    DateTime Function()? now,
  }) : _detectors = {for (final detector in detectors) detector.id: detector},
       _now = now ?? DateTime.now;

  final Map<HarnessId, HarnessDetector> _detectors;
  final HarnessMcpInstallerRegistry? _mcpInstallers;
  final HiveMcpLocator? _mcpLocator;
  final DateTime Function() _now;
  final Map<HarnessId, HarnessInfo> _cache = {};
  final Map<HarnessId, String?> _overrides = {};
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
    final detected = await detector.detect();
    final updated = await _enrichMcpStatus(detected);
    _cache[id] = updated;
    _emit(updated);
    return Success(updated);
  }

  @override
  Future<Result<HarnessInfo>> installMcp(HarnessId id) async {
    final detector = _detectors[id];
    if (detector == null) {
      return FailureResult(
        NotFoundFailure('Unknown harness "${id.wireName}".'),
      );
    }

    final installer = _mcpInstallers?[id];
    final locator = _mcpLocator;
    if (installer == null || locator == null) {
      return FailureResult(
        ConflictFailure(
          'MCP installation is not supported for ${id.displayName}.',
        ),
      );
    }

    final current = _cache[id] ?? await detector.detect();
    final executablePath = current.executablePath;
    if (current.status == HarnessStatus.notInstalled ||
        executablePath == null) {
      return FailureResult(
        ConflictFailure('${id.displayName} CLI is not installed.'),
      );
    }

    final commandResult = locator.resolve();
    if (commandResult case FailureResult<HiveMcpLaunchCommand>(
      :final failure,
    )) {
      return FailureResult(failure);
    }
    final command = commandResult.valueOrNull!;

    final installResult = await installer.install(
      executablePath: executablePath,
      command: command,
    );
    if (installResult case FailureResult<void>(:final failure)) {
      return FailureResult(failure);
    }

    return await refreshOne(id);
  }

  @override
  Future<void> applyExecutableOverrides(
    Map<HarnessId, String> overrides, {
    bool triggerRefresh = true,
  }) async {
    final changedIds = <HarnessId>[];
    for (final entry in _detectors.entries) {
      final id = entry.key;
      final detector = entry.value;
      final raw = overrides[id]?.trim();
      final next = (raw == null || raw.isEmpty) ? null : raw;
      final prev = _overrides[id];
      if (prev != next) {
        _overrides[id] = next;
        detector.setExecutableOverride(next);
        changedIds.add(id);
      }
    }
    if (triggerRefresh && changedIds.isNotEmpty) {
      await Future.wait([for (final id in changedIds) refreshOne(id)]);
    }
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
    final detected = await Future.wait([
      for (final detector in detectors) detector.detect(),
    ]);
    final results = await Future.wait([
      for (final info in detected) _enrichMcpStatus(info),
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

  Future<HarnessInfo> _enrichMcpStatus(HarnessInfo info) async {
    final installers = _mcpInstallers;
    final locator = _mcpLocator;
    if (installers == null || locator == null) {
      return info;
    }

    if (info.status == HarnessStatus.notInstalled ||
        info.executablePath == null) {
      return info.copyWith(
        mcpStatus: HarnessMcpStatus.unsupported,
        mcpMessage: '${info.displayName} CLI is not installed.',
      );
    }

    final installer = installers[info.id];
    if (installer == null) {
      return info.copyWith(
        mcpStatus: HarnessMcpStatus.unsupported,
        mcpMessage:
            'MCP installation is not supported for ${info.displayName}.',
      );
    }

    final commandResult = locator.resolve();
    if (commandResult case FailureResult<HiveMcpLaunchCommand>(
      :final failure,
    )) {
      return info.copyWith(
        mcpStatus: HarnessMcpStatus.unknown,
        mcpMessage: failure.message,
      );
    }

    final detection = await installer.detect(
      executablePath: info.executablePath!,
      expectedCommand: commandResult.valueOrNull!,
    );
    return info.copyWith(
      mcpStatus: detection.status,
      mcpMessage: detection.message,
    );
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
        previous.errorMessage != next.errorMessage ||
        previous.mcpStatus != next.mcpStatus ||
        previous.mcpMessage != next.mcpMessage;
  }
}
