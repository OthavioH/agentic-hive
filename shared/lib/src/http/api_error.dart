import 'package:agentic_hive_shared/src/json_fields.dart';

/// The body of every HTTP error response: `{"error": {...}}`.
final class ApiError {
  /// Creates an error body.
  const new({required this.code, required this.message, this.requestId});

  /// Decodes an error body; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) {
    final error = readObject(json, 'error');
    return ApiError(
      code: readField<String>(error, 'code'),
      message: readField<String>(error, 'message'),
      requestId: readField<String?>(error, 'requestId'),
    );
  }

  /// A stable, machine-readable error code from [ApiErrorCode].
  final String code;

  /// A human-readable description. Never contains a stack trace.
  final String message;

  /// The id of the request that failed, also sent as `X-Request-Id`.
  final String? requestId;

  /// Encodes this error as the JSON response body.
  JsonMap toJson() => {
    'error': {'code': code, 'message': message, 'requestId': ?requestId},
  };
}

/// Error codes the backend can return in [ApiError.code].
abstract final class ApiErrorCode {
  /// An unexpected failure inside the backend (`500`).
  static const internalError = 'internal_error';

  /// No route matches the request (`404`).
  static const notFound = 'not_found';

  /// The request carried an `Origin` header (`403`).
  static const originNotAllowed = 'origin_not_allowed';

  /// `GET /ws` was called without a WebSocket upgrade (`426`).
  static const upgradeRequired = 'upgrade_required';

  /// The WebSocket upgrade request was malformed (`400`).
  static const invalidWebSocketHandshake = 'invalid_websocket_handshake';
}
