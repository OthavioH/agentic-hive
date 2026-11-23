import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'status_response.freezed.dart';
part 'status_response.g.dart';

/// Overall backend status reported by `GET /api/v1/status`.
enum BackendStatus {
  /// Every check passed.
  ok,

  /// The process is up, but a dependency (such as the database) failed.
  degraded,
}

/// Body of `GET /api/v1/status`.
@freezed
sealed class StatusResponse with _$StatusResponse {
  /// Creates a status body.
  const factory({
    required BackendStatus status,
    required String version,
    required int uptimeSeconds,
    required String dataDir,
    required DatabaseStatus database,
    @Default(0) int activeRuns,
  }) = _StatusResponse;

  /// Decodes a status body; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$StatusResponseFromJson);
}

/// Result of the database check inside [StatusResponse].
@freezed
sealed class DatabaseStatus with _$DatabaseStatus {
  /// Creates a database check result.
  const factory({
    @JsonKey(
      name: 'status',
      fromJson: _dbStatusFromJson,
      toJson: _dbStatusToJson,
    )
    required bool ok,
    int? schemaVersion,
    String? error,
  }) = _DatabaseStatus;

  /// Decodes a database check result; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) => parseJson(json, _$DatabaseStatusFromJson);
}

bool _dbStatusFromJson(String value) => switch (value) {
  'ok' => true,
  'error' => false,
  final other => throw FormatException(
    'Expected "status" to be "ok" or "error", got "$other".',
  ),
};

String _dbStatusToJson(bool ok) => ok ? 'ok' : 'error';
