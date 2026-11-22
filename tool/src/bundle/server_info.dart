import 'dart:convert';

/// The parts of `server.json` the smoke test needs (format: `ServerInfoFile`
/// in the backend).
final class ServerInfo {
  /// Creates a [ServerInfo].
  const new({required this.pid, required this.socketPath});

  /// Parses `server.json` content. Throws [FormatException] when it is not a
  /// JSON object with an int `pid` and a non-empty String `socketPath`.
  factory parse(String source) {
    final decoded = jsonDecode(source);
    return switch (decoded) {
      {'pid': final int pid, 'socketPath': final String socketPath}
          when socketPath.isNotEmpty =>
        ServerInfo(pid: pid, socketPath: socketPath),
      _ => throw FormatException(
        'server.json must contain an int "pid" and a String "socketPath".',
        source,
      ),
    };
  }

  /// Process ID of the running backend server.
  final int pid;

  /// Unix domain socket path where the server is listening.
  final String socketPath;
}
