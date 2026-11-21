import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/theme/app_theme_preference.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_preference_store.g.dart';

/// Persistence abstraction for the locally stored [AppThemePreference].
abstract interface class ThemePreferenceStore {
  /// Loads the persisted [AppThemePreference], defaulting to
  /// [AppThemePreference.dark] when unset or unreadable.
  Future<AppThemePreference> load();

  /// Persists [preference] locally.
  Future<void> save(AppThemePreference preference);
}

/// File-backed [ThemePreferenceStore] writing `theme_preference.json` inside
/// [PlatformPaths.defaultDataDir].
final class FileThemePreferenceStore implements ThemePreferenceStore {
  /// Creates a [FileThemePreferenceStore].
  const new(this._platformPaths);

  static const String _fileName = 'theme_preference.json';

  final PlatformPaths _platformPaths;

  File get _file => File(
    _platformPaths.context.join(_platformPaths.defaultDataDir(), _fileName),
  );

  @override
  Future<AppThemePreference> load() async {
    try {
      final file = _file;
      if (!file.existsSync()) return AppThemePreference.dark;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        final theme = decoded['theme'];
        if (theme is String) {
          return AppThemePreference.fromStorageName(theme);
        }
      }
      return AppThemePreference.dark;
    } on Object {
      return AppThemePreference.dark;
    }
  }

  @override
  Future<void> save(AppThemePreference preference) async {
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, String>{'theme': preference.name}),
    );
  }
}

/// Provides the local [ThemePreferenceStore].
@Riverpod(keepAlive: true)
ThemePreferenceStore themePreferenceStore(Ref ref) =>
    FileThemePreferenceStore(currentPlatformPaths());
