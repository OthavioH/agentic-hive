import 'dart:async';

import 'package:agentic_hive_frontend/core/shell/side_rail_pin_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'side_rail_pin_controller.g.dart';

/// Manages whether the side-rail workspaces panel is pinned and persists
/// changes locally.
@Riverpod(keepAlive: true)
class SideRailPinController extends _$SideRailPinController {
  bool _hasUserSelection = false;

  @override
  bool build() {
    _hasUserSelection = false;
    unawaited(Future<void>.microtask(_loadSaved));
    return false;
  }

  Future<void> _loadSaved() async {
    final loaded = await ref.read(sideRailPinStoreProvider).load();
    if (!ref.mounted || _hasUserSelection) return;
    state = loaded;
  }

  /// Updates the pin state immediately and persists it locally.
  Future<void> setPinned(bool pinned) async {
    _hasUserSelection = true;
    state = pinned;
    try {
      await ref.read(sideRailPinStoreProvider).save(pinned);
    } on Object {
      // Keep the active in-memory pin state if local persistence fails.
    }
  }
}
