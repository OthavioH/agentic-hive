import 'package:agentic_hive_backend/src/api/agents/agents_handler.dart';
import 'package:agentic_hive_backend/src/api/harnesses/harnesses_handler.dart';
import 'package:agentic_hive_backend/src/api/runs/runs_handler.dart';
import 'package:agentic_hive_backend/src/api/settings/settings_handler.dart';
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
  AgentsHandler? agentsHandler,
  HarnessesHandler? harnessesHandler,
  WorkflowHandler? workflowHandler,
  RunsHandler? runsHandler,
  SettingsHandler? settingsHandler,
}) {
  final router = Router(notFoundHandler: _notFound)
    ..get('/health', healthHandler)
    ..get('/api/v1/status', statusHandler.call)
    ..post('/api/v1/shutdown', shutdownHandler.call)
    ..get('/ws', webSocketHandler);
  if (workflowHandler != null) {
    router.mount('/api/v1/workflows', workflowHandler.call);
  }
  if (runsHandler != null) {
    router.mount('/api/v1/runs', runsHandler.call);
  }

  if (harnessesHandler != null) {
    router
      ..get('/api/v1/harnesses', harnessesHandler.list)
      ..post('/api/v1/harnesses/refresh', harnessesHandler.refreshAll)
      ..post('/api/v1/harnesses/<id>/refresh', harnessesHandler.refreshOne);
  }

  if (agentsHandler != null) {
    router
      ..get('/api/v1/agents', agentsHandler.list)
      ..get('/api/v1/agents/<id>', agentsHandler.getById)
      ..post('/api/v1/agents', agentsHandler.create)
      ..put('/api/v1/agents/<id>', agentsHandler.update)
      ..delete('/api/v1/agents/<id>', agentsHandler.delete);
  }

  if (settingsHandler != null) {
    router
      ..get('/api/v1/settings', settingsHandler.get)
      ..put('/api/v1/settings', settingsHandler.update);
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
