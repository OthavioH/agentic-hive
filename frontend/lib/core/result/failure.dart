/// Base type for expected domain and data-layer failures returned in a
/// `Result`.
///
/// Exceptions are reserved for bugs; fallible operations return a [Failure]
/// subtype instead.
sealed class Failure {
  /// Creates a failure with a human-readable [message].
  const new(this.message);

  /// A short description of the failure.
  final String message;
}

/// The local backend could not be reached or a transport error occurred.
final class NetworkFailure extends Failure {
  /// Creates a network failure.
  const new(super.message, {this.cause, this.code});

  /// Optional underlying cause for diagnostics.
  final Object? cause;

  /// Optional machine-readable error code for transport categorization.
  final String? code;
}

/// The backend returned a non-success response or protocol error.
final class BackendFailure extends Failure {
  /// Creates a backend failure.
  const new(super.message, {this.code, this.statusCode});

  /// Optional machine-readable error code from the backend.
  final String? code;

  /// Optional HTTP status code from the backend.
  final int? statusCode;
}

/// The requested resource does not exist.
final class NotFoundFailure extends Failure {
  /// Creates a not-found failure.
  const new(super.message);
}

/// Input or state failed validation.
final class ValidationFailure extends Failure {
  /// Creates a validation failure.
  const new(super.message);
}

/// The operation conflicts with the current state of a resource.
final class ConflictFailure extends Failure {
  /// Creates a conflict failure.
  const new(super.message);
}

/// An unexpected internal failure.
final class UnexpectedFailure extends Failure {
  /// Creates an unexpected failure.
  const new(super.message, {this.cause});

  /// Optional underlying cause for diagnostics.
  final Object? cause;
}
