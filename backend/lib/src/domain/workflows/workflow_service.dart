import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_revision.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_runs_deleter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_slug.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Domain service for managing and validating [Workflow]s.
///
/// Workflows are global (SQLite) or workspace-scoped (files under the
/// workspace root, ADR 0025). Every operation takes an optional `workspaceId`:
/// `null` addresses the global scope.
final class WorkflowService {
  /// Creates a workflow service.
  ///
  /// Without a workspace workflow repository and a workspace repository only
  /// the global scope is available and any `workspaceId` is answered with
  /// `NotFoundFailure`. Without a runs deleter the workflow's runs are kept
  /// (tests only).
  new({
    required this._repository,
    required this._validator,
    this._workspaceWorkflows,
    this._workspaces,
    this._runsDeleter,
    String Function()? generateId,
    DateTime Function()? now,
  }) : _generateId = generateId ?? randomId,
       _now = now ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  final WorkflowRepository _repository;
  final WorkflowValidator _validator;
  final WorkspaceWorkflowRepository? _workspaceWorkflows;
  final WorkspaceRepository? _workspaces;
  final WorkflowRunsDeleter? _runsDeleter;
  final String Function() _generateId;
  final DateTime Function() _now;
  final Map<String, Future<void>> _writeQueue = <String, Future<void>>{};

  /// Lists global workflows, plus the ones of [workspaceId] when given, as
  /// summaries with their validation status. Same-named workflows from both
  /// scopes are all listed; each summary carries its scope.
  Future<Result<WorkflowListResponse>> listWorkflows({
    String? workspaceId,
  }) async {
    final globals = await _repository.listAll();
    if (globals case FailureResult<List<Workflow>>(:final failure)) {
      return FailureResult(failure);
    }
    final summaries = <WorkflowSummary>[
      for (final workflow in globals.valueOrNull!)
        _summary(workflow, WorkflowScope.global, null),
    ];
    if (workspaceId != null) {
      final target = await _resolveTarget(workspaceId);
      if (target case FailureResult<_Target>(:final failure)) {
        return FailureResult(failure);
      }
      final scoped = target.valueOrNull!;
      final files = await scoped.repository.listAll(scoped.rootPath);
      if (files case FailureResult<List<Workflow>>(:final failure)) {
        return FailureResult(failure);
      }
      summaries.addAll([
        for (final workflow in files.valueOrNull!)
          _summary(workflow, WorkflowScope.workspace, workspaceId),
      ]);
    }
    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Success(WorkflowListResponse(workflows: summaries));
  }

  /// Fetches a workflow by [id] along with its validation result.
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  }) async {
    final result = await _load(id, workspaceId);
    return result.map((workflow) => _response(workflow, workspaceId));
  }

  /// Creates and persists a new workflow in the scope named by
  /// `request.workspaceId` (drafts with errors are allowed).
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) {
    final timestamp = _now().toUtc();
    return _persistNew(
      request.name,
      request.workspaceId,
      (id) => Workflow(
        id: id,
        name: request.name,
        description: request.description,
        nodes: request.nodes,
        edges: request.edges,
        entryNodeId: request.entryNodeId,
        schemaVersion: request.schemaVersion,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }

  /// Updates an existing workflow [id], refreshing `updatedAt`.
  ///
  /// When `request.revision` is non-blank, fails with [StaleRevisionFailure]
  /// if the stored workflow's revision differs.
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) => _serialized(id, workspaceId, () async {
    final existingResult = await _load(id, workspaceId);
    if (existingResult case FailureResult<Workflow>(:final failure)) {
      return FailureResult(failure);
    }
    final existing = existingResult.valueOrNull!;
    if (_staleRevision(existing, request.revision) case final stale?) {
      return FailureResult(stale);
    }
    final updated = Workflow(
      id: existing.id,
      name: request.name,
      description: request.description,
      nodes: request.nodes,
      edges: request.edges,
      entryNodeId: request.entryNodeId,
      schemaVersion: request.schemaVersion,
      createdAt: existing.createdAt,
      updatedAt: _now().toUtc(),
    );
    final Result<Workflow> result;
    if (workspaceId == null) {
      result = await _repository.update(updated);
    } else {
      final target = await _resolveTarget(workspaceId);
      if (target case FailureResult<_Target>(:final failure)) {
        return FailureResult(failure);
      }
      final scoped = target.valueOrNull!;
      result = await scoped.repository.update(scoped.rootPath, updated);
    }
    return result.map((saved) => _response(saved, workspaceId));
  });

  /// Deletes the workflow [id] and every run of it (#103): runs first, in one
  /// transaction that refuses with [WorkflowHasActiveRunsFailure] when any is
  /// active, then the workflow. Worktrees and workspace files are kept.
  ///
  /// When [expectedRevision] is non-blank, fails with [StaleRevisionFailure]
  /// if the stored workflow's revision differs.
  Future<Result<DeleteWorkflowResponse>> deleteWorkflow(
    String id, {
    String? workspaceId,
    String? expectedRevision,
  }) => _serialized(id, workspaceId, () async {
    final existing = await _load(id, workspaceId);
    if (existing case FailureResult<Workflow>(:final failure)) {
      return FailureResult(failure);
    }
    if (_staleRevision(existing.valueOrNull!, expectedRevision)
        case final stale?) {
      return FailureResult(stale);
    }
    var deletedRuns = 0;
    final runsDeleter = _runsDeleter;
    if (runsDeleter != null) {
      final runs = await runsDeleter.deleteRunsOfWorkflow(
        id,
        workspaceId: workspaceId,
      );
      if (runs case FailureResult<int>(:final failure)) {
        return FailureResult(failure);
      }
      deletedRuns = runs.valueOrNull!;
    }
    final Result<void> deleted;
    if (workspaceId == null) {
      deleted = await _repository.delete(id);
    } else {
      final target = await _resolveTarget(workspaceId);
      if (target case FailureResult<_Target>(:final failure)) {
        return FailureResult(failure);
      }
      final scoped = target.valueOrNull!;
      deleted = await scoped.repository.delete(scoped.rootPath, id);
    }
    return deleted.map(
      (_) => DeleteWorkflowResponse(id: id, deletedRuns: deletedRuns),
    );
  });

  /// Clones an existing workflow [id] into a new workflow of the same scope.
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) async {
    final existingResult = await _load(id, workspaceId);
    if (existingResult case FailureResult<Workflow>(:final failure)) {
      return FailureResult(failure);
    }
    final existing = existingResult.valueOrNull!;
    final timestamp = _now().toUtc();
    final trimmedName = name?.trim();
    final copyName = (trimmedName != null && trimmedName.isNotEmpty)
        ? trimmedName
        : '${existing.name} (Copy)';
    return await _persistNew(
      copyName,
      workspaceId,
      (newId) => Workflow(
        id: newId,
        name: copyName,
        description: existing.description,
        nodes: existing.nodes,
        edges: existing.edges,
        entryNodeId: existing.entryNodeId,
        schemaVersion: existing.schemaVersion,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }

  /// Validates [workflow] without persisting it.
  WorkflowValidationResult validateWorkflow(Workflow workflow) =>
      _validator.validate(workflow);

  Future<Result<WorkflowResponse>> _persistNew(
    String name,
    String? workspaceId,
    Workflow Function(String id) build,
  ) async {
    final Result<Workflow> result;
    if (workspaceId == null) {
      result = await _repository.create(build(_generateId()));
    } else {
      final target = await _resolveTarget(workspaceId);
      if (target case FailureResult<_Target>(:final failure)) {
        return FailureResult(failure);
      }
      final scoped = target.valueOrNull!;
      final base = slugifyWorkflowName(name);
      var candidate = base;
      var suffix = 1;
      while (await _exists(scoped, candidate)) {
        suffix += 1;
        candidate = '$base-$suffix';
      }
      result = await scoped.repository.create(
        scoped.rootPath,
        build(candidate),
      );
    }
    return result.map((saved) => _response(saved, workspaceId));
  }

  Future<bool> _exists(_Target target, String id) async =>
      (await target.repository.getById(target.rootPath, id)) is Success;

  Future<Result<Workflow>> _load(String id, String? workspaceId) async {
    if (workspaceId == null) return await _repository.getById(id);
    final target = await _resolveTarget(workspaceId);
    if (target case FailureResult<_Target>(:final failure)) {
      return FailureResult(failure);
    }
    final scoped = target.valueOrNull!;
    return await scoped.repository.getById(scoped.rootPath, id);
  }

  Future<Result<_Target>> _resolveTarget(String workspaceId) async {
    final repository = _workspaceWorkflows;
    final workspaces = _workspaces;
    if (repository == null || workspaces == null) {
      return FailureResult(
        NotFoundFailure('Workspace "$workspaceId" not found.'),
      );
    }
    final workspace = await workspaces.getById(workspaceId);
    return workspace.map(
      (found) => _Target(repository: repository, rootPath: found.rootPath),
    );
  }

  WorkflowSummary _summary(
    Workflow workflow,
    WorkflowScope scope,
    String? workspaceId,
  ) {
    final validation = _validator.validate(workflow);
    return WorkflowSummary(
      id: workflow.id,
      name: workflow.name,
      description: workflow.description,
      nodeCount: workflow.nodes.length,
      edgeCount: workflow.edges.length,
      hasValidationErrors: !validation.isValid,
      updatedAt: workflow.updatedAt,
      scope: scope,
      workspaceId: workspaceId,
      revision: workflowRevision(workflow),
    );
  }

  WorkflowResponse _response(Workflow workflow, String? workspaceId) =>
      WorkflowResponse(
        workflow: workflow,
        validation: _validator.validate(workflow),
        scope: workspaceId == null
            ? WorkflowScope.global
            : WorkflowScope.workspace,
        workspaceId: workspaceId,
        revision: workflowRevision(workflow),
      );

  /// Runs [action] after every earlier write to the same workflow finished.
  Future<T> _serialized<T>(
    String id,
    String? workspaceId,
    Future<T> Function() action,
  ) async {
    final key = '${workspaceId ?? ''}\u0000$id';
    final previous = _writeQueue[key] ?? Future<void>.value();
    final done = Completer<void>();
    _writeQueue[key] = done.future;
    try {
      await previous;
      return await action();
    } finally {
      done.complete();
      if (identical(_writeQueue[key], done.future)) {
        unawaited(_writeQueue.remove(key));
      }
    }
  }

  /// `null` when [expected] is absent/blank or matches [current]; otherwise
  /// the stale-revision failure.
  StaleRevisionFailure? _staleRevision(Workflow current, String? expected) {
    final trimmed = expected?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final actual = workflowRevision(current);
    if (actual == trimmed) return null;
    return StaleRevisionFailure(
      'Workflow "${current.id}" changed since it was read. '
      'Read it again and reapply your change.',
      currentRevision: actual,
    );
  }
}

final class _Target {
  const new({required this.repository, required this.rootPath});

  final WorkspaceWorkflowRepository repository;
  final String rootPath;
}
