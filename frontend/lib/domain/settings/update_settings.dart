import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Updates runtime [AppSettings] on the backend.
final class UpdateSettings {
  /// Creates an [UpdateSettings] use case.
  const new(this._repository);

  final SettingsRepository _repository;

  /// Executes the use case.
  Future<Result<AppSettings>> call(UpdateSettingsRequest request) =>
      _repository.updateSettings(request);
}
