import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/core/backend/server_info.dart';
import 'package:agentic_hive_frontend/core/backend/socket_backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [BackendClient] implementation that speaks HTTP and WebSocket over the
/// backend's Unix domain socket (ADR 0011).
final class UnixSocketBackendClient implements BackendClient {
  /// Creates a client that discovers the backend socket from [_platformPaths].
  new({
    required this._platformPaths,
    this.connectTimeout = defaultConnectTimeout,
    this.handshakeTimeout = defaultHandshakeTimeout,
  });

  static const int _connectTimeoutSeconds = 2;
  static const int _handshakeTimeoutSeconds = 3;

  /// Default timeout for socket connect, HTTP status requests, and WebSocket
  /// upgrade.
  static const Duration defaultConnectTimeout = Duration(
    seconds: _connectTimeoutSeconds,
  );

  /// Default timeout to receive `server.hello` after WebSocket upgrade.
  static const Duration defaultHandshakeTimeout = Duration(
    seconds: _handshakeTimeoutSeconds,
  );

  final PlatformPaths _platformPaths;

  /// Timeout applied to socket connect, HTTP status requests, and WebSocket
  /// upgrade.
  final Duration connectTimeout;

  /// Timeout applied when waiting for `server.hello` after WebSocket upgrade.
  final Duration handshakeTimeout;

  HttpClient? _httpClient;
  String? _activeSocketPath;
  bool _closed = false;

  @override
  Future<Result<StatusResponse>> checkStatus() async {
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
      final response = await () async {
        final request = await client.getUrl(
          Uri.parse('http://localhost/api/v1/status'),
        );
        return await request.close();
      }().timeout(connectTimeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(connectTimeout);

      final isOk = response.statusCode == HttpStatus.ok;
      final isDegradedCode =
          response.statusCode == HttpStatus.serviceUnavailable;

      if (!isOk && !isDegradedCode) {
        return FailureResult(
          BackendFailure(
            'Status check failed with status ${response.statusCode}.',
            statusCode: response.statusCode,
          ),
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) {
        return const FailureResult(
          BackendFailure('Invalid status response payload.'),
        );
      }
      final status = StatusResponse.fromJson(decoded);
      if (isDegradedCode || status.status == BackendStatus.degraded) {
        return FailureResult(
          BackendFailure(
            status.database.error ??
                'Backend is degraded (status ${response.statusCode}).',
            code: BackendFailureCode.degraded,
            statusCode: response.statusCode,
          ),
        );
      }
      return Success(status);
    } on TimeoutException catch (error) {
      _resetHttpClient();
      return FailureResult(
        NetworkFailure(
          'Timed out waiting for backend status.',
          cause: error,
          code: BackendFailureCode.timeout,
        ),
      );
    } on SocketException catch (error) {
      _resetHttpClient();
      return FailureResult(
        NetworkFailure(
          'Unable to reach backend socket.',
          cause: error,
          code: BackendFailureCode.connectionRefused,
        ),
      );
    } on HttpException catch (error) {
      _resetHttpClient();
      return FailureResult(
        NetworkFailure('HTTP transport error.', cause: error),
      );
    } on FormatException catch (error) {
      return FailureResult(
        BackendFailure('Malformed JSON from backend: ${error.message}'),
      );
    } on Object catch (error) {
      _resetHttpClient();
      return FailureResult(
        UnexpectedFailure('Unexpected error checking status.', cause: error),
      );
    }
  }

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async {
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
      ).timeout(connectTimeout);

      return await SocketBackendWebSocketSession.connect(
        socket,
        handshakeTimeout: handshakeTimeout,
        onClosed: _resetHttpClient,
      );
    } on TimeoutException catch (error) {
      _resetHttpClient();
      return FailureResult(
        NetworkFailure(
          'Timed out opening WebSocket connection.',
          cause: error,
          code: BackendFailureCode.timeout,
        ),
      );
    } on SocketException catch (error) {
      _resetHttpClient();
      return FailureResult(
        NetworkFailure(
          'Unable to open WebSocket on backend.',
          cause: error,
          code: BackendFailureCode.connectionRefused,
        ),
      );
    } on WebSocketException catch (error) {
      _resetHttpClient();
      return FailureResult(
        NetworkFailure('WebSocket upgrade failed.', cause: error),
      );
    } on Object catch (error) {
      _resetHttpClient();
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
    _resetHttpClient();
  }

  void _resetHttpClient() {
    _httpClient?.close(force: true);
    _httpClient = null;
    _activeSocketPath = null;
  }

  Future<Result<HttpClient>> _ensureHttpClient() async {
    final infoResult = await _readServerInfo();
    if (infoResult case FailureResult<ServerInfo>(:final failure)) {
      _resetHttpClient();
      return FailureResult(failure);
    }
    final socketPath = (infoResult as Success<ServerInfo>).value.socketPath;

    if (_httpClient != null && _activeSocketPath == socketPath) {
      return Success(_httpClient!);
    }

    _resetHttpClient();
    final client = HttpClient()
      ..connectionTimeout = connectTimeout
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
          NetworkFailure(
            'Backend server.json not found at $path.',
            code: BackendFailureCode.notRunning,
          ),
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
