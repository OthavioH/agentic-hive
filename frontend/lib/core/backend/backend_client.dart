import 'dart:io';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Transport interface for communicating with the local Agentic Hive backend.
abstract interface class BackendClient {
  /// Checks backend liveness via `GET /health`.
  Future<Result<HealthResponse>> checkHealth();

  /// Opens a WebSocket connection to `GET /ws`.
  Future<Result<WebSocket>> connectWebSocket();

  /// Closes underlying transport resources.
  Future<void> close();
}
