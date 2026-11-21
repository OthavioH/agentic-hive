import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Domain service for managing and validating [Workflow]s.
final class WorkflowService {
  /// Creates a workflow service.
  new({
    required this._repository,
    required this._validator,
    String Function()? generateId,
    DateTime Function()? now,
  }) : _generateId = generateId ?? randomId,
       _now = now ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  final WorkflowRepository _repository;
  final WorkflowValidator _validator;
  final String Function() _generateId;
  final DateTime Function() _now;

  /// Lists all saved workflows as summaries with their validation status.
  Future<Result<WorkflowListResponse>> listWorkflows() async {
    final result = await _repository.listAll();
    return result.map((workflows) {
      final summaries = workflows.map((workflow) {
        final validation = _validator.validate(workflow);
        return WorkflowSummary(
          id: workflow.id,
          name: workflow.name,
          description: workflow.description,
          nodeCount: workflow.nodes.length,
          edgeCount: workflow.edges.length,
          hasValidationErrors: !validation.isValid,
          updatedAt: workflow.updatedAt,
        );
      }).toList();
      return WorkflowListResponse(workflows: summaries);
    });
  }

  /// Fetches a workflow by [id] along with its validation result.
  Future<Result<WorkflowResponse>> getWorkflow(String id) async {
    final result = await _repository.getById(id);
    return result.map(
      (workflow) => WorkflowResponse(
        workflow: workflow,
        validation: _validator.validate(workflow),
      ),
    );
  }

  /// Creates and persists a new workflow (drafts with errors are allowed).
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async {
    final timestamp = _now().toUtc();
    final workflow = Workflow(
      id: _generateId(),
      name: request.name,
      description: request.description,
      nodes: request.nodes,
      edges: request.edges,
      entryNodeId: request.entryNodeId,
      schemaVersion: request.schemaVersion,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final result = await _repository.create(workflow);
    return result.map(
      (saved) => WorkflowResponse(
        workflow: saved,
        validation: _validator.validate(saved),
      ),
    );
  }

  /// Updates an existing workflow [id], refreshing `updatedAt`.
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request,
  ) async {
    final existingResult = await _repository.getById(id);
    if (existingResult case FailureResult<Workflow>(:final failure)) {
      return FailureResult(failure);
    }
    final existing = existingResult.valueOrNull!;
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
    final result = await _repository.update(updated);
    return result.map(
      (saved) => WorkflowResponse(
        workflow: saved,
        validation: _validator.validate(saved),
      ),
    );
  }

  /// Deletes the workflow with [id].
  Future<Result<void>> deleteWorkflow(String id) => _repository.delete(id);

  /// Clones an existing workflow [id] into a new workflow.
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
  }) async {
    final existingResult = await _repository.getById(id);
    if (existingResult case FailureResult<Workflow>(:final failure)) {
      return FailureResult(failure);
    }
    final existing = existingResult.valueOrNull!;
    final timestamp = _now().toUtc();
    final trimmedName = name?.trim();
    final copyName = (trimmedName != null && trimmedName.isNotEmpty)
        ? trimmedName
        : '${existing.name} (Copy)';
    final duplicated = Workflow(
      id: _generateId(),
      name: copyName,
      description: existing.description,
      nodes: existing.nodes,
      edges: existing.edges,
      entryNodeId: existing.entryNodeId,
      schemaVersion: existing.schemaVersion,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final result = await _repository.create(duplicated);
    return result.map(
      (saved) => WorkflowResponse(
        workflow: saved,
        validation: _validator.validate(saved),
      ),
    );
  }

  /// Validates [workflow] without persisting it.
  WorkflowValidationResult validateWorkflow(Workflow workflow) =>
      _validator.validate(workflow);
}
