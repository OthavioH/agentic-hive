import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for loading, updating, and observing runtime
/// application settings.
abstract interface class SettingsRepository {
  /// Fetches the current [AppSettings] from the backend.
  Future<Result<AppSettings>> getSettings();

  /// Validates and persists [request] on the backend, returning the updated
  /// [AppSettings].
  Future<Result<AppSettings>> updateSettings(UpdateSettingsRequest request);

  /// Emits live [AppSettings] updates broadcast by the backend over WebSocket.
  Stream<AppSettings> watchSettingsUpdates();
}
