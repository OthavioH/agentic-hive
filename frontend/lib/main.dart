import 'dart:async';

import 'package:agentic_hive_frontend/app.dart';
import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/lifecycle/window_lifecycle_service.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_controller.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = FileThemePreferenceStore(currentPlatformPaths());
  final initialTheme = await store.load();
  final windowService = currentWindowLifecycleService()..configureTitleBar();
  runApp(
    ProviderScope(
      overrides: [
        themePreferenceStoreProvider.overrideWithValue(store),
        initialThemePreferenceProvider.overrideWithValue(initialTheme),
        windowLifecycleServiceProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(windowService.dispose()));
          return windowService;
        }),
      ],
      child: const HiveApp(),
    ),
  );
}
