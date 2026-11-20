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

/// The requested resource does not exist (`404`).
final class NotFoundFailure extends Failure {
  /// Creates a not-found failure.
  const new(super.message);
}

/// Input or state failed domain validation (`400`).
final class ValidationFailure extends Failure {
  /// Creates a validation failure.
  const new(super.message);
}

/// The operation conflicts with the current state of a resource (`409`).
final class ConflictFailure extends Failure {
  /// Creates a conflict failure.
  const new(super.message);
}

/// A persistence operation (for example SQLite) failed (`500`).
final class PersistenceFailure extends Failure {
  /// Creates a persistence failure.
  const new(super.message, {this.cause});

  /// Optional underlying cause for logging; never exposed over HTTP.
  final Object? cause;
}

/// An unexpected internal failure (`500`).
final class UnexpectedFailure extends Failure {
  /// Creates an unexpected failure.
  const new(super.message, {this.cause});

  /// Optional underlying cause for logging; never exposed over HTTP.
  final Object? cause;
}
