import 'dart:async';

import 'package:agentic_hive_frontend/core/preferences/run_detail_splitter_preference.dart';
import 'package:agentic_hive_frontend/core/preferences/run_detail_splitter_preference_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'run_detail_splitter_preference_controller.g.dart';

/// Manages the Run Detail splitter positions and persists changes locally.
@Riverpod(keepAlive: true)
class RunDetailSplitterPreferenceController
    extends _$RunDetailSplitterPreferenceController {
  bool _hasUserSideBySideSelection = false;
  bool _hasUserStackedSelection = false;

  @override
  RunDetailSplitterPreference build() {
    _hasUserSideBySideSelection = false;
    _hasUserStackedSelection = false;
    unawaited(Future<void>.microtask(_loadSavedPreference));
    return const RunDetailSplitterPreference();
  }

  Future<void> _loadSavedPreference() async {
    final loaded = await ref
        .read(runDetailSplitterPreferenceStoreProvider)
        .load();
    if (!ref.mounted) return;
    state = RunDetailSplitterPreference(
      sideBySide: _hasUserSideBySideSelection
          ? state.sideBySide
          : loaded.sideBySide,
      stacked: _hasUserStackedSelection ? state.stacked : loaded.stacked,
    );
  }

  /// Updates the side-by-side splitter fraction and persists it locally.
  Future<void> setSideBySide(double fraction) async {
    _hasUserSideBySideSelection = true;
    final next = state.copyWith(sideBySide: fraction);
    state = next;
    await _save(next);
  }

  /// Updates the stacked splitter fraction and persists it locally.
  Future<void> setStacked(double fraction) async {
    _hasUserStackedSelection = true;
    final next = state.copyWith(stacked: fraction);
    state = next;
    await _save(next);
  }

  Future<void> _save(RunDetailSplitterPreference preference) async {
    try {
      await ref.read(runDetailSplitterPreferenceStoreProvider).save(preference);
    } on Object {
      // Keep the active in-memory fractions if local persistence fails.
    }
  }
}
