import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/theme/app_theme_preference.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_controller.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final class _FakeThemePreferenceStore implements ThemePreferenceStore {
  new({this.initial = AppThemePreference.dark});

  AppThemePreference initial;
  Completer<AppThemePreference>? pendingLoad;
  final List<AppThemePreference> saved = <AppThemePreference>[];

  @override
  Future<AppThemePreference> load() =>
      pendingLoad?.future ?? Future<AppThemePreference>.value(initial);

  @override
  Future<void> save(AppThemePreference preference) async {
    saved.add(preference);
    initial = preference;
  }
}

final class _TempPlatformPaths implements PlatformPaths {
  new(this._dir);

  final String _dir;

  @override
  p.Context get context => p.context;

  @override
  String defaultDataDir() => _dir;

  @override
  String serverInfoPath() => context.join(_dir, 'server.json');
}

void main() {
  group('ThemePreferenceController', () {
    test('defaults to dark and loads persisted preference', () async {
      final store = _FakeThemePreferenceStore(
        initial: AppThemePreference.light,
      );
      final container = ProviderContainer.test(
        overrides: [themePreferenceStoreProvider.overrideWithValue(store)],
      );

      expect(
        container.read(themePreferenceControllerProvider),
        AppThemePreference.dark,
      );

      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(themePreferenceControllerProvider),
        AppThemePreference.light,
      );
    });

    test('setPreference updates state immediately and persists', () async {
      final store = _FakeThemePreferenceStore();
      final container = ProviderContainer.test(
        overrides: [themePreferenceStoreProvider.overrideWithValue(store)],
      );

      await container
          .read(themePreferenceControllerProvider.notifier)
          .setPreference(AppThemePreference.system);

      expect(
        container.read(themePreferenceControllerProvider),
        AppThemePreference.system,
      );
      expect(store.saved, <AppThemePreference>[AppThemePreference.system]);
    });

    test(
      'user selection before initial load completes is not overwritten',
      () async {
        final pending = Completer<AppThemePreference>();
        final store = _FakeThemePreferenceStore()..pendingLoad = pending;
        final container = ProviderContainer.test(
          overrides: [themePreferenceStoreProvider.overrideWithValue(store)],
        );

        await container
            .read(themePreferenceControllerProvider.notifier)
            .setPreference(AppThemePreference.light);

        pending.complete(AppThemePreference.system);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(themePreferenceControllerProvider),
          AppThemePreference.light,
        );
      },
    );
  });

  group('FileThemePreferenceStore', () {
    test('persists and reloads preference from disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_theme_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final store = FileThemePreferenceStore(_TempPlatformPaths(tempDir.path));
      expect(await store.load(), AppThemePreference.dark);

      await store.save(AppThemePreference.light);
      expect(await store.load(), AppThemePreference.light);

      await store.save(AppThemePreference.system);
      expect(await store.load(), AppThemePreference.system);
    });
  });
}
