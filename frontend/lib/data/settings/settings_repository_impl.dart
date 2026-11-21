import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/settings/settings_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_repository_impl.g.dart';

/// [SettingsRepository] backed by [SettingsRemoteDataSource].
final class SettingsRepositoryImpl implements SettingsRepository {
  /// Creates a [SettingsRepositoryImpl].
  const new(this._remoteDataSource);

  final SettingsRemoteDataSource _remoteDataSource;

  @override
  Future<Result<AppSettings>> getSettings() => _remoteDataSource.getSettings();

  @override
  Future<Result<AppSettings>> updateSettings(UpdateSettingsRequest request) =>
      _remoteDataSource.updateSettings(request);

  @override
  Stream<AppSettings> watchSettingsUpdates() =>
      _remoteDataSource.watchSettingsUpdates();
}

/// Provides the [SettingsRepository] implementation.
@riverpod
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepositoryImpl(ref.watch(settingsRemoteDataSourceProvider));
