import 'dart:convert';
import 'dart:io';

/// Another backend already answers on the socket.
final class BackendAlreadyRunningException implements Exception {
  /// Creates the exception for [socketPath].
  const new(this.socketPath);

  /// The socket a live backend answers on.
  final String socketPath;

  @override
  String toString() =>
      'Another Agentic Hive backend is already running on $socketPath.';
}

/// The socket path is longer than the operating system accepts.
final class SocketPathTooLongException implements Exception {
  /// Creates the exception for [socketPath].
  const new(this.socketPath, this.maxBytes);

  /// The rejected path.
  final String socketPath;

  /// The platform's limit, in bytes.
  final int maxBytes;

  @override
  String toString() =>
      'The socket path is longer than $maxBytes bytes, the limit of this '
      'operating system: $socketPath. Choose a shorter data folder.';
}

/// The Unix domain socket the backend listens on (ADR 0011).
final class LocalSocket {
  /// Creates the socket description for [path].
  new(this.path, {required this.maxPathBytes});

  /// Path of the socket file.
  final String path;

  /// The platform's socket path limit, in bytes.
  final int maxPathBytes;

  /// The address to bind or connect to.
  InternetAddress get address =>
      InternetAddress(path, type: InternetAddressType.unix);

  bool get _exists =>
      FileSystemEntity.typeSync(path, followLinks: false) !=
      FileSystemEntityType.notFound;

  /// Checks the path length and clears a socket file left by a backend that
  /// is gone. Throws [BackendAlreadyRunningException] when a live backend
  /// answers on it, which also keeps a single backend per data folder.
  Future<void> prepare() async {
    final length = utf8.encode(path).length;
    if (length > maxPathBytes) {
      throw SocketPathTooLongException(path, maxPathBytes);
    }
    if (!_exists) return;
    if (await _isAlive()) throw BackendAlreadyRunningException(path);
    delete();
  }

  /// Removes the socket file, if present.
  void delete() {
    if (!_exists) return;
    try {
      File(path).deleteSync();
    } on FileSystemException {
      // Already removed by the operating system.
    }
  }

  Future<bool> _isAlive() async {
    try {
      final socket = await Socket.connect(
        address,
        0,
        timeout: const Duration(seconds: 1),
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    }
  }
}
