import 'package:agentic_hive_shared/src/json_fields.dart';

/// Overall backend status reported by `GET /api/v1/status`.
enum BackendStatus {
  /// Every check passed.
  ok,

  /// The process is up, but a dependency (such as the database) failed.
  degraded,
}

/// Body of `GET /api/v1/status`.
final class StatusResponse {
  /// Creates a status body.
  const new({
    required this.status,
    required this.version,
    required this.uptimeSeconds,
    required this.dataDir,
    required this.database,
  });

  /// Decodes a status body; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => StatusResponse(
    status: _parseStatus(readField<String>(json, 'status')),
    version: readField<String>(json, 'version'),
    uptimeSeconds: readField<int>(json, 'uptimeSeconds'),
    dataDir: readField<String>(json, 'dataDir'),
    database: DatabaseStatus.fromJson(readObject(json, 'database')),
  );

  /// Whether every check passed.
  final BackendStatus status;

  /// Backend version, such as `0.1.0`.
  final String version;

  /// Seconds since the backend started.
  final int uptimeSeconds;

  /// Absolute path of the backend's data folder.
  final String dataDir;

  /// Result of the database check.
  final DatabaseStatus database;

  /// Encodes this status as the JSON response body.
  JsonMap toJson() => {
    'status': status.name,
    'version': version,
    'uptimeSeconds': uptimeSeconds,
    'dataDir': dataDir,
    'database': database.toJson(),
  };
}

/// Result of the database check inside [StatusResponse].
final class DatabaseStatus {
  /// Creates a database check result.
  const new({required this.ok, this.schemaVersion, this.error});

  /// Decodes a database check result; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) => DatabaseStatus(
    ok: switch (readField<String>(json, 'status')) {
      'ok' => true,
      'error' => false,
      final other => throw FormatException(
        'Expected "status" to be "ok" or "error", got "$other".',
      ),
    },
    schemaVersion: readField<int?>(json, 'schemaVersion'),
    error: readField<String?>(json, 'error'),
  );

  /// Whether the database answered queries.
  final bool ok;

  /// The schema version stored in the database, when it answered.
  final int? schemaVersion;

  /// A short description of the failure. Never contains user content.
  final String? error;

  /// Encodes this result as JSON.
  JsonMap toJson() => {
    'status': ok ? 'ok' : 'error',
    'schemaVersion': ?schemaVersion,
    'error': ?error,
  };
}

BackendStatus _parseStatus(String value) {
  for (final status in BackendStatus.values) {
    if (status.name == value) return status;
  }
  throw FormatException('Unknown backend status "$value".');
}
