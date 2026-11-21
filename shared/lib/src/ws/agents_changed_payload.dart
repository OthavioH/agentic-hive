import 'package:agentic_hive_shared/src/agents/agent_summary.dart';
import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agents_changed_payload.freezed.dart';
part 'agents_changed_payload.g.dart';

/// Kind of filesystem change reported in [AgentsChangedPayload].
enum AgentChangeKind {
  /// A new `<id>.md` file appeared on disk.
  created,

  /// An existing `<id>.md` file was modified on disk.
  updated,

  /// An `<id>.md` file was removed from disk.
  deleted,
}

/// Payload of an `agents.changed` WebSocket event.
@freezed
sealed class AgentsChangedPayload with _$AgentsChangedPayload {
  /// Creates an agents-changed payload.
  const factory({
    required AgentChangeKind kind,
    required String id,
    AgentSummary? agent,
  }) = _AgentsChangedPayload;

  /// Decodes an agents-changed payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$AgentsChangedPayloadFromJson);
}
