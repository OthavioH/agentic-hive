import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'side_rail_pin_store.g.dart';

/// Persistence abstraction for the locally stored side-rail panel pin state.
abstract interface class SideRailPinStore {
  /// Loads the persisted pin state, defaulting to `false` when unset or
  /// unreadable.
  Future<bool> load();

  /// Persists [pinned] locally.
  Future<void> save(bool pinned);
}

/// File-backed [SideRailPinStore] writing `side_rail_pin.json` inside
/// [PlatformPaths.defaultDataDir].
final class FileSideRailPinStore implements SideRailPinStore {
  /// Creates a [FileSideRailPinStore].
  const new(this._platformPaths);

  static const String _fileName = 'side_rail_pin.json';

  final PlatformPaths _platformPaths;

  File get _file => File(
    _platformPaths.context.join(_platformPaths.defaultDataDir(), _fileName),
  );

  @override
  Future<bool> load() async {
    try {
      final file = _file;
      if (!file.existsSync()) return false;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        final pinned = decoded['pinned'];
        if (pinned is bool) return pinned;
      }
      return false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> save(bool pinned) async {
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(<String, bool>{'pinned': pinned}));
  }
}

/// Provides the local [SideRailPinStore].
@Riverpod(keepAlive: true)
SideRailPinStore sideRailPinStore(Ref ref) =>
    FileSideRailPinStore(currentPlatformPaths());
