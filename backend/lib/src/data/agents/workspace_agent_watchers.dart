import 'dart:io';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/agent_directory_watcher.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Keeps one [AgentDirectoryWatcher] per registered workspace so external
/// edits to `<root>/.agents/agents` (for example after `git pull`) reach the
/// app live (ADR 0025).
///
/// Call [sync] at startup and whenever workspaces or their agent folders
/// change. A workspace whose agents folder does not exist yet is skipped: the
/// folder is never created just to be watched.
final class WorkspaceAgentWatchers {
  /// Creates the manager.
  new({
    required this._listWorkspaces,
    required this._repositoryFor,
    required this._registry,
    this._debounceDuration = const Duration(milliseconds: 50),
    p.Context? pathContext,
  }) : _path = pathContext ?? p.context;

  static final _log = Logger('agents.workspace_watchers');

  final Future<Result<List<Workspace>>> Function() _listWorkspaces;
  final AgentRepository Function(String workspaceRoot) _repositoryFor;
  final ConnectionRegistry _registry;
  final Duration _debounceDuration;
  final p.Context _path;

  final _watchers = <String, AgentDirectoryWatcher>{};
  final _roots = <String, String>{};
  Future<void> _queue = Future<void>.value();
  bool _closed = false;

  /// Identifiers of the workspaces currently being watched.
  Set<String> get watchedWorkspaceIds => _watchers.keys.toSet();

  /// Reconciles the running watchers with the registered workspaces.
  ///
  /// Concurrent calls are serialized.
  Future<void> sync() {
    final next = _queue.then((_) => _sync());
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _sync() async {
    if (_closed) return;
    final listed = await _listWorkspaces();
    if (listed case FailureResult<List<Workspace>>(:final failure)) {
      _log.warning(
        LogEvent(
          'agents.workspace_watchers_list_failed',
          fields: {'failure': failure.message},
        ),
      );
      return;
    }
    final workspaces = listed.valueOrNull!;
    final wanted = {for (final w in workspaces) w.id: w.rootPath};

    for (final id in _watchers.keys.toList()) {
      if (wanted[id] != _roots[id]) {
        await _watchers.remove(id)?.close();
        _roots.remove(id);
      }
    }
    for (final MapEntry(key: id, value: root) in wanted.entries) {
      if (_closed || _watchers.containsKey(id)) continue;
      final dir = _path.join(root, '.agents', 'agents');
      if (!Directory(dir).existsSync()) continue;
      final watcher = AgentDirectoryWatcher(
        agentsDir: dir,
        repository: _repositoryFor(root),
        registry: _registry,
        workspaceId: id,
        debounceDuration: _debounceDuration,
        pathContext: _path,
      );
      try {
        await watcher.start(createDirectory: false);
      } on FileSystemException catch (e, st) {
        _log.warning(
          LogEvent('agents.workspace_watcher_start_failed', fields: {'id': id}),
          e,
          st,
        );
        await watcher.close();
        continue;
      }
      _watchers[id] = watcher;
      _roots[id] = root;
    }
  }

  /// Stops every watcher.
  Future<void> close() async {
    _closed = true;
    await _queue;
    for (final watcher in _watchers.values) {
      await watcher.close();
    }
    _watchers.clear();
    _roots.clear();
  }
}
