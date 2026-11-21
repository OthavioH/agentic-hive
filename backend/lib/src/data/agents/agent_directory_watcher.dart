import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/agent_markdown_codec.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

/// Watches [agentsDir] for external `.md` file changes and broadcasts
/// `agents.changed` events to connected WebSocket clients.
final class AgentDirectoryWatcher {
  /// Creates a watcher for [agentsDir]; does not start until [start] is
  /// called.
  new({
    required this._agentsDir,
    required this._repository,
    required this._registry,
    this._debounceDuration = const Duration(milliseconds: 50),
    p.Context? pathContext,
    this._generateId = randomId,
  }) : _path = pathContext ?? p.context;

  static final _log = Logger('agents.watcher');

  String _agentsDir;

  /// Directory being watched for root-level `.md` files.
  String get agentsDir => _agentsDir;

  final AgentRepository _repository;
  final ConnectionRegistry _registry;
  final Duration _debounceDuration;
  final p.Context _path;
  final String Function() _generateId;

  DirectoryWatcher? _watcher;
  StreamSubscription<WatchEvent>? _subscription;
  final _pendingTimers = <String, Timer>{};
  final _pendingKinds = <String, AgentChangeKind>{};
  bool _closed = false;

  /// Completes once the underlying [DirectoryWatcher] is ready to emit events.
  Future<void> get ready => _watcher?.ready ?? Future<void>.value();

  /// Ensures [agentsDir] exists and begins watching for file changes.
  Future<void> start() async {
    if (_closed || _subscription != null) return;
    await Directory(agentsDir).create(recursive: true);

    final watcher = DirectoryWatcher(agentsDir);
    _watcher = watcher;
    _subscription = watcher.events.listen(
      _onWatchEvent,
      onError: (Object error, StackTrace stackTrace) => _log.warning(
        LogEvent('agents.watcher_error', fields: {'dir': agentsDir}),
        error,
        stackTrace,
      ),
    );
    await watcher.ready;
  }

  void _onWatchEvent(WatchEvent event) {
    if (_closed) return;
    if (!_path.equals(_path.dirname(event.path), _path.normalize(agentsDir))) {
      return;
    }
    if (_path.extension(event.path).toLowerCase() != '.md') return;

    final id = _path.basenameWithoutExtension(event.path);
    final kind = switch (event.type) {
      ChangeType.ADD => AgentChangeKind.created,
      ChangeType.MODIFY => AgentChangeKind.updated,
      ChangeType.REMOVE => AgentChangeKind.deleted,
      _ => null,
    };
    if (kind == null) return;

    final existing = _pendingKinds[id];
    if (existing == AgentChangeKind.created &&
        kind == AgentChangeKind.updated) {
      _pendingKinds[id] = AgentChangeKind.created;
    } else {
      _pendingKinds[id] = kind;
    }

    _pendingTimers[id]?.cancel();
    _pendingTimers[id] = Timer(_debounceDuration, () => _flush(id));
  }

  Future<void> _flush(String id) async {
    _pendingTimers.remove(id);
    final kind = _pendingKinds.remove(id);
    if (_closed || kind == null) return;

    final AgentsChangedPayload payload;
    if (kind == AgentChangeKind.deleted) {
      payload = AgentsChangedPayload(kind: AgentChangeKind.deleted, id: id);
    } else {
      final result = await _repository.getById(id);
      if (_closed) return;
      switch (result) {
        case Success(:final value):
          payload = AgentsChangedPayload(
            kind: kind,
            id: id,
            agent: AgentMarkdownCodec.toSummary(value),
          );
        case FailureResult():
          payload = AgentsChangedPayload(kind: AgentChangeKind.deleted, id: id);
      }
    }

    _registry.broadcast(
      WsEnvelope(
        type: WsMessageType.agentsChanged,
        id: _generateId(),
        payload: payload.toJson(),
      ),
    );
  }

  /// Stops watching and cancels any pending debounce timers.
  Future<void> close() async {
    _closed = true;
    await _stopWatching();
  }

  /// Switches the watcher to [newDir] without closing the instance.
  ///
  /// If the watcher has already been started, it stops watching the previous
  /// directory and starts watching [newDir].
  Future<void> switchDirectory(String newDir) async {
    if (_closed) return;
    if (_path.equals(_path.normalize(newDir), _path.normalize(_agentsDir))) {
      return;
    }
    final wasStarted = _subscription != null;
    await _stopWatching();
    _agentsDir = newDir;
    if (wasStarted) {
      await start();
    }
  }

  Future<void> _stopWatching() async {
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _pendingKinds.clear();
    await _subscription?.cancel();
    _subscription = null;
    _watcher = null;
  }
}
