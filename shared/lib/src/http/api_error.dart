import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_error.freezed.dart';
part 'api_error.g.dart';

/// The body of every HTTP error response: `{"error": {...}}`.
@Freezed(toJson: false)
sealed class ApiError with _$ApiError {
  /// Creates an error body.
  const factory({
    required String code,
    required String message,
    String? requestId,
    Map<String, String>? details,
  }) = _ApiError;

  const new _();

  /// Decodes an error body; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(readObject(json, 'error'), _$ApiErrorFromJson);

  /// Encodes this error as the JSON response body.
  JsonMap toJson() => {
    'error': {
      'code': code,
      'message': message,
      'requestId': ?requestId,
      'details': ?details,
    },
  };
}

/// Error codes the backend can return in [ApiError.code].
abstract final class ApiErrorCode {
  /// An unexpected failure inside the backend (`500`).
  static const internalError = 'internal_error';

  /// No route matches the request (`404`).
  static const notFound = 'not_found';

  /// The request payload or parameters failed validation (`400`).
  static const badRequest = 'bad_request';

  /// The request conflicts with the current state of a resource (`409`).
  static const conflict = 'conflict';

  /// The request carried an `Origin` header (`403`).
  static const originNotAllowed = 'origin_not_allowed';

  /// `GET /ws` was called without a WebSocket upgrade (`426`).
  static const upgradeRequired = 'upgrade_required';

  /// The WebSocket upgrade request was malformed (`400`).
  static const invalidWebSocketHandshake = 'invalid_websocket_handshake';
}
