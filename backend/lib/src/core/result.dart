import 'package:agentic_hive_backend/src/core/failure.dart';

/// The outcome of a fallible operation: either [Success] or [FailureResult].
sealed class Result<T> {
  const new();

  /// Whether this result holds a [Success] value.
  bool get isSuccess => this is Success<T>;

  /// Whether this result holds a [FailureResult].
  bool get isFailure => this is FailureResult<T>;

  /// The success value, or `null` when this is a [FailureResult].
  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    FailureResult<T>() => null,
  };

  /// The failure, or `null` when this is a [Success].
  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    FailureResult<T>(:final failure) => failure,
  };

  /// Reduces this result by running [onSuccess] or [onFailure].
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    FailureResult<T>(:final failure) => onFailure(failure),
  };

  /// Transforms the value of a [Success], leaving a [FailureResult] untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Success<R>(transform(value)),
    FailureResult<T>(:final failure) => FailureResult<R>(failure),
  };

  /// Chains another fallible operation on a [Success], short-circuiting on a
  /// [FailureResult].
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Success<T>(:final value) => transform(value),
    FailureResult<T>(:final failure) => FailureResult<R>(failure),
  };
}

/// A successful [Result] holding [value].
final class Success<T> extends Result<T> {
  /// Creates a success result.
  const new(this.value);

  /// The produced value.
  final T value;
}

/// A failed [Result] holding [failure].
final class FailureResult<T> extends Result<T> {
  /// Creates a failure result.
  const new(this.failure);

  /// The domain or data-layer failure.
  final Failure failure;
}
