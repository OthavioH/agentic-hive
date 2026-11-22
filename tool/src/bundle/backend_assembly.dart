import 'dart:io';

import 'package:path/path.dart' as p;

import 'bundle_layout.dart';

/// Moves the `dart build cli` outputs of every
/// [BundleLayout.backendEntryPoints] (`<buildRoot>/<entry>/bundle/`) into
/// `layout.backendDir`, replacing an old backend folder.
///
/// The `server` output is moved whole; for the other entry points only the
/// executable and their `lib/` files are added. A library that already
/// exists is kept when byte-identical; otherwise it is a conflict.
///
/// Returns the problems found, empty when the backend folder is complete.
List<String> assembleBackend({
  required BundleLayout layout,
  required String buildRoot,
}) {
  final backendDir = Directory(layout.backendDir);
  if (backendDir.existsSync()) {
    backendDir.deleteSync(recursive: true);
  }
  Directory(p.join(buildRoot, 'server', 'bundle')).renameSync(layout.backendDir);

  final problems = <String>[];
  for (final entry in BundleLayout.backendEntryPoints.skip(1)) {
    final bundle = p.join(buildRoot, entry, 'bundle');
    final exeName = layout.platform.executableFileName(entry);
    final srcExe = File(p.join(bundle, 'bin', exeName));
    if (srcExe.existsSync()) {
      srcExe.renameSync(p.join(layout.backendDir, 'bin', exeName));
    }

    final srcLibDir = Directory(p.join(bundle, 'lib'));
    if (srcLibDir.existsSync()) {
      final entities = srcLibDir.listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final entity in entities) {
        final name = p.basename(entity.path);
        if (entity is Directory) {
          problems.add('Unexpected folder in $entry lib/: $name');
          continue;
        }
        if (entity is File) {
          final target = File(p.join(layout.backendDir, 'lib', name));
          if (!target.existsSync()) {
            entity.renameSync(target.path);
          } else if (!_sameBytes(entity, target)) {
            problems.add(
              'Conflicting library $name: the $entry build differs from the '
              'server build.',
            );
          }
        }
      }
    }
  }

  problems.addAll(
    layout
        .missingBackendFiles((f) => File(f).existsSync())
        .map((f) => 'Missing built file: $f'),
  );
  return problems;
}

bool _sameBytes(File a, File b) {
  if (a.lengthSync() != b.lengthSync()) return false;
  final bytesA = a.readAsBytesSync();
  final bytesB = b.readAsBytesSync();
  for (var i = 0; i < bytesA.length; i++) {
    if (bytesA[i] != bytesB[i]) return false;
  }
  return true;
}
