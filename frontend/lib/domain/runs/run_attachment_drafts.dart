import 'dart:convert';
import 'dart:typed_data';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// A candidate file or pasted image before validation.
final class RunAttachmentCandidate {
  /// Creates a [RunAttachmentCandidate].
  const new({
    required this.fileName,
    required this.sizeBytes,
    required this.bytes,
  });

  /// Display name of the file or pasted image.
  final String fileName;

  /// File size in bytes.
  final int sizeBytes;

  /// Raw image bytes, or `null` when the source skipped reading an oversized
  /// or unreadable file.
  final Uint8List? bytes;
}

/// A validated image attachment staged for a new run.
final class RunAttachmentDraft {
  /// Creates a [RunAttachmentDraft].
  const new({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  /// Display name of the attachment.
  final String fileName;

  /// Sniffed MIME type (one of [RunAttachmentLimits.allowedMimeTypes]).
  final String mimeType;

  /// Raw image bytes.
  final Uint8List bytes;

  /// Size of [bytes] in bytes.
  int get sizeBytes => bytes.length;

  /// Converts this draft to a [RunAttachmentPayload] with base64-encoded data.
  RunAttachmentPayload toPayload() => RunAttachmentPayload(
    fileName: fileName,
    mimeType: mimeType,
    data: base64Encode(bytes),
  );
}

/// Reason a [RunAttachmentCandidate] was rejected.
enum RunAttachmentRejection {
  /// The file's magic bytes did not match an allowed image format.
  type,

  /// The file exceeded per-file, count, or total size limits (or could not be
  /// read).
  limits,
}

/// Sniffs the image MIME type from [bytes] magic bytes, or returns `null` if
/// unrecognized.
String? sniffImageMimeType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 && // G
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x38 && // 8
      (bytes[4] == 0x37 || bytes[4] == 0x39) && // 7 or 9
      bytes[5] == 0x61) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 && // R
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x46 && // F
      bytes[8] == 0x57 && // W
      bytes[9] == 0x45 && // E
      bytes[10] == 0x42 && // B
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

/// Maps a supported image [mime] type to its canonical file extension.
String extensionForMime(String mime) {
  return switch (mime) {
    'image/png' => 'png',
    'image/jpeg' => 'jpg',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    _ => 'png',
  };
}

/// Validates [candidates] in order against [current] drafts and
/// [RunAttachmentLimits], returning accepted drafts and per-file rejections.
({
  List<RunAttachmentDraft> accepted,
  List<(String fileName, RunAttachmentRejection reason)> rejected,
})
addRunAttachments(
  List<RunAttachmentDraft> current,
  List<RunAttachmentCandidate> candidates,
) {
  final accepted = <RunAttachmentDraft>[];
  final rejected = <(String, RunAttachmentRejection)>[];

  var totalCount = current.length;
  var totalBytes = current.fold<int>(0, (sum, d) => sum + d.sizeBytes);

  for (final candidate in candidates) {
    final bytes = candidate.bytes;
    if (bytes == null ||
        candidate.sizeBytes > RunAttachmentLimits.maxBytesEach ||
        bytes.length > RunAttachmentLimits.maxBytesEach) {
      rejected.add((candidate.fileName, RunAttachmentRejection.limits));
      continue;
    }

    final mime = sniffImageMimeType(bytes);
    if (mime == null || !RunAttachmentLimits.allowedMimeTypes.contains(mime)) {
      rejected.add((candidate.fileName, RunAttachmentRejection.type));
      continue;
    }

    if (totalCount + 1 > RunAttachmentLimits.maxCount ||
        totalBytes + bytes.length > RunAttachmentLimits.maxTotalBytes) {
      rejected.add((candidate.fileName, RunAttachmentRejection.limits));
      continue;
    }

    accepted.add(
      RunAttachmentDraft(
        fileName: candidate.fileName,
        mimeType: mime,
        bytes: bytes,
      ),
    );
    totalCount += 1;
    totalBytes += bytes.length;
  }

  return (accepted: accepted, rejected: rejected);
}
