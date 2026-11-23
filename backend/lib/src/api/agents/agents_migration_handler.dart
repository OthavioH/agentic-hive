import 'package:agentic_hive_backend/src/domain/agents/agents_migration_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:shelf/shelf.dart';

/// HTTP handlers for `/api/v1/agent-library/migration`.
final class AgentsMigrationHandler {
  /// Creates the handler backed by [_service].
  const new(this._service);

  final AgentsMigrationService _service;

  /// `GET /api/v1/agent-library/migration` — the conflicts left by the move of
  /// the global agents into `~/.agents/agents`.
  Future<Response> get(Request request) async {
    final result = await _service.status();
    return result.fold<Response>(
      onSuccess: (status) => jsonResponse(200, status),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `POST /api/v1/agent-library/migration/dismiss` — remembers that the user
  /// saw the current conflicts.
  Future<Response> dismiss(Request request) async {
    final result = await _service.dismiss();
    return result.fold<Response>(
      onSuccess: (status) => jsonResponse(200, status),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }
}
