import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

final _log = Logger('http.error');

/// Turns any uncaught error into a `500` with the standard [ApiError] body.
/// The stack trace goes to the log only, never to the response.
Middleware errorMiddleware() =>
    (inner) => (request) async {
      try {
        return await inner(request);
      } on HijackException {
        rethrow;
      } on Object catch (error, stackTrace) {
        _log.severe(
          LogEvent(
            'http.unhandled_error',
            fields: {
              'method': request.method,
              'path': '/${request.url.path}',
              'requestId': requestIdOf(request),
            },
          ),
          error,
          stackTrace,
        );
        return errorResponse(
          request,
          500,
          code: ApiErrorCode.internalError,
          message: 'Internal server error.',
        );
      }
    };
