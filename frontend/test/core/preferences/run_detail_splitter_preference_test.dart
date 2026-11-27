import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/preferences/run_detail_splitter_preference.dart';
import 'package:agentic_hive_frontend/core/preferences/run_detail_splitter_preference_controller.dart';
import 'package:agentic_hive_frontend/core/preferences/run_detail_splitter_preference_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final class _TempPlatformPaths implements PlatformPaths {
  const new(this._dir);

  final String _dir;

  @override
  p.Context get context => p.context;

  @override
  String defaultDataDir() => _dir;

  @override
  String serverInfoPath() => context.join(_dir, 'server.json');
}

final class _InMemorySplitterPreferenceStore
    implements RunDetailSplitterPreferenceStore {
  new([this.value = const RunDetailSplitterPreference()]);

  RunDetailSplitterPreference value;
  int saveCalls = 0;

  @override
  Future<RunDetailSplitterPreference> load() async => value;

  @override
  Future<void> save(RunDetailSplitterPreference preference) async {
    saveCalls++;
    value = preference;
  }
}

void main() {
  group('RunDetailSplitterPreference', () {
    test('defaults to 0.45 for both layouts', () {
      const pref = RunDetailSplitterPreference();
      expect(pref.sideBySide, 0.45);
      expect(pref.stacked, 0.45);
    });

    test('copyWith updates only the specified field', () {
      const pref = RunDetailSplitterPreference();
      expect(
        pref.copyWith(sideBySide: 0.6),
        const RunDetailSplitterPreference(sideBySide: 0.6),
      );
      expect(
        pref.copyWith(stacked: 0.35),
        const RunDetailSplitterPreference(stacked: 0.35),
      );
    });
  });

  group('FileRunDetailSplitterPreferenceStore', () {
    test('loads default when unset and persists saved values', () async {
      final dir = Directory.systemTemp.createTempSync(
        'hive_splitter_pref_test_',
      );
      addTearDown(() {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });
      final store = FileRunDetailSplitterPreferenceStore(
        _TempPlatformPaths(dir.path),
      );

      expect(await store.load(), const RunDetailSplitterPreference());

      const updated = RunDetailSplitterPreference(
        sideBySide: 0.62,
        stacked: 0.38,
      );
      await store.save(updated);

      expect(await store.load(), updated);
    });
  });

  group('RunDetailSplitterPreferenceController', () {
    test('loads saved values on startup', () async {
      final store = _InMemorySplitterPreferenceStore(
        const RunDetailSplitterPreference(sideBySide: 0.58, stacked: 0.42),
      );
      final container = ProviderContainer.test(
        overrides: [
          runDetailSplitterPreferenceStoreProvider.overrideWithValue(store),
        ],
      );

      expect(
        container.read(runDetailSplitterPreferenceControllerProvider),
        const RunDetailSplitterPreference(),
      );

      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(runDetailSplitterPreferenceControllerProvider),
        const RunDetailSplitterPreference(sideBySide: 0.58, stacked: 0.42),
      );
    });

    test('setSideBySide and setStacked update state and persist', () async {
      final store = _InMemorySplitterPreferenceStore();
      final container = ProviderContainer.test(
        overrides: [
          runDetailSplitterPreferenceStoreProvider.overrideWithValue(store),
        ],
      );

      final notifier = container.read(
        runDetailSplitterPreferenceControllerProvider.notifier,
      );
      await notifier.setSideBySide(0.65);
      await notifier.setStacked(0.32);

      expect(
        container.read(runDetailSplitterPreferenceControllerProvider),
        const RunDetailSplitterPreference(sideBySide: 0.65, stacked: 0.32),
      );
      expect(store.saveCalls, 2);
      expect(
        store.value,
        const RunDetailSplitterPreference(sideBySide: 0.65, stacked: 0.32),
      );
    });
  });
}
