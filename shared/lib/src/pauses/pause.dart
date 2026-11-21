import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/pauses/pause_kind.dart';
import 'package:agentic_hive_shared/src/pauses/pause_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pause.freezed.dart';
part 'pause.g.dart';

/// A durable human-in-the-loop pause for a workflow run (`HumanApprovalNode`
/// or `ask_human`).
@freezed
sealed class Pause with _$Pause {
  /// Creates a pause record.
  const factory({
    required String id,
    required String runId,
    required String nodeId,
    required PauseKind kind,
    required PauseStatus status,
    required String workflowName,
    required String nodeLabel,
    required DateTime createdAt,
    String? title,
    String? instructions,
    @Default(true) bool allowFeedback,
    String? question,
    @Default(<String>[]) List<String> options,
    String? decision,
    String? feedback,
    String? answer,
    DateTime? answeredAt,
  }) = _Pause;

  /// Decodes a pause; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$PauseFromJson);
}
