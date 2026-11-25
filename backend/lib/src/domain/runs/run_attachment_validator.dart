import 'dart:convert';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// File extension stored for each allowed Run attachment MIME type.
const runAttachmentExtensions = <String, String>{
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/gif': 'gif',
  'image/webp': 'webp',
};

/// One validated Run attachment: decoded bytes plus the detected type.
final class DecodedRunAttachment {
  /// Creates a decoded Run attachment.
  const new({
    required this.fileName,
    required this.mimeType,
    required this.extension,
    required this.bytes,
  });

  /// Display file name from the request (never used for storage paths).
  final String fileName;

  /// Validated MIME type.
  final String mimeType;

  /// File extension matching the detected image signature.
  final String extension;

  /// Decoded image bytes.
  final Uint8List bytes;

  /// Converts this decoded attachment into persisted metadata (no bytes).
  RunAttachment toMetadata() => RunAttachment(
    fileName: fileName,
    mimeType: mimeType,
    sizeBytes: bytes.length,
  );
}

/// Validates and decodes start-run attachments (ADR 0030).
///
/// Returns `Success([])` when [payloads] is null or empty.
Result<List<DecodedRunAttachment>> decodeRunAttachments(
  List<RunAttachmentPayload>? payloads,
) {
  if (payloads == null || payloads.isEmpty) {
    return const Success([]);
  }
  if (payloads.length > RunAttachmentLimits.maxCount) {
    return const FailureResult(
      ValidationFailure(
        'At most ${RunAttachmentLimits.maxCount} attachments are allowed.',
      ),
    );
  }

  final decoded = <DecodedRunAttachment>[];
  var totalBytes = 0;

  for (var i = 0; i < payloads.length; i++) {
    final index = i + 1;
    final payload = payloads[i];

    if (!RunAttachmentLimits.allowedMimeTypes.contains(payload.mimeType)) {
      return FailureResult(
        ValidationFailure('Attachment $index has an unsupported type.'),
      );
    }

    final Uint8List bytes;
    try {
      bytes = base64.decode(payload.data);
    } on FormatException {
      return FailureResult(
        ValidationFailure('Attachment $index is not valid base64.'),
      );
    }
    if (bytes.isEmpty) {
      return FailureResult(
        ValidationFailure('Attachment $index is not valid base64.'),
      );
    }

    if (bytes.length > RunAttachmentLimits.maxBytesEach) {
      return FailureResult(
        ValidationFailure('Attachment $index exceeds 10 MiB.'),
      );
    }

    final detected = _sniffImageType(bytes);
    if (detected == null || detected.mimeType != payload.mimeType) {
      return FailureResult(
        ValidationFailure(
          'Attachment $index does not match its declared type.',
        ),
      );
    }

    totalBytes += bytes.length;
    if (totalBytes > RunAttachmentLimits.maxTotalBytes) {
      return const FailureResult(
        ValidationFailure('Attachments exceed 25 MiB in total.'),
      );
    }

    decoded.add(
      DecodedRunAttachment(
        fileName: payload.fileName,
        mimeType: payload.mimeType,
        extension: detected.extension,
        bytes: bytes,
      ),
    );
  }

  return Success(decoded);
}

({String mimeType, String extension})? _sniffImageType(Uint8List bytes) {
  if (_matchesPrefix(bytes, const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return (mimeType: 'image/png', extension: 'png');
  }
  if (_matchesPrefix(bytes, const [0xFF, 0xD8, 0xFF])) {
    return (mimeType: 'image/jpeg', extension: 'jpg');
  }
  if (_matchesPrefix(bytes, const [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
      _matchesPrefix(bytes, const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61])) {
    return (mimeType: 'image/gif', extension: 'gif');
  }
  if (bytes.length >= 12 &&
      _matchesAt(bytes, 0, const [0x52, 0x49, 0x46, 0x46]) &&
      _matchesAt(bytes, 8, const [0x57, 0x45, 0x42, 0x50])) {
    return (mimeType: 'image/webp', extension: 'webp');
  }
  return null;
}

bool _matchesPrefix(Uint8List bytes, List<int> prefix) =>
    _matchesAt(bytes, 0, prefix);

bool _matchesAt(Uint8List bytes, int offset, List<int> expected) {
  if (bytes.length < offset + expected.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (bytes[offset + i] != expected[i]) return false;
  }
  return true;
}
