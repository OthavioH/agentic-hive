import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/harness_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// HTTP handlers for `/api/v1/harnesses` endpoints.
final class HarnessesHandler {
  /// Creates a harnesses HTTP handler.
  const new({required this._harnessService});

  final HarnessService _harnessService;

  /// `GET /api/v1/harnesses`: returns the cached list of all harnesses.
  Future<Response> list(Request request) async {
    final result = await _harnessService.listHarnesses();
    return result.fold<Response>(
      onSuccess: (harnesses) =>
          jsonResponse(200, HarnessListResponse(harnesses: harnesses)),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `POST /api/v1/harnesses/refresh`: re-runs detection for all harnesses.
  Future<Response> refreshAll(Request request) async {
    final result = await _harnessService.refreshAll();
    return result.fold<Response>(
      onSuccess: (harnesses) =>
          jsonResponse(200, HarnessListResponse(harnesses: harnesses)),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `POST /api/v1/harnesses/<id>/refresh`: re-runs detection for one harness.
  Future<Response> refreshOne(Request request, String rawId) async {
    final id = HarnessId.tryParse(rawId);
    if (id == null) {
      return failureResponse(
        request,
        NotFoundFailure('Unknown harness "$rawId".'),
      );
    }
    final result = await _harnessService.refreshOne(id);
    return result.fold<Response>(
      onSuccess: (harness) => jsonResponse(200, harness),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }

  /// `POST /api/v1/harnesses/<id>/mcp/install`: installs or updates the Hive
  /// MCP server in one harness's user config and returns refreshed info.
  Future<Response> installMcp(Request request, String rawId) async {
    final id = HarnessId.tryParse(rawId);
    if (id == null) {
      return failureResponse(
        request,
        NotFoundFailure('Unknown harness "$rawId".'),
      );
    }
    final result = await _harnessService.installMcp(id);
    return result.fold<Response>(
      onSuccess: (harness) => jsonResponse(200, harness),
      onFailure: (failure) => failureResponse(request, failure),
    );
  }
}
