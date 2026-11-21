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
  static const int _requestTimeoutSeconds = 15;

  /// Default timeout for socket connect, HTTP status requests, and WebSocket
  /// upgrade.
  static const Duration defaultConnectTimeout = Duration(
    seconds: _connectTimeoutSeconds,
  );

  /// Default timeout to receive `server.hello` after WebSocket upgrade.
  static const Duration defaultHandshakeTimeout = Duration(
    seconds: _handshakeTimeoutSeconds,
  );

  /// Default timeout for feature HTTP JSON requests.
  static const Duration defaultRequestTimeout = Duration(
    seconds: _requestTimeoutSeconds,
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

      if (isDegradedCode) {
        return FailureResult(
          BackendFailure(
            _tryExtractDegradedMessage(body) ??
                'Backend is degraded (status ${response.statusCode}).',
            code: BackendFailureCode.degraded,
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
      if (status.status == BackendStatus.degraded) {
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
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) =>
      _requestJson('GET', path, timeout: timeout);

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) => _requestJson('POST', path, body: body, timeout: timeout);

  Future<Result<JsonMap>> _requestJson(
    String method,
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) async {
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
    final effectiveTimeout = timeout ?? defaultRequestTimeout;

    try {
      final response = await () async {
        final uri = Uri.parse('http://localhost$path');
        final request = method == 'POST'
            ? await client.postUrl(uri)
            : await client.getUrl(uri);
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }
        return await request.close();
      }().timeout(effectiveTimeout);

      final rawBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(effectiveTimeout);

      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices) {
        return FailureResult(_mapHttpError(response.statusCode, rawBody));
      }

      if (rawBody.trim().isEmpty) {
        return const Success(<String, Object?>{});
      }

      final decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, Object?>) {
        return const FailureResult(
          BackendFailure('Invalid JSON response payload.'),
        );
      }
      return Success(decoded);
    } on TimeoutException catch (error) {
      _resetHttpClient();
      return FailureResult(
        NetworkFailure(
          'Timed out waiting for backend response.',
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
        UnexpectedFailure('Unexpected error during request.', cause: error),
      );
    }
  }

  Failure _mapHttpError(int statusCode, String rawBody) {
    String? code;
    var message = 'Request failed with status $statusCode.';
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, Object?>) {
        final apiError = ApiError.fromJson(decoded);
        code = apiError.code;
        message = apiError.message;
      }
    } on Object {
      // Keep default status message when body is not an ApiError JSON object.
    }
    if (statusCode == HttpStatus.notFound) {
      return NotFoundFailure(message);
    }
    return BackendFailure(message, code: code, statusCode: statusCode);
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
  Future<Result<JsonMap>> putJson(String path, JsonMap body) =>
      sendJsonRequest('PUT', path, body: body);

  @override
  Future<Result<void>> delete(String path) async {
    final result = await sendJsonRequest('DELETE', path);
    return result.map((_) {});
  }

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async {
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
      final payload = jsonEncode(ShutdownRequest(force: force).toJson());
      final response = await () async {
        final request = await client.postUrl(
          Uri.parse('http://localhost/api/v1/shutdown'),
        );
        request.headers.contentType = ContentType.json;
        request.write(payload);
        return await request.close();
      }().timeout(connectTimeout);

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(connectTimeout);

      if (response.statusCode == HttpStatus.conflict) {
        return FailureResult(
          BackendFailure(
            _tryExtractApiErrorMessage(body) ??
                'Backend has active runs; force shutdown required.',
            code: ApiErrorCode.conflict,
            statusCode: response.statusCode,
          ),
        );
      }

      if (response.statusCode != HttpStatus.accepted &&
          response.statusCode != HttpStatus.ok) {
        return FailureResult(
          BackendFailure(
            'Shutdown request failed with status ${response.statusCode}.',
            statusCode: response.statusCode,
          ),
        );
      }

      if (body.trim().isEmpty) {
        return const Success(ShutdownResponse());
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) {
        return const FailureResult(
          BackendFailure('Invalid shutdown response payload.'),
        );
      }
      return Success(ShutdownResponse.fromJson(decoded));
    } on TimeoutException catch (error) {
      _resetHttpClient();
      return FailureResult(
        NetworkFailure(
          'Timed out waiting for backend shutdown.',
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
        UnexpectedFailure(
          'Unexpected error requesting shutdown.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async {
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
        final request = await client.openUrl(
          method,
          Uri.parse('http://localhost$path'),
        );
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }
        return await request.close();
      }().timeout(connectTimeout);

      final rawBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(connectTimeout);

      final decoded = rawBody.trim().isEmpty
          ? <String, Object?>{}
          : jsonDecode(rawBody);
      if (decoded is! Map<String, Object?>) {
        return const FailureResult(
          BackendFailure('Invalid JSON response payload.'),
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Success(decoded);
      }

      final apiError = _tryParseApiError(decoded);
      final message =
          apiError?.message ??
          'Request failed with status ${response.statusCode}.';
      if (response.statusCode == HttpStatus.notFound) {
        return FailureResult(NotFoundFailure(message));
      }
      if (response.statusCode == HttpStatus.badRequest) {
        return FailureResult(ValidationFailure(message));
      }
      return FailureResult(
        BackendFailure(
          message,
          code: apiError?.code,
          statusCode: response.statusCode,
        ),
      );
    } on TimeoutException catch (error) {
      _resetHttpClient();
      return FailureResult(
        NetworkFailure(
          'Timed out waiting for backend response.',
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
        UnexpectedFailure('Unexpected error calling backend.', cause: error),
      );
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    _resetHttpClient();
  }

  String? _tryExtractApiErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) return null;
      return ApiError.fromJson(decoded).message;
    } on Object {
      return null;
    }
  }

  ApiError? _tryParseApiError(JsonMap json) {
    try {
      return ApiError.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  String? _tryExtractDegradedMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) return null;
      return StatusResponse.fromJson(decoded).database.error;
    } on Object {
      return null;
    }
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
