import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workflow_editor_controller.g.dart';

/// Request emitted when the canvas should smoothly pan/focus onto a target
/// graph coordinate.
@immutable
final class EditorFocusRequest {
  /// Creates an [EditorFocusRequest].
  const new({required this.sequence, required this.x, required this.y});

  /// Monotonically increasing sequence number so repeated clicks still fire.
  final int sequence;

  /// Target canvas X coordinate.
  final double x;

  /// Target canvas Y coordinate.
  final double y;
}

/// View state for the workflow graph editor.
@immutable
final class WorkflowEditorState {
  /// Creates a [WorkflowEditorState].
  const new({
    required this.workflow,
    required this.savedWorkflow,
    required this.validation,
    this.selectedNodeId,
    this.selectedEdgeId,
    this.isSaving = false,
    this.isValidating = false,
    this.saveFailure,
    this.focusRequest,
  });

  /// Current editable workflow draft.
  final Workflow workflow;

  /// Last persisted workflow snapshot used to compute [isDirty].
  final Workflow savedWorkflow;

  /// Latest validation result from the backend.
  final WorkflowValidationResult validation;

  /// Currently selected node ID, if any.
  final String? selectedNodeId;

  /// Currently selected edge ID, if any.
  final String? selectedEdgeId;

  /// Whether a save request is currently in flight.
  final bool isSaving;

  /// Whether a validation request is currently in flight.
  final bool isValidating;

  /// Failure from the most recent failed save attempt.
  final Failure? saveFailure;

  /// Latest pan/focus target requested by clicking a validation issue.
  final EditorFocusRequest? focusRequest;

  /// Whether [workflow] has unsaved local edits compared to [savedWorkflow].
  bool get isDirty {
    return workflow.name != savedWorkflow.name ||
        (workflow.description ?? '') != (savedWorkflow.description ?? '') ||
        workflow.entryNodeId != savedWorkflow.entryNodeId ||
        !listEquals(workflow.nodes, savedWorkflow.nodes) ||
        !listEquals(workflow.edges, savedWorkflow.edges);
  }

  /// Selected [WorkflowNode], or `null` when none is selected.
  WorkflowNode? get selectedNode {
    final id = selectedNodeId;
    if (id == null) return null;
    for (final node in workflow.nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// Selected [WorkflowEdge], or `null` when none is selected.
  WorkflowEdge? get selectedEdge {
    final id = selectedEdgeId;
    if (id == null) return null;
    for (final edge in workflow.edges) {
      if (edge.id == id) return edge;
    }
    return null;
  }

  /// Returns a copy with updated fields.
  WorkflowEditorState copyWith({
    Workflow? workflow,
    Workflow? savedWorkflow,
    WorkflowValidationResult? validation,
    String? Function()? selectedNodeId,
    String? Function()? selectedEdgeId,
    bool? isSaving,
    bool? isValidating,
    Failure? Function()? saveFailure,
    EditorFocusRequest? Function()? focusRequest,
  }) {
    return WorkflowEditorState(
      workflow: workflow ?? this.workflow,
      savedWorkflow: savedWorkflow ?? this.savedWorkflow,
      validation: validation ?? this.validation,
      selectedNodeId: selectedNodeId != null
          ? selectedNodeId()
          : this.selectedNodeId,
      selectedEdgeId: selectedEdgeId != null
          ? selectedEdgeId()
          : this.selectedEdgeId,
      isSaving: isSaving ?? this.isSaving,
      isValidating: isValidating ?? this.isValidating,
      saveFailure: saveFailure != null ? saveFailure() : this.saveFailure,
      focusRequest: focusRequest != null ? focusRequest() : this.focusRequest,
    );
  }
}

/// Manages editing, selection, validation, and saving of a single workflow.
@riverpod
class WorkflowEditorController extends _$WorkflowEditorController {
  int _idCounter = 0;
  int _validationSeq = 0;
  int _focusSeq = 0;
  String? _workspaceId;

  /// Loads [workflowId] from the scope of [workspaceId]; `null` is the global
  /// scope. Saving writes back to the same scope.
  @override
  Future<WorkflowEditorState> build(
    String workflowId, {
    String? workspaceId,
  }) async {
    _workspaceId = workspaceId;
    final result = await ref
        .read(getWorkflowProvider)
        .call(workflowId, workspaceId: workspaceId);
    return switch (result) {
      Success<WorkflowResponse>(:final value) => WorkflowEditorState(
        workflow: value.workflow,
        savedWorkflow: value.workflow,
        validation: value.validation,
      ),
      FailureResult<WorkflowResponse>(:final failure) =>
        Error.throwWithStackTrace(failure, StackTrace.current),
    };
  }

  /// Selects a node and clears any edge selection.
  void selectNode(String? nodeId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        selectedNodeId: () => nodeId,
        selectedEdgeId: () => null,
      ),
    );
  }

  /// Selects an edge and clears any node selection.
  void selectEdge(String? edgeId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        selectedNodeId: () => null,
        selectedEdgeId: () => edgeId,
      ),
    );
  }

  /// Clears node and edge selection so the workflow inspector is shown.
  void clearSelection() {
    final current = state.asData?.value;
    if (current == null) return;
    if (current.selectedNodeId == null && current.selectedEdgeId == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(selectedNodeId: () => null, selectedEdgeId: () => null),
    );
  }

  /// Updates the workflow's name and/or description.
  void updateWorkflowMetadata({String? name, String? description}) {
    final current = state.asData?.value;
    if (current == null) return;
    final nextWorkflow = current.workflow.copyWith(
      name: name ?? current.workflow.name,
      description: description ?? current.workflow.description,
    );
    _applyDraft(current, nextWorkflow, revalidate: name != null);
  }

  /// Adds a typed node to the canvas using defaults from [NodeDescriptors]
  /// and selects it.
  ///
  /// When the workflow has no nodes yet (or no `entryNodeId`), the new node
  /// automatically becomes the entry node.
  void addNode({
    required String typeId,
    required String defaultLabel,
    double? x,
    double? y,
  }) {
    final current = state.asData?.value;
    if (current == null) return;

    final existingIds = current.workflow.nodes.map((n) => n.id).toSet();
    final id = _nextUniqueId('node', existingIds);
    final index = current.workflow.nodes.length;
    final position = WorkflowPosition(
      x: x ?? 120.0 + (index % 4) * 260.0,
      y: y ?? 120.0 + (index ~/ 4) * 180.0,
    );
    final descriptor = NodeDescriptors.of(typeId);

    final newNode = WorkflowNode(
      id: id,
      type: typeId,
      label: defaultLabel,
      config: descriptor?.defaultConfig() ?? const <String, Object?>{},
      position: position,
    );
    final nextNodes = <WorkflowNode>[...current.workflow.nodes, newNode];
    final nextEntry =
        current.workflow.nodes.isEmpty || current.workflow.entryNodeId == null
        ? id
        : current.workflow.entryNodeId;
    final nextWorkflow = current.workflow.copyWith(
      nodes: nextNodes,
      entryNodeId: nextEntry,
    );
    _applyDraft(
      current,
      nextWorkflow,
      selectedNodeId: () => id,
      selectedEdgeId: () => null,
    );
  }

  /// Moves a node by ([dx], [dy]) in canvas coordinates.
  void moveNode(String nodeId, double dx, double dy) {
    final current = state.asData?.value;
    if (current == null) return;
    final nextNodes = <WorkflowNode>[
      for (final node in current.workflow.nodes)
        if (node.id == nodeId)
          node.copyWith(
            position: WorkflowPosition(
              x: (node.position.x + dx).clamp(0.0, 4000.0),
              y: (node.position.y + dy).clamp(0.0, 4000.0),
            ),
          )
        else
          node,
    ];
    _applyDraft(
      current,
      current.workflow.copyWith(nodes: nextNodes),
      revalidate: false,
    );
  }

  /// Updates a node's display label.
  void updateNodeLabel(String nodeId, String label) {
    final current = state.asData?.value;
    if (current == null) return;
    final nextNodes = <WorkflowNode>[
      for (final node in current.workflow.nodes)
        if (node.id == nodeId) node.copyWith(label: label) else node,
    ];
    _applyDraft(
      current,
      current.workflow.copyWith(nodes: nextNodes),
      revalidate: false,
    );
  }

  /// Updates a node's typed configuration map and triggers revalidation.
  void updateNodeConfig(String nodeId, JsonMap config) {
    final current = state.asData?.value;
    if (current == null) return;
    final nextNodes = <WorkflowNode>[
      for (final node in current.workflow.nodes)
        if (node.id == nodeId) node.copyWith(config: config) else node,
    ];
    _applyDraft(current, current.workflow.copyWith(nodes: nextNodes));
  }

  /// Toggles whether [nodeId] is the workflow's `entryNodeId`.
  void setEntryNode(String nodeId, {required bool isEntry}) {
    final current = state.asData?.value;
    if (current == null) return;
    final nextEntry = isEntry
        ? nodeId
        : (current.workflow.entryNodeId == nodeId
              ? null
              : current.workflow.entryNodeId);
    _applyDraft(current, current.workflow.copyWith(entryNodeId: nextEntry));
  }

  /// Deletes [nodeId] and all edges connected to it.
  void deleteNode(String nodeId) {
    final current = state.asData?.value;
    if (current == null) return;
    final nextNodes = current.workflow.nodes
        .where((node) => node.id != nodeId)
        .toList();
    final nextEdges = current.workflow.edges
        .where(
          (edge) => edge.sourceNodeId != nodeId && edge.targetNodeId != nodeId,
        )
        .toList();
    final nextEntry = current.workflow.entryNodeId == nodeId
        ? null
        : current.workflow.entryNodeId;
    final clearSelectedEdge =
        current.selectedEdgeId != null &&
        !nextEdges.any((edge) => edge.id == current.selectedEdgeId);

    _applyDraft(
      current,
      current.workflow.copyWith(
        nodes: nextNodes,
        edges: nextEdges,
        entryNodeId: nextEntry,
      ),
      selectedNodeId: current.selectedNodeId == nodeId ? () => null : null,
      selectedEdgeId: clearSelectedEdge ? () => null : null,
    );
  }

  /// Adds a directed edge from [sourceNodeId] to [targetNodeId] and selects it.
  void addEdge({
    required String sourceNodeId,
    required String targetNodeId,
    String sourceOutput = 'onSuccess',
  }) {
    final current = state.asData?.value;
    if (current == null) return;
    final existingIds = current.workflow.edges.map((e) => e.id).toSet();
    final id = _nextUniqueId('edge', existingIds);
    final edge = WorkflowEdge(
      id: id,
      sourceNodeId: sourceNodeId,
      sourceOutput: sourceOutput,
      targetNodeId: targetNodeId,
    );
    _applyDraft(
      current,
      current.workflow.copyWith(
        edges: <WorkflowEdge>[...current.workflow.edges, edge],
      ),
      selectedNodeId: () => null,
      selectedEdgeId: () => id,
    );
  }

  /// Updates an edge's `sourceOutput` or `maxRetries`.
  void updateEdge(
    String edgeId, {
    String? sourceOutput,
    int? maxRetries,
    bool clearMaxRetries = false,
  }) {
    final current = state.asData?.value;
    if (current == null) return;
    final nextEdges = <WorkflowEdge>[
      for (final edge in current.workflow.edges)
        if (edge.id == edgeId)
          edge.copyWith(
            sourceOutput: sourceOutput ?? edge.sourceOutput,
            maxRetries: clearMaxRetries
                ? null
                : (maxRetries ?? edge.maxRetries),
          )
        else
          edge,
    ];
    _applyDraft(current, current.workflow.copyWith(edges: nextEdges));
  }

  /// Deletes the edge identified by [edgeId].
  void deleteEdge(String edgeId) {
    final current = state.asData?.value;
    if (current == null) return;
    final nextEdges = current.workflow.edges
        .where((edge) => edge.id != edgeId)
        .toList();
    _applyDraft(
      current,
      current.workflow.copyWith(edges: nextEdges),
      selectedEdgeId: current.selectedEdgeId == edgeId ? () => null : null,
    );
  }

  /// Deletes whichever node or edge is currently selected.
  void deleteSelected() {
    final current = state.asData?.value;
    if (current == null) return;
    if (current.selectedNodeId != null) {
      deleteNode(current.selectedNodeId!);
    } else if (current.selectedEdgeId != null) {
      deleteEdge(current.selectedEdgeId!);
    }
  }

  /// Selects the offending node/edge for [issue] and requests the canvas to
  /// focus on it.
  void focusIssue(WorkflowValidationIssue issue) {
    final current = state.asData?.value;
    if (current == null) return;

    WorkflowNode? targetNode;
    WorkflowEdge? targetEdge;

    if (issue.nodeId != null) {
      for (final node in current.workflow.nodes) {
        if (node.id == issue.nodeId) {
          targetNode = node;
          break;
        }
      }
    }
    if (issue.edgeId != null) {
      for (final edge in current.workflow.edges) {
        if (edge.id == issue.edgeId) {
          targetEdge = edge;
          break;
        }
      }
    }

    EditorFocusRequest? focus;
    if (targetNode != null) {
      focus = EditorFocusRequest(
        sequence: ++_focusSeq,
        x: targetNode.position.x + 110,
        y: targetNode.position.y + 44,
      );
    } else if (targetEdge != null) {
      WorkflowNode? source;
      WorkflowNode? target;
      for (final node in current.workflow.nodes) {
        if (node.id == targetEdge.sourceNodeId) source = node;
        if (node.id == targetEdge.targetNodeId) target = node;
      }
      if (source != null && target != null) {
        focus = EditorFocusRequest(
          sequence: ++_focusSeq,
          x: (source.position.x + target.position.x) / 2 + 110,
          y: (source.position.y + target.position.y) / 2 + 44,
        );
      }
    }

    state = AsyncData(
      current.copyWith(
        selectedNodeId: () => targetNode?.id,
        selectedEdgeId: () => targetNode == null ? targetEdge?.id : null,
        focusRequest: focus != null ? () => focus : null,
      ),
    );
  }

  /// Persists the current draft workflow to the backend.
  Future<Result<WorkflowResponse>> save() async {
    final current = state.asData?.value;
    if (current == null) {
      return const FailureResult<WorkflowResponse>(
        UnexpectedFailure('Workflow editor is not loaded.'),
      );
    }

    state = AsyncData(
      current.copyWith(isSaving: true, saveFailure: () => null),
    );

    final draft = current.workflow;
    final trimmedDescription = draft.description?.trim();
    final result = await ref
        .read(updateWorkflowProvider)
        .call(
          draft.id,
          UpdateWorkflowRequest(
            name: draft.name,
            description:
                trimmedDescription == null || trimmedDescription.isEmpty
                ? null
                : trimmedDescription,
            nodes: draft.nodes,
            edges: draft.edges,
            entryNodeId: draft.entryNodeId,
            schemaVersion: draft.schemaVersion,
          ),
          workspaceId: _workspaceId,
        );
    if (!ref.mounted) return result;

    final latest = state.asData?.value;
    if (latest == null) return result;

    switch (result) {
      case Success<WorkflowResponse>(:final value):
        state = AsyncData(
          latest.copyWith(
            workflow: value.workflow,
            savedWorkflow: value.workflow,
            validation: value.validation,
            isSaving: false,
            saveFailure: () => null,
          ),
        );
        return Success<WorkflowResponse>(value);
      case FailureResult<WorkflowResponse>(:final failure):
        state = AsyncData(
          latest.copyWith(isSaving: false, saveFailure: () => failure),
        );
        return FailureResult<WorkflowResponse>(failure);
    }
  }

  void _applyDraft(
    WorkflowEditorState current,
    Workflow nextWorkflow, {
    String? Function()? selectedNodeId,
    String? Function()? selectedEdgeId,
    bool revalidate = true,
  }) {
    state = AsyncData(
      current.copyWith(
        workflow: nextWorkflow,
        selectedNodeId: selectedNodeId,
        selectedEdgeId: selectedEdgeId,
        isValidating: revalidate,
        saveFailure: () => null,
      ),
    );
    if (revalidate) {
      unawaited(_revalidate(nextWorkflow));
    }
  }

  Future<void> _revalidate(Workflow workflow) async {
    final seq = ++_validationSeq;
    final result = await ref.read(validateWorkflowProvider).call(workflow);
    if (!ref.mounted || seq != _validationSeq) return;
    final current = state.asData?.value;
    if (current == null) return;

    switch (result) {
      case Success<WorkflowValidationResult>(:final value):
        state = AsyncData(
          current.copyWith(validation: value, isValidating: false),
        );
      case FailureResult<WorkflowValidationResult>():
        state = AsyncData(current.copyWith(isValidating: false));
    }
  }

  String _nextUniqueId(String prefix, Set<String> existing) {
    while (true) {
      _idCounter++;
      final candidate = '${prefix}_$_idCounter';
      if (!existing.contains(candidate)) return candidate;
    }
  }
}
