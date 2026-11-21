import 'dart:async';

import 'package:agentic_hive_frontend/core/theme/app_theme_preference.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_preference_controller.g.dart';

/// Optional preloaded [AppThemePreference] injected before `runApp` to prevent
/// a dark-frame flash on startup.
@Riverpod(keepAlive: true)
AppThemePreference? initialThemePreference(Ref ref) => null;

/// Manages the active [AppThemePreference] and persists changes locally.
@Riverpod(keepAlive: true)
class ThemePreferenceController extends _$ThemePreferenceController {
  bool _hasUserSelection = false;

  @override
  AppThemePreference build() {
    _hasUserSelection = false;
    final preloaded = ref.watch(initialThemePreferenceProvider);
    if (preloaded != null) return preloaded;
    unawaited(Future<void>.microtask(_loadSavedPreference));
    return AppThemePreference.dark;
  }

  Future<void> _loadSavedPreference() async {
    final loaded = await ref.read(themePreferenceStoreProvider).load();
    if (!ref.mounted || _hasUserSelection) return;
    state = loaded;
  }

  /// Updates the active theme immediately and persists it locally.
  Future<void> setPreference(AppThemePreference preference) async {
    _hasUserSelection = true;
    state = preference;
    try {
      await ref.read(themePreferenceStoreProvider).save(preference);
    } on Object {
      // Keep the active in-memory theme if local persistence fails.
    }
  }
}
