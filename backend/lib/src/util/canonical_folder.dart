import 'dart:io';

import 'package:path/path.dart' as p;

/// The canonical form of folder [path] under [context]: symbolic links are
/// resolved when the folder exists, then the path is normalized and, on
/// case-insensitive platforms, case-folded.
///
/// Two paths name the same folder when their canonical forms are equal. A
/// folder that does not exist is canonicalized as a plain path.
String canonicalFolder(String path, p.Context context) {
  try {
    final dir = Directory(path);
    if (dir.existsSync()) {
      return context.canonicalize(dir.resolveSymbolicLinksSync());
    }
  } on FileSystemException {
    // Fall back to path canonicalization below.
  }
  return context.canonicalize(path);
}
