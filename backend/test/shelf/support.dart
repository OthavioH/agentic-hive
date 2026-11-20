import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/db/database_health_check.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

/// Builds an in-process request to `http://localhost<path>`.
Request buildRequest(
  String path, {
  String method = 'GET',
  Map<String, String> headers = const {},
}) => Request(method, Uri.parse('http://localhost$path'), headers: headers);

/// Decodes the JSON object in the body of [response].
Future<JsonMap> readJson(Response response) async =>
    jsonDecode(await response.readAsString()) as JsonMap;

/// A [DatabaseHealthCheck] that returns [result] and counts its calls.
final class FakeDatabaseHealthCheck implements DatabaseHealthCheck {
  /// Creates a fake that answers [result].
  new(this.result);

  /// The status returned by [check].
  DatabaseStatus result;

  /// Number of times [check] ran.
  int calls = 0;

  @override
  Future<DatabaseStatus> check() async {
    calls++;
    return result;
  }
}

/// Captures every log record emitted while it is attached.
///
/// Sets the root level to [Level.ALL] on [attach] and restores the previous
/// level on [detach].
final class LogCapture {
  /// The captured records, in order.
  final records = <LogRecord>[];

  StreamSubscription<LogRecord>? _subscription;
  Level? _previousLevel;

  /// Starts capturing.
  void attach() {
    records.clear();
    _previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    _subscription = Logger.root.onRecord.listen(records.add);
  }

  /// Stops capturing and restores the root level.
  Future<void> detach() async {
    await _subscription?.cancel();
    _subscription = null;
    final previous = _previousLevel;
    if (previous != null) Logger.root.level = previous;
  }
}
