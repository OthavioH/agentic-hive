import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/shell/side_rail_pin_controller.dart';
import 'package:agentic_hive_frontend/core/shell/side_rail_pin_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final class _ThrowingPinStore implements SideRailPinStore {
  @override
  Future<bool> load() async => false;

  @override
  Future<void> save(bool pinned) async {
    throw const FileSystemException('disk full');
  }
}

final class _FakeSideRailPinStore implements SideRailPinStore {
  new({this.initial = false});

  bool initial;
  Completer<bool>? pendingLoad;
  final List<bool> saved = <bool>[];

  @override
  Future<bool> load() => pendingLoad?.future ?? Future<bool>.value(initial);

  @override
  Future<void> save(bool pinned) async {
    saved.add(pinned);
    initial = pinned;
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
  group('SideRailPinController', () {
    test('defaults to false and loads persisted true', () async {
      final store = _FakeSideRailPinStore(initial: true);
      final container = ProviderContainer.test(
        overrides: [sideRailPinStoreProvider.overrideWithValue(store)],
      );

      expect(container.read(sideRailPinControllerProvider), isFalse);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(sideRailPinControllerProvider), isTrue);
    });

    test('setPinned updates state immediately and persists', () async {
      final store = _FakeSideRailPinStore();
      final container = ProviderContainer.test(
        overrides: [sideRailPinStoreProvider.overrideWithValue(store)],
      );

      await container
          .read(sideRailPinControllerProvider.notifier)
          .setPinned(true);
      expect(container.read(sideRailPinControllerProvider), isTrue);

      await container
          .read(sideRailPinControllerProvider.notifier)
          .setPinned(false);
      expect(container.read(sideRailPinControllerProvider), isFalse);
      expect(store.saved, <bool>[true, false]);
    });

    test(
      'user selection before initial load completes is not overwritten',
      () async {
        final pending = Completer<bool>();
        final store = _FakeSideRailPinStore()..pendingLoad = pending;
        final container = ProviderContainer.test(
          overrides: [sideRailPinStoreProvider.overrideWithValue(store)],
        );

        await container
            .read(sideRailPinControllerProvider.notifier)
            .setPinned(true);

        pending.complete(false);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(sideRailPinControllerProvider), isTrue);
      },
    );

    test('setPinned keeps in-memory state when save fails', () async {
      final container = ProviderContainer.test(
        overrides: [
          sideRailPinStoreProvider.overrideWithValue(_ThrowingPinStore()),
        ],
      );

      await container
          .read(sideRailPinControllerProvider.notifier)
          .setPinned(true);

      expect(container.read(sideRailPinControllerProvider), isTrue);
    });
  });

  group('FileSideRailPinStore', () {
    test('returns false when file does not exist', () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_pin_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final store = FileSideRailPinStore(_TempPlatformPaths(tempDir.path));
      expect(await store.load(), isFalse);
    });

    test('persists and reloads true and false from disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_pin_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final store = FileSideRailPinStore(_TempPlatformPaths(tempDir.path));
      await store.save(true);
      expect(await store.load(), isTrue);

      await store.save(false);
      expect(await store.load(), isFalse);
    });

    test('returns false when file contains invalid JSON or non-bool', () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_pin_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final file = File(p.join(tempDir.path, 'side_rail_pin.json'));
      await file.writeAsString('{not valid json');
      final store = FileSideRailPinStore(_TempPlatformPaths(tempDir.path));
      expect(await store.load(), isFalse);

      await file.writeAsString('{"pinned": "yes"}');
      expect(await store.load(), isFalse);
    });
  });
}
