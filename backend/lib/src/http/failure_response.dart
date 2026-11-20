import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/http/json_response.dart';
import 'package:agentic_hive_backend/src/http/request_context.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';

/// An HTTP status code paired with its [ApiError] response body.
typedef HttpFailureMapping = ({int statusCode, ApiError error});

/// Maps a domain or data-layer [failure] to an HTTP status code and [ApiError].
///
/// Internal failures ([PersistenceFailure], [UnexpectedFailure]) never expose
/// their internal [Failure.message] over HTTP.
HttpFailureMapping mapFailureToHttp(Failure failure, {String? requestId}) =>
    switch (failure) {
      NotFoundFailure(:final message) => (
        statusCode: 404,
        error: ApiError(
          code: ApiErrorCode.notFound,
          message: message,
          requestId: requestId,
        ),
      ),
      ValidationFailure(:final message) => (
        statusCode: 400,
        error: ApiError(
          code: ApiErrorCode.badRequest,
          message: message,
          requestId: requestId,
        ),
      ),
      ConflictFailure(:final message) => (
        statusCode: 409,
        error: ApiError(
          code: ApiErrorCode.conflict,
          message: message,
          requestId: requestId,
        ),
      ),
      PersistenceFailure() || UnexpectedFailure() => (
        statusCode: 500,
        error: ApiError(
          code: ApiErrorCode.internalError,
          message: 'Internal server error.',
          requestId: requestId,
        ),
      ),
    };

/// Builds a JSON [Response] for [failure], tagged with the request id.
Response failureResponse(Request request, Failure failure) {
  final mapped = mapFailureToHttp(failure, requestId: requestIdOf(request));
  return jsonResponse(mapped.statusCode, mapped.error);
}
