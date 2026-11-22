import 'package:agentic_hive_backend/src/api/agents/agents_handler.dart';
import 'package:agentic_hive_backend/src/api/harnesses/harnesses_handler.dart';
import 'package:agentic_hive_backend/src/api/overview/overview_handler.dart';
import 'package:agentic_hive_backend/src/api/pauses/pauses_handler.dart';
import 'package:agentic_hive_backend/src/api/result_contract/result_contract_handler.dart';
import 'package:agentic_hive_backend/src/api/runs/runs_handler.dart';
import 'package:agentic_hive_backend/src/api/settings/settings_handler.dart';
import 'package:agentic_hive_backend/src/api/workflows/workflow_handler.dart';
import 'package:agentic_hive_backend/src/api/workspace/workspace_handler.dart';
import 'package:agentic_hive_backend/src/api/workspace/workspaces_handler.dart';
import 'package:agentic_hive_backend/src/api/worktrees/worktrees_handler.dart';
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
  ResultContractHandler? resultContractHandler,
  RunsHandler? runsHandler,
  PausesHandler? pausesHandler,
  OverviewHandler? overviewHandler,
  WorkspaceHandler? workspaceHandler,
  WorkspacesHandler? workspacesHandler,
  WorktreesHandler? worktreesHandler,
  SettingsHandler? settingsHandler,
}) {
  final router = Router(notFoundHandler: _notFound)
    ..get('/health', healthHandler)
    ..get('/api/v1/status', statusHandler.call)
    ..post('/api/v1/shutdown', shutdownHandler.call)
    ..get('/ws', webSocketHandler);
  if (overviewHandler != null) {
    router.get('/api/v1/overview', overviewHandler.call);
  }
  if (workflowHandler != null) {
    router.mount('/api/v1/workflows', workflowHandler.call);
  }
  if (workspaceHandler != null) {
    router
      ..get('/api/v1/workspace/capabilities', workspaceHandler.capabilities)
      ..get('/api/v1/runs/<id>/snapshots', workspaceHandler.listSnapshots)
      ..get(
        '/api/v1/runs/<id>/snapshots/<snapshotId>/diff',
        workspaceHandler.getDiff,
      )
      ..post(
        '/api/v1/runs/<id>/snapshots/<snapshotId>/restore',
        workspaceHandler.restoreSnapshot,
      );
  }
  if (worktreesHandler != null) {
    router
      ..get('/api/v1/workspaces/<id>/worktrees', worktreesHandler.list)
      ..post('/api/v1/workspaces/<id>/worktrees', worktreesHandler.create)
      ..delete(
        '/api/v1/workspaces/<id>/worktrees/<worktreeId>',
        worktreesHandler.remove,
      );
  }
  if (workspacesHandler != null) {
    router.mount('/api/v1/workspaces', workspacesHandler.call);
  }
  if (runsHandler != null) {
    router.mount('/api/v1/runs', runsHandler.call);
  }
  if (pausesHandler != null) {
    router.mount('/api/v1/pauses', pausesHandler.call);
  }

  if (harnessesHandler != null) {
    router
      ..get('/api/v1/harnesses', harnessesHandler.list)
      ..post('/api/v1/harnesses/refresh', harnessesHandler.refreshAll)
      ..post('/api/v1/harnesses/<id>/refresh', harnessesHandler.refreshOne)
      ..post('/api/v1/harnesses/<id>/mcp/install', harnessesHandler.installMcp);
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

  if (resultContractHandler != null) {
    router
      ..post(
        '/api/v1/internal/runs/<runId>/nodes/<nodeId>/attempts/<attempt>/report-result',
        resultContractHandler.reportResult,
      )
      ..post(
        '/api/v1/internal/runs/<runId>/nodes/<nodeId>/attempts/<attempt>/ask-human',
        resultContractHandler.askHuman,
      );
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
