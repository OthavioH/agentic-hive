import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/fan_out_reference_finder.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_registry.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_revision.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_runs_deleter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_slug.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';

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
    WorkflowDeletionRegistry? deletions,
    this._deletionEvents,
    String Function()? generateId,
    DateTime Function()? now,
  }) : _deletions = deletions ?? WorkflowDeletionRegistry(),
       _generateId = generateId ?? randomId,
       _now = now ?? _utcNow;

  static final _log = Logger('workflow_service');

  static DateTime _utcNow() => DateTime.now().toUtc();

  final WorkflowRepository _repository;
  final WorkflowValidator _validator;
  final WorkspaceWorkflowRepository? _workspaceWorkflows;
  final WorkspaceRepository? _workspaces;
  final WorkflowRunsDeleter? _runsDeleter;
  final WorkflowDeletionRegistry _deletions;
  final WorkflowDeletionEvents? _deletionEvents;
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
    if (result case FailureResult<Workflow>(:final failure)) {
      return FailureResult(failure);
    }
    return Success(await _response(result.valueOrNull!, workspaceId));
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
    if (_deletingFailure(id, workspaceId) case final failure?) {
      return FailureResult(failure);
    }
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
    if (result case FailureResult<Workflow>(:final failure)) {
      return FailureResult(failure);
    }
    return Success(await _response(result.valueOrNull!, workspaceId));
  });

  /// Accepts asynchronous deletion of the workflow [id] (ADR 0027).
  ///
  /// When [expectedRevision] is non-blank, fails with [StaleRevisionFailure]
  /// if the stored workflow's revision differs.
  Future<Result<WorkflowDeletionAccepted>> deleteWorkflow(
    String id, {
    String? workspaceId,
    String? expectedRevision,
    bool force = false,
  }) => _serialized(id, workspaceId, () async {
    final running = _deletions.runningFor(id, workspaceId: workspaceId);
    if (running != null) {
      return Success(
        WorkflowDeletionAccepted(operationId: running.id, workflowId: id),
      );
    }
    final existing = await _load(id, workspaceId);
    if (existing case FailureResult<Workflow>(:final failure)) {
      return FailureResult(failure);
    }
    if (_staleRevision(existing.valueOrNull!, expectedRevision)
        case final stale?) {
      return FailureResult(stale);
    }
    var activeRuns = <String, RunStatus>{};
    final runsDeleter = _runsDeleter;
    if (runsDeleter != null) {
      final active = await runsDeleter.activeRunsOfWorkflow(
        id,
        workspaceId: workspaceId,
      );
      if (active case FailureResult<Map<String, RunStatus>>(:final failure)) {
        return FailureResult(failure);
      }
      activeRuns = active.valueOrNull!;
      if (activeRuns.isNotEmpty && !force) {
        return FailureResult(
          WorkflowHasActiveRunsFailure(
            'Workflow "$id" has ${activeRuns.length} active run(s). '
            'Stop them, then delete it again.',
            activeRuns: activeRuns,
          ),
        );
      }
    }
    final referencesResult = await _referenceFinder.find(
      id,
      workspaceId: workspaceId,
    );
    if (referencesResult case FailureResult<List<WorkflowReference>>(
      :final failure,
    )) {
      return FailureResult(failure);
    }
    final phase = force && activeRuns.isNotEmpty
        ? WorkflowDeletionPhase.stoppingRuns
        : WorkflowDeletionPhase.deletingRuns;
    final operation = _deletions.start(
      WorkflowDeletionOperation(
        id: _generateId(),
        workflowId: id,
        workspaceId: workspaceId,
        phase: phase,
        runsToStop: force ? activeRuns.length : 0,
        startedAt: _now().toUtc(),
      ),
    );
    _deletionEvents?.progress(operation);
    unawaited(_runDeletion(operation.id, force: force));
    return Success(
      WorkflowDeletionAccepted(
        operationId: operation.id,
        workflowId: id,
        references: referencesResult.valueOrNull!,
      ),
    );
  });

  /// Lists the workflows whose fan-out nodes reference workflow [id] (R16).
  Future<Result<WorkflowReferencesResponse>> getReferences(
    String id, {
    String? workspaceId,
  }) async {
    final existing = await _load(id, workspaceId);
    if (existing case FailureResult<Workflow>(:final failure)) {
      return FailureResult(failure);
    }
    final found = await _referenceFinder.find(id, workspaceId: workspaceId);
    return found.map((refs) => WorkflowReferencesResponse(references: refs));
  }

  FanOutReferenceFinder get _referenceFinder => FanOutReferenceFinder(
    repository: _repository,
    workspaceWorkflows: _workspaceWorkflows,
    workspaces: _workspaces,
  );

  /// Returns the operation status or a not-found failure.
  Result<WorkflowDeletionOperation> getDeletion(String operationId) {
    final operation = _deletions.byId(operationId);
    if (operation != null) return Success(operation);
    return FailureResult(
      NotFoundFailure('Workflow deletion "$operationId" not found.'),
    );
  }

  /// Completes when an operation finishes, or null for an unknown id.
  Future<WorkflowDeletionOperation>? whenDeletionFinished(String operationId) =>
      _deletions.whenFinished(operationId);

  Future<void> _runDeletion(String operationId, {required bool force}) async {
    final operation = _deletions.byId(operationId);
    if (operation == null) return;
    var deletedRuns = 0;
    var orphanedRuns = const <String>[];
    try {
      final runsDeleter = _runsDeleter;
      if (runsDeleter != null) {
        final result = await runsDeleter.deleteRunsOfWorkflow(
          operation.workflowId,
          workspaceId: operation.workspaceId,
          force: force,
          onProgress: (p) => _onRunsProgress(operationId, p),
        );
        if (result case FailureResult<WorkflowRunsDeletion>(:final failure)) {
          _finish(
            operationId,
            deletedRuns: 0,
            orphanedRuns: const [],
            failure: failure,
          );
          return;
        }
        deletedRuns = result.valueOrNull!.deletedRuns;
        orphanedRuns = result.valueOrNull!.orphanedRuns;
      }
      _onRunsProgress(
        operationId,
        WorkflowRunsProgress(
          phase: WorkflowDeletionPhase.deletingRuns,
          runsDeleted: deletedRuns,
        ),
      );
      final deleted = await _deleteDefinition(
        operation.workflowId,
        operation.workspaceId,
      );
      if (deleted case FailureResult<void>(:final failure)) {
        _finish(
          operationId,
          deletedRuns: deletedRuns,
          orphanedRuns: orphanedRuns,
          failure: failure,
        );
        return;
      }
      _finish(
        operationId,
        deletedRuns: deletedRuns,
        orphanedRuns: orphanedRuns,
      );
    } on Object catch (error, stackTrace) {
      _log.warning(
        LogEvent(
          'workflows.delete_crashed',
          fields: {'operationId': operationId, 'error': '$error'},
        ),
        error,
        stackTrace,
      );
      _finish(
        operationId,
        deletedRuns: deletedRuns,
        orphanedRuns: orphanedRuns,
        failure: UnexpectedFailure(
          'Workflow deletion failed unexpectedly.',
          cause: error,
        ),
      );
    }
  }

  Future<Result<void>> _deleteDefinition(String id, String? workspaceId) async {
    if (workspaceId == null) return await _repository.delete(id);
    final target = await _resolveTarget(workspaceId);
    if (target case FailureResult<_Target>(:final failure)) {
      return FailureResult(failure);
    }
    final scoped = target.valueOrNull!;
    return await scoped.repository.delete(scoped.rootPath, id);
  }

  void _onRunsProgress(String operationId, WorkflowRunsProgress progress) {
    final updated = _deletions.update(
      operationId,
      (current) => progress.phase == WorkflowDeletionPhase.stoppingRuns
          ? current.copyWith(
              phase: progress.phase,
              runsToStop: progress.runsToStop,
              runsStopped: progress.runsStopped,
            )
          : current.copyWith(
              phase: progress.phase,
              runsDeleted: progress.runsDeleted,
            ),
    );
    _deletionEvents?.progress(updated);
  }

  void _finish(
    String operationId, {
    required int deletedRuns,
    required List<String> orphanedRuns,
    Failure? failure,
  }) {
    final updated = _deletions.update(
      operationId,
      (current) => current.copyWith(
        phase: WorkflowDeletionPhase.done,
        outcome: failure == null
            ? WorkflowDeletionOutcome.deleted
            : WorkflowDeletionOutcome.failed,
        runsDeleted: deletedRuns,
        orphanedRuns: orphanedRuns,
        failure: failure,
        finishedAt: _now().toUtc(),
      ),
    );
    _deletionEvents?.progress(updated);
    if (failure == null) {
      _deletionEvents?.deleted(updated);
    } else {
      _deletionEvents?.failed(updated);
    }
  }

  /// Clones an existing workflow [id] into a new workflow of the same scope.
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) async {
    if (_deletingFailure(id, workspaceId) case final failure?) {
      return FailureResult(failure);
    }
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
    if (result case FailureResult<Workflow>(:final failure)) {
      return FailureResult(failure);
    }
    return Success(await _response(result.valueOrNull!, workspaceId));
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
      deleting:
          _deletions.runningFor(workflow.id, workspaceId: workspaceId) != null,
    );
  }

  WorkflowDeletingFailure? _deletingFailure(String id, String? workspaceId) {
    final operation = _deletions.runningFor(id, workspaceId: workspaceId);
    return operation == null
        ? null
        : WorkflowDeletingFailure(
            'Workflow "$id" is being deleted.',
            operationId: operation.id,
          );
  }

  Future<WorkflowResponse> _response(
    Workflow workflow,
    String? workspaceId,
  ) async {
    final base = _validator.validate(workflow);
    final extra = await _fanOutIssues(workflow, workspaceId);
    final issues = [...base.issues, ...extra];
    return WorkflowResponse(
      workflow: workflow,
      validation: WorkflowValidationResult(
        isValid: !issues.any(
          (i) => i.severity == WorkflowValidationSeverity.error,
        ),
        issues: issues,
      ),
      scope: workspaceId == null
          ? WorkflowScope.global
          : WorkflowScope.workspace,
      workspaceId: workspaceId,
      revision: workflowRevision(workflow),
    );
  }

  Future<List<WorkflowValidationIssue>> _fanOutIssues(
    Workflow workflow,
    String? workspaceId,
  ) async {
    final childIds = {
      for (final n in workflow.nodes)
        if (n.type == NodeTypeId.fanOut && n.config['workflowId'] is String)
          (n.config['workflowId']! as String).trim(),
    }..remove('');
    if (childIds.isEmpty) return const [];
    final found = <String, Workflow>{};
    for (final id in childIds) {
      final child = await _resolveChild(id, workspaceId);
      if (child != null) found[id] = child;
    }
    return FanOutValidation.validate(workflow, findWorkflow: (id) => found[id]);
  }

  Future<Workflow?> _resolveChild(String id, String? workspaceId) async {
    if (workspaceId != null) {
      final target = await _resolveTarget(workspaceId);
      final scoped = target.valueOrNull;
      if (scoped != null) {
        final inWorkspace = await scoped.repository.getById(
          scoped.rootPath,
          id,
        );
        if (inWorkspace case Success<Workflow>(:final value)) return value;
      }
    }
    return (await _repository.getById(id)).valueOrNull;
  }

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
