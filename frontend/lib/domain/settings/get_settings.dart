import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Loads the current [AppSettings] from the backend.
final class GetSettings {
  /// Creates a [GetSettings] use case.
  const new(this._repository);

  final SettingsRepository _repository;

  /// Executes the use case.
  Future<Result<AppSettings>> call() => _repository.getSettings();
}
