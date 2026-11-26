import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/watching/debounced_folder_watcher.dart';
import 'package:agentic_hive_backend/src/data/workflows/file_workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_revision.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Watches `<root>/.agentic-hive/workflows` of every registered workspace and
/// broadcasts `workflows.changed` events when files change on disk (for
/// example after a `git pull`), so connected clients refresh live.
///
/// The workflows folder is not created by the watcher. A periodic rescan
/// (every two seconds by default) starts watching folders that appear later and
/// stops watching workspaces that were unregistered.
final class WorkspaceWorkflowWatcher {
  /// Creates a watcher; nothing is watched until [start] is called.
  new({
    required this._workspaces,
    required this._repository,
    required this._validator,
    required this._registry,
    this._debounceDuration = const Duration(milliseconds: 50),
    this._rescanInterval = const Duration(seconds: 2),
    p.Context? pathContext,
    String Function()? generateId,
  }) : _path = pathContext ?? p.context,
       _generateId = generateId ?? randomId;

  static final _log = Logger('workflows.watcher');

  final WorkspaceRepository _workspaces;
  final WorkspaceWorkflowRepository _repository;
  final WorkflowValidator _validator;
  final ConnectionRegistry _registry;
  final Duration _debounceDuration;
  final Duration _rescanInterval;
  final p.Context _path;
  final String Function() _generateId;

  final _watched =
      <String, ({String rootPath, DebouncedFolderWatcher folder})>{};
  Timer? _rescanTimer;
  bool _closed = false;
  Future<void>? _syncing;

  /// Begins watching and rescans periodically.
  Future<void> start() async {
    if (_closed || _rescanTimer != null) return;
    _rescanTimer = Timer.periodic(_rescanInterval, (_) => unawaited(sync()));
    await sync();
  }

  /// Reconciles the watched folders with the registered workspaces.
  ///
  /// Call it after registering a workspace or creating its first workflow so
  /// the new folder is watched without waiting for the next rescan.
  Future<void> sync() {
    if (_closed) return Future<void>.value();
    return _syncing ??= _sync().whenComplete(() => _syncing = null);
  }

  Future<void> _sync() async {
    final listed = await _workspaces.list();
    if (listed case FailureResult<List<Workspace>>(:final failure)) {
      _log.warning(
        LogEvent(
          'workflows.watcher_list_failed',
          fields: {'failure': '$failure'},
        ),
      );
      return;
    }
    final current = {for (final w in listed.valueOrNull!) w.id: w};

    for (final id in _watched.keys.toList()) {
      final stillRegistered = current[id];
      if (stillRegistered == null ||
          stillRegistered.rootPath != _watched[id]!.rootPath) {
        await _watched.remove(id)?.folder.close();
      }
    }
    for (final workspace in current.values) {
      if (_closed || _watched.containsKey(workspace.id)) continue;
      final directory = FileWorkspaceWorkflowRepository.workflowsDirectory(
        workspace.rootPath,
        pathContext: _path,
      );
      if (!Directory(directory).existsSync()) continue;
      final folder = DebouncedFolderWatcher(
        directory: directory,
        extensions: const {'.json'},
        debounce: _debounceDuration,
        pathContext: _path,
        onChange: (path, kind) => unawaited(
          _flush(workspace, _path.basenameWithoutExtension(path), kind),
        ),
        onError: (error, stackTrace) => _log.warning(
          LogEvent(
            'workflows.watcher_error',
            fields: {'workspaceId': workspace.id},
          ),
          error,
          stackTrace,
        ),
      );
      _watched[workspace.id] = (rootPath: workspace.rootPath, folder: folder);
      await folder.ready;
    }
  }

  Future<void> _flush(
    Workspace workspace,
    String id,
    FolderChangeKind folderKind,
  ) async {
    if (_closed) return;
    final kind = switch (folderKind) {
      FolderChangeKind.created => WorkflowChangeKind.created,
      FolderChangeKind.updated => WorkflowChangeKind.updated,
      FolderChangeKind.deleted => WorkflowChangeKind.deleted,
    };

    final WorkflowsChangedPayload payload;
    if (kind == WorkflowChangeKind.deleted) {
      payload = WorkflowsChangedPayload(
        kind: kind,
        id: id,
        workspaceId: workspace.id,
      );
    } else {
      final result = await _repository.getById(workspace.rootPath, id);
      if (_closed) return;
      payload = switch (result) {
        Success<Workflow>(:final value) => WorkflowsChangedPayload(
          kind: kind,
          id: id,
          workspaceId: workspace.id,
          workflow: WorkflowSummary(
            id: value.id,
            name: value.name,
            description: value.description,
            nodeCount: value.nodes.length,
            edgeCount: value.edges.length,
            hasValidationErrors: !_validator.validate(value).isValid,
            updatedAt: value.updatedAt,
            scope: WorkflowScope.workspace,
            workspaceId: workspace.id,
            revision: workflowRevision(value),
          ),
        ),
        // An unreadable or half-written file is not listed, so clients treat
        // it as gone until it becomes valid again.
        FailureResult<Workflow>() => WorkflowsChangedPayload(
          kind: WorkflowChangeKind.deleted,
          id: id,
          workspaceId: workspace.id,
        ),
      };
    }
    _registry.broadcast(
      WsEnvelope(
        type: WsMessageType.workflowsChanged,
        id: _generateId(),
        payload: payload.toJson(),
      ),
    );
  }

  /// Stops watching and cancels pending timers.
  Future<void> close() async {
    _closed = true;
    _rescanTimer?.cancel();
    _rescanTimer = null;
    for (final watched in _watched.values) {
      await watched.folder.close();
    }
    _watched.clear();
  }
}
