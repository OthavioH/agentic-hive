import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_attachment.freezed.dart';
part 'run_attachment.g.dart';

/// A Run attachment as sent in a start-run request: an image inline as
/// base64. [fileName] is display only; the backend stores the file under a
/// generated name (ADR 0030).
@freezed
sealed class RunAttachmentPayload with _$RunAttachmentPayload {
  /// Creates a Run attachment payload.
  const factory({
    required String fileName,
    required String mimeType,
    required String data, // base64
  }) = _RunAttachmentPayload;

  /// Decodes a Run attachment payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$RunAttachmentPayloadFromJson);
}

/// Metadata the run keeps for each Run attachment. It holds no bytes; whether
/// the file still exists comes from the run status.
@freezed
sealed class RunAttachment with _$RunAttachment {
  /// Creates Run attachment metadata.
  const factory({
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) = _RunAttachment;

  /// Decodes Run attachment metadata; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) => parseJson(json, _$RunAttachmentFromJson);
}

/// Limits on Run attachments, enforced by both app and backend (ADR 0030).
abstract final class RunAttachmentLimits {
  /// Allowed image MIME types for Run attachments.
  static const allowedMimeTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
  };

  /// Maximum number of attachments per run.
  static const maxCount = 10;

  /// Maximum decoded size in bytes for a single attachment (10 MiB).
  static const int maxBytesEach = 10 * 1024 * 1024;

  /// Maximum decoded size in bytes across all attachments in a run (25 MiB).
  static const int maxTotalBytes = 25 * 1024 * 1024;
}
