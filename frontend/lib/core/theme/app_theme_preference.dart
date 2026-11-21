import 'package:material_ui/material_ui.dart';

/// User-selected application theme mode persisted locally on the frontend.
enum AppThemePreference {
  /// Always use the dark theme (default).
  dark,

  /// Always use the light theme.
  light,

  /// Follow the operating system brightness.
  system;

  /// Parses a persisted storage string, defaulting to
  /// [AppThemePreference.dark].
  static AppThemePreference fromStorageName(String? value) => switch (value) {
    'light' => AppThemePreference.light,
    'system' => AppThemePreference.system,
    _ => AppThemePreference.dark,
  };

  /// Maps this preference to Flutter's [ThemeMode].
  ThemeMode toThemeMode() => switch (this) {
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.system => ThemeMode.system,
  };
}
