import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backend_connection_config.g.dart';

/// Timing and randomness hooks for `BackendConnection`, injectable in tests
/// via `backendConnectionConfigProvider`.
final class BackendConnectionConfig {
  /// Creates a connection configuration with production defaults.
  const new({
    this.now = DateTime.now,
    this.createTimer = Timer.new,
    this.random,
    this.nextRandomDouble,
    this.gracePeriod = defaultGracePeriod,
    this.maxBackoff = defaultMaxBackoff,
  });

  static const int _graceSeconds = 2;
  static const int _maxBackoffSeconds = 10;

  /// Default 2-second silent grace period on WebSocket drop.
  static const Duration defaultGracePeriod = Duration(seconds: _graceSeconds);

  /// Default 10-second backoff cap.
  static const Duration defaultMaxBackoff = Duration(
    seconds: _maxBackoffSeconds,
  );

  /// Returns the current wall-clock time.
  final DateTime Function() now;

  /// Creates a one-shot [Timer].
  final Timer Function(Duration duration, void Function() callback) createTimer;

  /// Optional [Random] instance for jitter.
  final Random? random;

  /// Optional deterministic `[0, 1)` generator for jitter.
  final double Function()? nextRandomDouble;

  /// Maximum duration to stay in the shell while silently reconnecting.
  final Duration gracePeriod;

  /// Maximum backoff delay between automatic retries.
  final Duration maxBackoff;

  /// Returns a value in `[0.0, 1.0)` for backoff jitter.
  double sampleRandomDouble() {
    final override = nextRandomDouble;
    if (override != null) return override();
    return (random ?? _sharedRandom).nextDouble();
  }

  static final Random _sharedRandom = Random();
}

/// Provides [BackendConnectionConfig] for `BackendConnection`.
///
/// Tests can override this provider to control clocks, timers, and jitter
/// deterministically.
@Riverpod(keepAlive: true)
BackendConnectionConfig backendConnectionConfig(Ref ref) =>
    const BackendConnectionConfig();
