import 'dart:convert';

import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_events.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_backend/src/domain/worktrees/worktree_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// HTTP handler for `/api/v1/workspaces/{id}/worktrees` (ADR 0022).
final class WorktreesHandler {
  /// Creates a handler backed by the workspace and worktree services.
  const new({
    required this._workspaces,
    required this._worktrees,
    this._events,
  });

  final WorkspaceService _workspaces;
  final WorktreeService _worktrees;
  final WorkspaceEvents? _events;

  /// `GET /api/v1/workspaces/{id}/worktrees`.
  Future<Response> list(Request request, String id) async {
    final workspace = await _workspaces.get(id);
    if (workspace case FailureResult<Workspace>(:final failure)) {
      return failureResponse(request, failure);
    }
    final result = await _worktrees.list(workspace.valueOrNull!);
    return switch (result) {
      Success<List<Worktree>>(:final value) => jsonResponse(
        200,
        WorktreeListResponse(items: value),
      ),
      FailureResult<List<Worktree>>(:final failure) => failureResponse(
        request,
        failure,
      ),
    };
  }

  /// `POST /api/v1/workspaces/{id}/worktrees`.
  Future<Response> create(Request request, String id) async {
    final workspace = await _workspaces.get(id);
    if (workspace case FailureResult<Workspace>(:final failure)) {
      return failureResponse(request, failure);
    }
    final CreateWorktreeRequest body;
    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is! Map<String, Object?>) {
        return errorResponse(
          request,
          400,
          code: ApiErrorCode.badRequest,
          message: 'Request body must be a JSON object.',
        );
      }
      body = CreateWorktreeRequest.fromJson(decoded);
    } on FormatException catch (e) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: e.message,
      );
    }
    final result = await _worktrees.create(workspace.valueOrNull!, body);
    if (result case Success<Worktree>(:final value)) {
      _events?.worktreeChanged(
        WorktreeChangeKind.created,
        id,
        value.id,
        worktree: value,
      );
    }
    return switch (result) {
      Success<Worktree>(:final value) => jsonResponse(201, value),
      FailureResult<Worktree>(:final failure) => failureResponse(
        request,
        failure,
      ),
    };
  }

  /// `DELETE /api/v1/workspaces/{id}/worktrees/{worktreeId}`; the optional
  /// `force=true` query discards uncommitted changes.
  Future<Response> remove(Request request, String id, String worktreeId) async {
    final workspace = await _workspaces.get(id);
    if (workspace case FailureResult<Workspace>(:final failure)) {
      return failureResponse(request, failure);
    }
    final result = await _worktrees.remove(
      workspace.valueOrNull!,
      worktreeId,
      force: request.url.queryParameters['force'] == 'true',
    );
    if (result is Success<RemoveWorktreeResponse>) {
      _events?.worktreeChanged(WorktreeChangeKind.removed, id, worktreeId);
    }
    return switch (result) {
      Success<RemoveWorktreeResponse>(:final value) => jsonResponse(200, value),
      FailureResult<RemoveWorktreeResponse>(:final failure) => failureResponse(
        request,
        failure,
      ),
    };
  }
}
