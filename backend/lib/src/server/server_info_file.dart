import 'dart:convert';
import 'dart:io';

/// `server.json`: tells the frontend where the running backend listens.
///
/// ```json
/// {"pid": 1234, "version": "0.1.0", "socketPath": "...", "startedAt": "..."}
/// ```
final class ServerInfoFile {
  /// Creates the file description for [path].
  new(this.path);

  /// Path of `server.json`.
  final String path;

  /// Writes the file atomically (temporary file, then rename).
  Future<void> write({
    required int pid,
    required String version,
    required String socketPath,
    required DateTime startedAt,
  }) async {
    final temporary = File('$path.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'pid': pid,
        'version': version,
        'socketPath': socketPath,
        'startedAt': startedAt.toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await temporary.rename(path);
  }

  /// Removes the file, if present.
  Future<void> delete() async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}
