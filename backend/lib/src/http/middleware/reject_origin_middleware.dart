import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// Rejects every request that carries an `Origin` header with `403`.
///
/// Browsers always send `Origin` on cross-site requests and WebSocket
/// handshakes; the Flutter app never does. This is a cheap extra layer on top
/// of the Unix socket transport (ADR 0011).
Middleware rejectOriginMiddleware() =>
    (inner) => (request) {
      if (request.headers.containsKey('origin')) {
        return errorResponse(
          request,
          403,
          code: ApiErrorCode.originNotAllowed,
          message: 'Requests with an Origin header are not accepted.',
        );
      }
      return inner(request);
    };
