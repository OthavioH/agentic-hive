import 'dart:convert';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_attachment_validator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  final pngHeader = Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
  ]);
  final jpegHeader = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
  final gif87aHeader = Uint8List.fromList(
    utf8.encode('GIF87a\x01\x00\x01\x00'),
  );
  final gif89aHeader = Uint8List.fromList(
    utf8.encode('GIF89a\x01\x00\x01\x00'),
  );
  final webpHeader = Uint8List.fromList([
    ...utf8.encode('RIFF'),
    0x00,
    0x00,
    0x00,
    0x00,
    ...utf8.encode('WEBP'),
    0x56,
    0x50,
    0x38,
    0x20,
  ]);

  RunAttachmentPayload payload(
    String fileName,
    String mimeType,
    Uint8List bytes,
  ) => RunAttachmentPayload(
    fileName: fileName,
    mimeType: mimeType,
    data: base64Encode(bytes),
  );

  group('decodeRunAttachments', () {
    test('returns empty list for null or empty payloads', () {
      expect(decodeRunAttachments(null).valueOrNull, isEmpty);
      expect(decodeRunAttachments(const []).valueOrNull, isEmpty);
    });

    test('validates and decodes PNG, JPEG, GIF87a, GIF89a, and WebP', () {
      final result = decodeRunAttachments([
        payload('a.png', 'image/png', pngHeader),
        payload('b.jpg', 'image/jpeg', jpegHeader),
        payload('c.gif', 'image/gif', gif87aHeader),
        payload('d.gif', 'image/gif', gif89aHeader),
        payload('e.webp', 'image/webp', webpHeader),
      ]);

      expect(result, isA<Success<List<DecodedRunAttachment>>>());
      final decoded = result.valueOrNull!;
      expect(decoded, hasLength(5));
      expect(decoded[0].extension, 'png');
      expect(decoded[0].toMetadata().sizeBytes, pngHeader.length);
      expect(decoded[1].extension, 'jpg');
      expect(decoded[1].toMetadata().sizeBytes, jpegHeader.length);
      expect(decoded[2].extension, 'gif');
      expect(decoded[2].toMetadata().sizeBytes, gif87aHeader.length);
      expect(decoded[3].extension, 'gif');
      expect(decoded[3].toMetadata().sizeBytes, gif89aHeader.length);
      expect(decoded[4].extension, 'webp');
      expect(decoded[4].toMetadata().sizeBytes, webpHeader.length);
    });

    test('rejects PNG bytes declared as image/jpeg', () {
      final data = base64Encode(pngHeader);
      final result = decodeRunAttachments([
        RunAttachmentPayload(
          fileName: 'fake.jpg',
          mimeType: 'image/jpeg',
          data: data,
        ),
      ]);

      expect(result, isA<FailureResult<List<DecodedRunAttachment>>>());
      final failure = (result as FailureResult).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('does not match its declared type'));
      expect(failure.message, isNot(contains(data)));
    });

    test('rejects unsupported mimeType', () {
      final data = base64Encode(utf8.encode('hello'));
      final result = decodeRunAttachments([
        RunAttachmentPayload(
          fileName: 'note.txt',
          mimeType: 'text/plain',
          data: data,
        ),
      ]);

      expect(result, isA<FailureResult<List<DecodedRunAttachment>>>());
      final failure = (result as FailureResult).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('unsupported type'));
      expect(failure.message, isNot(contains(data)));
    });

    test('rejects invalid base64', () {
      const badData = 'not-valid-base64!!!';
      final result = decodeRunAttachments([
        const RunAttachmentPayload(
          fileName: 'bad.png',
          mimeType: 'image/png',
          data: badData,
        ),
      ]);

      expect(result, isA<FailureResult<List<DecodedRunAttachment>>>());
      final failure = (result as FailureResult).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('not valid base64'));
      expect(failure.message, isNot(contains(badData)));
    });

    test('rejects more than maxCount attachments', () {
      final items = List.generate(
        RunAttachmentLimits.maxCount + 1,
        (i) => payload('img$i.png', 'image/png', pngHeader),
      );
      final result = decodeRunAttachments(items);

      expect(result, isA<FailureResult<List<DecodedRunAttachment>>>());
      final failure = (result as FailureResult).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('At most 10 attachments'));
    });

    test('rejects single attachment exceeding maxBytesEach', () {
      final oversized = Uint8List(RunAttachmentLimits.maxBytesEach + 1)
        ..setRange(0, pngHeader.length, pngHeader);
      final data = base64Encode(oversized);

      final result = decodeRunAttachments([
        RunAttachmentPayload(
          fileName: 'big.png',
          mimeType: 'image/png',
          data: data,
        ),
      ]);

      expect(result, isA<FailureResult<List<DecodedRunAttachment>>>());
      final failure = (result as FailureResult).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('exceeds 10 MiB'));
      expect(failure.message, isNot(contains(data)));
    });

    test('rejects total bytes exceeding maxTotalBytes', () {
      const nineMiB = 9 * 1024 * 1024;
      final chunk = Uint8List(nineMiB)
        ..setRange(0, pngHeader.length, pngHeader);
      final data = base64Encode(chunk);

      final result = decodeRunAttachments([
        RunAttachmentPayload(
          fileName: '1.png',
          mimeType: 'image/png',
          data: data,
        ),
        RunAttachmentPayload(
          fileName: '2.png',
          mimeType: 'image/png',
          data: data,
        ),
        RunAttachmentPayload(
          fileName: '3.png',
          mimeType: 'image/png',
          data: data,
        ),
      ]);

      expect(result, isA<FailureResult<List<DecodedRunAttachment>>>());
      final failure = (result as FailureResult).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('25 MiB in total'));
      expect(failure.message, isNot(contains(data)));
    });
  });
}
