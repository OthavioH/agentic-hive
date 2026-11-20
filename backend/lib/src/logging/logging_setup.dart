import 'dart:async';

import 'package:agentic_hive_backend/src/logging/log_sink.dart';
import 'package:logging/logging.dart';

/// Connects the root [Logger] to the configured sinks for the lifetime of the
/// backend.
final class LoggingSetup {
  /// Sets the root level and starts forwarding every record to [sinks].
  new({required Level level, required List<LogSink> sinks})
    : _sinks = List.unmodifiable(sinks) {
    Logger.root.level = level;
    _subscription = Logger.root.onRecord.listen(_forward);
  }

  final List<LogSink> _sinks;
  late final StreamSubscription<LogRecord> _subscription;

  void _forward(LogRecord record) {
    for (final sink in _sinks) {
      sink.write(record);
    }
  }

  /// Stops forwarding and flushes and closes every sink.
  Future<void> close() async {
    await _subscription.cancel();
    for (final sink in _sinks) {
      await sink.close();
    }
  }
}
