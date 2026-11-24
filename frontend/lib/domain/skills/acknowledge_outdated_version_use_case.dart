import 'package:agentic_hive_frontend/domain/skills/outdated_banner_store.dart';

/// Persists that the user acknowledged the outdated-tools banner for a version.
final class AcknowledgeOutdatedVersionUseCase {
  /// Creates an [AcknowledgeOutdatedVersionUseCase].
  const new(this._store);

  final OutdatedBannerStore _store;

  /// Saves [version] as acknowledged locally.
  Future<void> call(String version) => _store.saveAcknowledgedVersion(version);
}
