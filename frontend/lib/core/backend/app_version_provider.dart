import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version_provider.g.dart';

/// Current backend/app version reported by `/api/v1/status`, or `null` when
/// disconnected.
@Riverpod(keepAlive: true)
String? appVersion(Ref ref) => switch (ref.watch(backendConnectionProvider)) {
  BackendConnected(:final status) => status.version,
  BackendConnecting() || BackendDisconnected() => null,
};
