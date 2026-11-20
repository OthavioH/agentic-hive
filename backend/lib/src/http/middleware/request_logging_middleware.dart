import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

final _log = Logger('http');

/// Logs one `INFO` event per request: method, path, status, duration and
/// request id. The query string and body are never logged (they may carry user
/// content).
///
/// A WebSocket upgrade hijacks the connection; it is logged as `http.upgrade`
/// and the [HijackException] is rethrown for shelf to handle.
Middleware requestLoggingMiddleware() =>
    (inner) => (request) async {
      final stopwatch = Stopwatch()..start();
      final fields = <String, Object?>{
        'method': request.method,
        'path': '/${request.url.path}',
        'requestId': requestIdOf(request),
      };
      try {
        final response = await inner(request);
        _log.info(
          LogEvent(
            'http.request',
            fields: {
              ...fields,
              'status': response.statusCode,
              'durationMs': stopwatch.elapsedMilliseconds,
            },
          ),
        );
        return response;
      } on HijackException {
        _log.info(LogEvent('http.upgrade', fields: fields));
        rethrow;
      }
    };
