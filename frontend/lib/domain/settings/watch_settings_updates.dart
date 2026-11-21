import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Observes live [AppSettings] updates from the backend.
final class WatchSettingsUpdates {
  /// Creates a [WatchSettingsUpdates] use case.
  const new(this._repository);

  final SettingsRepository _repository;

  /// Executes the use case.
  Stream<AppSettings> call() => _repository.watchSettingsUpdates();
}
