/// Local persistence abstraction for the app version for which the outdated
/// harness tools banner has already been acknowledged.
abstract interface class OutdatedBannerStore {
  /// Loads the acknowledged app version, or `null` when unset or unreadable.
  Future<String?> loadAcknowledgedVersion();

  /// Persists [appVersion] as acknowledged locally.
  Future<void> saveAcknowledgedVersion(String appVersion);
}
