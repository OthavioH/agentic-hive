/// A structured log message. Pass it as the message of a `Logger` call:
///
/// ```dart
/// _log.info(LogEvent('http.request', fields: {'status': 200}));
/// ```
///
/// Rules (see `backend/AGENTS.md`, Logging):
/// - [fields] hold ids, counts, durations and statuses. Never user content.
/// - [userContent] holds prompts, agent output or file content. It is only
///   written for records below `INFO` (that is, `FINE` and finer), truncated.
final class LogEvent {
  /// Creates an event named [name].
  const new(this.name, {this.fields = const {}, this.userContent});

  /// A stable, dotted event name, such as `http.request`.
  final String name;

  /// Ids, counts, durations and statuses. Never user content.
  final Map<String, Object?> fields;

  /// User content, written only below `INFO`, truncated.
  final String? userContent;

  @override
  String toString() => name;
}
