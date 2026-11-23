import 'package:agentic_hive_shared/agentic_hive_shared.dart';

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
  /// Creates a validation failure with optional per-field [details].
  const new(super.message, {this.details});

  /// Optional per-field validation error messages (field key -> message).
  final Map<String, String>? details;
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

/// A harness CLI failed because the user is not signed in or credentials
/// expired (ADR 0002).
final class HarnessAuthenticationFailure extends Failure {
  /// Creates a harness authentication failure.
  const new(super.message, {required this.harnessType});

  /// Canonical `WorkflowNode.type` of the harness that failed authentication.
  final String harnessType;
}

/// A harness CLI failed because a rate limit or quota was exhausted (ADR 0002).
final class HarnessRateLimitFailure extends Failure {
  /// Creates a harness rate-limit/quota failure.
  const new(super.message, {required this.harnessType});

  /// Canonical `WorkflowNode.type` of the harness that hit the limit.
  final String harnessType;
}

/// A node did not finish because it needs a human before the run can go on.
///
/// Returned (never thrown) by a node or port that wants the run paused
/// (ADR 0007, ADR 0019). The engine persists a checkpoint and releases the run
/// from memory instead of counting this as a failure.
final class PauseRequestedFailure extends Failure {
  /// Creates a pause request.
  const new(
    super.message, {
    required this.kind,
    required this.runId,
    required this.nodeId,
    this.question,
  });

  /// What the node is waiting for.
  final PauseKind kind;

  /// Run that must pause.
  final String runId;

  /// Node that requested the pause.
  final String nodeId;

  /// Question or instructions shown to the human, when known.
  final String? question;
}

/// A node failed due to an infrastructure error (missing report, non-zero
/// exit, timeout, or process spawn error).
final class NodeExecutionFailure extends Failure {
  /// Creates a node execution failure.
  const new(super.message, {this.exitCode, this.cause});

  /// Optional process exit code.
  final int? exitCode;

  /// Optional underlying cause for logging.
  final Object? cause;
}

/// Installing or updating the Hive MCP server in a harness CLI failed (`500`).
final class HarnessMcpInstallFailure extends Failure {
  /// Creates an MCP installation failure with a safe CLI summary [message].
  const new(super.message);
}
