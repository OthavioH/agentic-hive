import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/runs/run_output_stream.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcript_entry.freezed.dart';
part 'transcript_entry.g.dart';

/// Neutral transcript entry derived from a node attempt's raw log.
///
/// Ids are unique within one attempt and depend only on the raw log; a later
/// entry with the same `id` replaces the earlier one.
///
/// [firstOffset] and [lastOffset] form the inclusive 1-based raw log offset
/// range that produced this entry.
@Freezed(unionKey: 'kind')
sealed class TranscriptEntry with _$TranscriptEntry {
  /// Assistant text message emitted by a harness.
  const factory agentMessage({
    required String id,
    required int firstOffset,
    required int lastOffset,
    required String text,
  }) = TranscriptAgentMessage;

  /// Assistant reasoning/thinking block emitted by a harness.
  const factory thinking({
    required String id,
    required int firstOffset,
    required int lastOffset,
    required String text,
  }) = TranscriptThinking;

  /// Tool invocation emitted by a harness.
  const factory toolCall({
    required String id,
    required int firstOffset,
    required int lastOffset,
    required String name,
    @Default(<String, Object?>{}) JsonMap input,
    String? callId,
  }) = TranscriptToolCall;

  /// Tool execution result emitted by a harness.
  ///
  /// [callId] is the CLI's own id, matching [TranscriptToolCall.callId].
  const factory toolResult({
    required String id,
    required int firstOffset,
    required int lastOffset,
    required String output,
    String? callId,
    @Default(false) bool isError,
  }) = TranscriptToolResult;

  /// Error reported in the transcript stream.
  const factory error({
    required String id,
    required int firstOffset,
    required int lastOffset,
    required String message,
  }) = TranscriptError;

  /// Terminal summary result reported by a harness.
  const factory finalResult({
    required String id,
    required int firstOffset,
    required int lastOffset,
    String? status,
    int? durationMs,
    double? costUsd,
    int? inputTokens,
    int? outputTokens,
  }) = TranscriptFinalResult;

  /// Plain-text fallback line from `stdout` or `stderr`.
  const factory plainText({
    required String id,
    required int firstOffset,
    required int lastOffset,
    required RunOutputStream stream,
    required String text,
  }) = TranscriptPlainText;

  /// Decodes a transcript entry; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$TranscriptEntryFromJson);
}
