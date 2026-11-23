import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Domain service for registering, listing, renaming and unregistering
/// [Workspace]s (ADR 0022).
///
/// A workspace has exactly one root folder, unique across workspaces. Non-git
/// folders are valid. Unregistering never deletes files.
final class WorkspaceService {
  /// Creates a workspace service.
  new({
    required this._workspaces,
    required this._capabilities,
    String Function()? generateId,
    DateTime Function()? now,
    p.Context? pathContext,
  }) : _generateId = generateId ?? randomId,
       _now = now ?? _utcNow,
       _path = pathContext ?? p.context;

  static DateTime _utcNow() => DateTime.now().toUtc();

  final WorkspaceRepository _workspaces;
  final WorkspaceCapabilitiesService _capabilities;
  final String Function() _generateId;
  final DateTime Function() _now;
  final p.Context _path;

  /// Registers the folder in [request]; the name defaults to the folder name
  /// and git is auto-detected.
  Future<Result<Workspace>> create(CreateWorkspaceRequest request) async {
    final rootPath = _validateRoot(request.rootPath);
    if (rootPath case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }
    final root = rootPath.valueOrNull!;

    String name;
    final requestedName = request.name?.trim();
    if (requestedName == null) {
      name = _defaultName(root);
    } else if (requestedName.isEmpty) {
      return const FailureResult(
        ValidationFailure('Field "name" must not be blank.'),
      );
    } else {
      name = requestedName;
    }
    return await _register(root, name);
  }

  /// Lists every registered workspace.
  Future<Result<List<Workspace>>> list() => _workspaces.list();

  /// Loads workspace [id].
  Future<Result<Workspace>> get(String id) => _workspaces.getById(id);

  /// Renames workspace [id].
  Future<Result<Workspace>> rename(
    String id,
    UpdateWorkspaceRequest request,
  ) async {
    final name = request.name.trim();
    if (name.isEmpty) {
      return const FailureResult(
        ValidationFailure('Field "name" must not be blank.'),
      );
    }
    return await _workspaces.rename(id, name: name, updatedAt: _now());
  }

  /// Unregisters workspace [id]. Files and worktrees on disk are never
  /// touched; refused with a conflict while any of its runs is active.
  Future<Result<void>> unregister(String id) => _workspaces.delete(id);

  Future<Result<Workspace>> _register(String root, String name) async {
    final existing = await _findByRoot(root);
    if (existing case FailureResult<Workspace?>(:final failure)) {
      return FailureResult(failure);
    }
    if (existing.valueOrNull != null) {
      return FailureResult(
        ConflictFailure('A workspace is already registered for "$root".'),
      );
    }

    final capabilities = await _capabilities.getCapabilities(path: root);
    if (capabilities case FailureResult<WorkspaceCapabilities>(
      :final failure,
    )) {
      return FailureResult(failure);
    }
    final now = _now().toUtc();
    return await _workspaces.create(
      Workspace(
        id: _generateId(),
        name: name,
        rootPath: root,
        isGit: capabilities.valueOrNull!.isGitRepo,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<Result<Workspace?>> _findByRoot(String root) async {
    final all = await _workspaces.list();
    if (all case FailureResult<List<Workspace>>(:final failure)) {
      return FailureResult(failure);
    }
    final key = _canonical(root);
    for (final workspace in all.valueOrNull!) {
      if (_canonical(workspace.rootPath) == key) return Success(workspace);
    }
    return const Success(null);
  }

  Result<String> _validateRoot(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return const FailureResult(
        ValidationFailure('Field "rootPath" must not be blank.'),
      );
    }
    if (!_path.isAbsolute(trimmed)) {
      return const FailureResult(
        ValidationFailure('Field "rootPath" must be an absolute path.'),
      );
    }
    if (!Directory(trimmed).existsSync()) {
      return FailureResult(
        ValidationFailure('Folder "$trimmed" does not exist.'),
      );
    }
    return Success(_path.normalize(trimmed));
  }

  String _defaultName(String root) {
    final name = _path.basename(root);
    return name.isEmpty ? root : name;
  }

  String _canonical(String path) {
    try {
      final dir = Directory(path);
      if (dir.existsSync()) {
        return _path.canonicalize(dir.resolveSymbolicLinksSync());
      }
    } on FileSystemException {
      // Fall back to path canonicalization below.
    }
    return _path.canonicalize(path);
  }
}
