import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/overview/overview_service.dart';
import 'package:agentic_hive_backend/src/http/failure_response.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:shelf/shelf.dart';

/// HTTP handler for `GET /api/v1/overview`.
final class OverviewHandler {
  /// Creates an overview handler backed by [_service].
  const new({required this._service});

  final OverviewService _service;

  /// Handles `GET /api/v1/overview`.
  Future<Response> call(Request request) async {
    final result = await _service.getOverview();
    return switch (result) {
      Success(:final value) => jsonResponse(200, value),
      FailureResult(:final failure) => failureResponse(request, failure),
    };
  }
}
