import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

/// Kind of a debounced change to one file in a watched folder.
enum FolderChangeKind {
  /// A new file appeared in the folder.
  created,

  /// An existing file in the folder was modified.
  updated,

  /// A file was removed from the folder.
  deleted,
}

/// Watches the root of one folder for files with the given extensions and
/// reports one merged change per path after a quiet debounce window.
final class DebouncedFolderWatcher {
  /// Starts watching [directory] for root-level files matching [extensions].
  new({
    required String directory,
    required Set<String> extensions,
    required this._debounce,
    required this._onChange,
    required void Function(Object error, StackTrace stackTrace) onError,
    p.Context? pathContext,
  }) : _path = pathContext ?? p.context,
       _extensions = {for (final ext in extensions) ext.toLowerCase()},
       _watcher = DirectoryWatcher(directory) {
    _directory = _path.normalize(directory);
    _subscription = _watcher.events.listen(_onEvent, onError: onError);
  }

  final p.Context _path;
  late final String _directory;
  final Set<String> _extensions;
  final Duration _debounce;
  final void Function(String path, FolderChangeKind kind) _onChange;
  final DirectoryWatcher _watcher;
  late final StreamSubscription<WatchEvent> _subscription;

  final _pendingTimers = <String, Timer>{};
  final _pendingKinds = <String, FolderChangeKind>{};
  bool _closed = false;

  /// Completes once the underlying [DirectoryWatcher] is ready to emit events.
  Future<void> get ready => _watcher.ready;

  void _onEvent(WatchEvent event) {
    if (_closed) return;
    if (!_path.equals(_path.dirname(event.path), _directory)) return;
    if (!_extensions.contains(_path.extension(event.path).toLowerCase())) {
      return;
    }

    final kind = switch (event.type) {
      ChangeType.ADD => FolderChangeKind.created,
      ChangeType.MODIFY => FolderChangeKind.updated,
      ChangeType.REMOVE => FolderChangeKind.deleted,
      _ => null,
    };
    if (kind == null) return;

    final path = event.path;
    final pending = _pendingKinds[path];
    _pendingKinds[path] =
        pending == FolderChangeKind.created && kind == FolderChangeKind.updated
        ? FolderChangeKind.created
        : kind;

    _pendingTimers[path]?.cancel();
    _pendingTimers[path] = Timer(_debounce, () => _flush(path));
  }

  void _flush(String path) {
    _pendingTimers.remove(path);
    final kind = _pendingKinds.remove(path);
    if (_closed || kind == null) return;
    _onChange(path, kind);
  }

  /// Stops watching and cancels any pending debounce timers.
  Future<void> close() async {
    _closed = true;
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
    _pendingKinds.clear();
    await _subscription.cancel();
  }
}
