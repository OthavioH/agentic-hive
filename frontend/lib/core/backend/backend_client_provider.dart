import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/backend/unix_socket_backend_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backend_client_provider.g.dart';

/// Provides the app-wide [BackendClient] over the local Unix domain socket.
///
/// Tests can override this provider with a fake [BackendClient].
@Riverpod(keepAlive: true)
BackendClient backendClient(Ref ref) {
  final client = UnixSocketBackendClient(platformPaths: currentPlatformPaths());
  ref.onDispose(() => unawaited(client.close()));
  return client;
}
