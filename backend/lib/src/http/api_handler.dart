import 'package:agentic_hive_backend/src/api/workflows/workflow_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/health_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_backend/src/http/middleware/error_middleware.dart';
import 'package:agentic_hive_backend/src/http/middleware/reject_origin_middleware.dart';
import 'package:agentic_hive_backend/src/http/middleware/request_id_middleware.dart';
import 'package:agentic_hive_backend/src/http/middleware/request_logging_middleware.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Builds the backend's single shelf [Handler]: routes plus the middleware
/// pipeline.
///
/// Order: request id → request log → error handling → Origin rejection →
/// routes. The log wraps error handling so `500`s are logged with their
/// status.
Handler buildApiHandler({
  required StatusHandler statusHandler,
  required ShutdownHandler shutdownHandler,
  required Handler webSocketHandler,
  WorkflowHandler? workflowHandler,
}) {
  final router = Router(notFoundHandler: _notFound)
    ..get('/health', healthHandler)
    ..get('/api/v1/status', statusHandler.call)
    ..post('/api/v1/shutdown', shutdownHandler.call)
    ..get('/ws', webSocketHandler);
  if (workflowHandler != null) {
    router.mount('/api/v1/workflows', workflowHandler.call);
  }

  return const Pipeline()
      .addMiddleware(requestIdMiddleware())
      .addMiddleware(requestLoggingMiddleware())
      .addMiddleware(errorMiddleware())
      .addMiddleware(rejectOriginMiddleware())
      .addHandler(router.call);
}

Response _notFound(Request request) => errorResponse(
  request,
  404,
  code: ApiErrorCode.notFound,
  message: 'Route not found.',
);
