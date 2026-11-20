import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/backend/server_info.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [BackendClient] implementation that speaks HTTP and WebSocket over the
/// backend's Unix domain socket (ADR 0011).
final class UnixSocketBackendClient implements BackendClient {
  /// Creates a client that discovers the backend socket from [_platformPaths].
  new({required this._platformPaths});

  final PlatformPaths _platformPaths;
  HttpClient? _httpClient;
  String? _activeSocketPath;
  bool _closed = false;

  @override
  Future<Result<HealthResponse>> checkHealth() async {
    if (_closed) {
      return const FailureResult(
        NetworkFailure('Backend client has been closed.'),
      );
    }

    final clientResult = await _ensureHttpClient();
    if (clientResult case FailureResult<HttpClient>(:final failure)) {
      return FailureResult(failure);
    }
    final client = (clientResult as Success<HttpClient>).value;

    try {
      final request = await client.getUrl(Uri.parse('http://localhost/health'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != HttpStatus.ok) {
        return FailureResult(
          BackendFailure(
            'Health check failed with status ${response.statusCode}.',
            statusCode: response.statusCode,
          ),
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const FailureResult(
          BackendFailure('Invalid health response payload.'),
        );
      }
      return Success(HealthResponse.fromJson(decoded));
    } on SocketException catch (error) {
      return FailureResult(
        NetworkFailure('Unable to reach backend socket.', cause: error),
      );
    } on HttpException catch (error) {
      return FailureResult(
        NetworkFailure('HTTP transport error.', cause: error),
      );
    } on FormatException catch (error) {
      return FailureResult(
        BackendFailure('Malformed JSON from backend: ${error.message}'),
      );
    } on Object catch (error) {
      return FailureResult(
        UnexpectedFailure('Unexpected error checking health.', cause: error),
      );
    }
  }

  @override
  Future<Result<WebSocket>> connectWebSocket() async {
    if (_closed) {
      return const FailureResult(
        NetworkFailure('Backend client has been closed.'),
      );
    }

    final clientResult = await _ensureHttpClient();
    if (clientResult case FailureResult<HttpClient>(:final failure)) {
      return FailureResult(failure);
    }
    final client = (clientResult as Success<HttpClient>).value;

    try {
      final socket = await WebSocket.connect(
        'ws://localhost/ws',
        customClient: client,
      );
      return Success(socket);
    } on SocketException catch (error) {
      return FailureResult(
        NetworkFailure('Unable to open WebSocket on backend.', cause: error),
      );
    } on WebSocketException catch (error) {
      return FailureResult(
        NetworkFailure('WebSocket upgrade failed.', cause: error),
      );
    } on Object catch (error) {
      return FailureResult(
        UnexpectedFailure(
          'Unexpected error connecting WebSocket.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    _httpClient?.close(force: true);
    _httpClient = null;
    _activeSocketPath = null;
  }

  Future<Result<HttpClient>> _ensureHttpClient() async {
    final infoResult = await _readServerInfo();
    if (infoResult case FailureResult<ServerInfo>(:final failure)) {
      return FailureResult(failure);
    }
    final socketPath = (infoResult as Success<ServerInfo>).value.socketPath;

    if (_httpClient != null && _activeSocketPath == socketPath) {
      return Success(_httpClient!);
    }

    _httpClient?.close(force: true);
    final client = HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) {
        final address = InternetAddress(
          socketPath,
          type: InternetAddressType.unix,
        );
        return Socket.startConnect(address, 0);
      };
    _httpClient = client;
    _activeSocketPath = socketPath;
    return Success(client);
  }

  Future<Result<ServerInfo>> _readServerInfo() async {
    final path = _platformPaths.serverInfoPath();
    final file = File(path);
    try {
      if (!file.existsSync()) {
        return FailureResult(
          NetworkFailure('Backend server.json not found at $path.'),
        );
      }
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const FailureResult(
          BackendFailure('Invalid server.json format.'),
        );
      }
      return Success(ServerInfo.fromJson(decoded));
    } on FileSystemException catch (error) {
      return FailureResult(
        NetworkFailure('Failed to read server.json.', cause: error),
      );
    } on FormatException catch (error) {
      return FailureResult(
        BackendFailure('Malformed server.json: ${error.message}'),
      );
    }
  }
}
