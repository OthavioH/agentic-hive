import 'dart:async';

import 'package:agentic_hive_frontend/core/theme/app_theme_preference.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_preference_controller.g.dart';

/// Manages the active [AppThemePreference] and persists changes locally.
@Riverpod(keepAlive: true)
class ThemePreferenceController extends _$ThemePreferenceController {
  bool _hasUserSelection = false;

  @override
  AppThemePreference build() {
    _hasUserSelection = false;
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
    await ref.read(themePreferenceStoreProvider).save(preference);
  }
}
