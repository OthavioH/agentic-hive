import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/preferences/run_detail_splitter_preference.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'run_detail_splitter_preference_store.g.dart';

/// Persistence abstraction for [RunDetailSplitterPreference].
abstract interface class RunDetailSplitterPreferenceStore {
  /// Loads the persisted [RunDetailSplitterPreference], defaulting to
  /// [RunDetailSplitterPreference.defaultFraction] when unset or unreadable.
  Future<RunDetailSplitterPreference> load();

  /// Persists [preference] locally.
  Future<void> save(RunDetailSplitterPreference preference);
}

/// File-backed [RunDetailSplitterPreferenceStore] writing
/// `run_detail_splitter_preference.json` inside [PlatformPaths.defaultDataDir].
final class FileRunDetailSplitterPreferenceStore
    implements RunDetailSplitterPreferenceStore {
  /// Creates a [FileRunDetailSplitterPreferenceStore].
  const new(this._platformPaths);

  static const String _fileName = 'run_detail_splitter_preference.json';

  final PlatformPaths _platformPaths;

  File get _file => File(
    _platformPaths.context.join(_platformPaths.defaultDataDir(), _fileName),
  );

  static double _parseFraction(Object? raw) {
    if (raw is num) {
      final value = raw.toDouble();
      if (value.isFinite && value >= 0 && value <= 1) return value;
    }
    return RunDetailSplitterPreference.defaultFraction;
  }

  @override
  Future<RunDetailSplitterPreference> load() async {
    try {
      final file = _file;
      if (!file.existsSync()) return const RunDetailSplitterPreference();
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return RunDetailSplitterPreference(
          sideBySide: _parseFraction(decoded['sideBySide']),
          stacked: _parseFraction(decoded['stacked']),
        );
      }
      return const RunDetailSplitterPreference();
    } on Object {
      return const RunDetailSplitterPreference();
    }
  }

  @override
  Future<void> save(RunDetailSplitterPreference preference) async {
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, double>{
        'sideBySide': preference.sideBySide,
        'stacked': preference.stacked,
      }),
    );
  }
}

/// Provides the local [RunDetailSplitterPreferenceStore].
@Riverpod(keepAlive: true)
RunDetailSplitterPreferenceStore runDetailSplitterPreferenceStore(Ref ref) =>
    FileRunDetailSplitterPreferenceStore(currentPlatformPaths());
