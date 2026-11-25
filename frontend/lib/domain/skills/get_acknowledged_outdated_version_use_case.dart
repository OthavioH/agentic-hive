import 'package:agentic_hive_frontend/domain/skills/outdated_banner_store.dart';

/// Reads the locally persisted acknowledged outdated-tools app version.
final class GetAcknowledgedOutdatedVersionUseCase {
  /// Creates a [GetAcknowledgedOutdatedVersionUseCase].
  const new(this._store);

  final OutdatedBannerStore _store;

  /// Loads the acknowledged version, or `null` if none is stored.
  Future<String?> call() => _store.loadAcknowledgedVersion();
}
