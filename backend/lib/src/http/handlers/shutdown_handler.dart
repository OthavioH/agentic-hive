import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

int _noActiveRuns() => 0;

/// `POST /api/v1/shutdown`: requests a graceful backend shutdown.
///
/// Answers `202 Accepted` when no active runs are in progress or `force` is
/// `true`, `409 Conflict` when active runs are in progress and `force` is
/// `false`, and `400 Bad Request` when the JSON body is malformed.
final class ShutdownHandler {
  /// Creates the handler; [_onShutdown] is invoked asynchronously after the
  /// `202` response is returned.
  new({required this._onShutdown, int Function()? activeRuns})
    : _activeRuns = activeRuns ?? _noActiveRuns;

  final Future<void> Function() _onShutdown;
  final int Function() _activeRuns;

  /// Handles one shutdown request.
  Future<Response> call(Request request) async {
    final ShutdownRequest body;
    try {
      body = await _parseBody(request);
    } on FormatException catch (e) {
      return errorResponse(
        request,
        400,
        code: ApiErrorCode.badRequest,
        message: e.message,
      );
    }

    final active = _activeRuns();
    if (active > 0 && !body.force) {
      return errorResponse(
        request,
        409,
        code: ApiErrorCode.conflict,
        message:
            'Cannot shut down while $active active run(s) are in progress.',
      );
    }

    // Give shelf_io time to flush the 202 response over the socket before
    // BackendServer.stop() calls HttpServer.close(force: true).
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 50), _onShutdown),
    );
    return jsonResponse(202, const ShutdownResponse());
  }

  static Future<ShutdownRequest> _parseBody(Request request) async {
    final raw = await request.readAsString();
    if (raw.trim().isEmpty) return const ShutdownRequest();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object.');
    }
    return ShutdownRequest.fromJson(decoded.cast<String, Object?>());
  }
}
