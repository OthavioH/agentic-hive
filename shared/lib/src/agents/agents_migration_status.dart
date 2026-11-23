import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agents_migration_status.freezed.dart';
part 'agents_migration_status.g.dart';

/// Outcome of moving the global agents from the app-data `agents` folder into
/// `~/.agents/agents` (ADR 0025), as reported by
/// `GET /api/v1/agent-library/migration`.
///
/// The move never overwrites an existing file. A [conflicts] entry is a file
/// that exists in both folders with different content: the file in
/// [targetDir] was kept and the copy in [legacyDir] was left untouched.
@freezed
sealed class AgentsMigrationStatus with _$AgentsMigrationStatus {
  /// Creates a migration status.
  const factory({
    required String legacyDir,
    required String targetDir,
    @Default(<String>[]) List<String> conflicts,
    @Default(false) bool dismissed,
  }) = _AgentsMigrationStatus;

  const new _();

  /// Decodes a migration status; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$AgentsMigrationStatusFromJson);

  /// Whether the user should still be told about [conflicts].
  bool get hasPendingConflicts => conflicts.isNotEmpty && !dismissed;
}
