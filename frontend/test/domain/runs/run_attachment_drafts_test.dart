import 'dart:convert';
import 'dart:typed_data';

import 'package:agentic_hive_frontend/domain/runs/run_attachment_drafts.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _pngBytes([int extra = 4]) => Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  ...List<int>.filled(extra, 0),
]);

Uint8List _jpegBytes([int extra = 4]) => Uint8List.fromList(<int>[
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  ...List<int>.filled(extra, 0),
]);

Uint8List _gif87aBytes() =>
    Uint8List.fromList(<int>[...utf8.encode('GIF87a'), 0x01, 0x00]);

Uint8List _gif89aBytes() =>
    Uint8List.fromList(<int>[...utf8.encode('GIF89a'), 0x01, 0x00]);

Uint8List _webpBytes() => Uint8List.fromList(<int>[
  ...utf8.encode('RIFF'),
  0x24,
  0x00,
  0x00,
  0x00,
  ...utf8.encode('WEBP'),
  0x00,
]);

void main() {
  group('sniffImageMimeType', () {
    test('detects PNG, JPEG, GIF87a, GIF89a, and WebP signatures', () {
      expect(sniffImageMimeType(_pngBytes()), 'image/png');
      expect(sniffImageMimeType(_jpegBytes()), 'image/jpeg');
      expect(sniffImageMimeType(_gif87aBytes()), 'image/gif');
      expect(sniffImageMimeType(_gif89aBytes()), 'image/gif');
      expect(sniffImageMimeType(_webpBytes()), 'image/webp');
    });

    test('returns null for non-image or truncated bytes', () {
      expect(
        sniffImageMimeType(Uint8List.fromList(utf8.encode('%PDF-1.7'))),
        isNull,
      );
      expect(sniffImageMimeType(Uint8List.fromList(<int>[0x89, 0x50])), isNull);
      expect(sniffImageMimeType(Uint8List(0)), isNull);
    });
  });

  group('extensionForMime', () {
    test('maps supported image MIME types to file extensions', () {
      expect(extensionForMime('image/png'), 'png');
      expect(extensionForMime('image/jpeg'), 'jpg');
      expect(extensionForMime('image/webp'), 'webp');
      expect(extensionForMime('image/gif'), 'gif');
    });
  });

  group('addRunAttachments', () {
    test('rejects a non-image renamed as .png with type reason', () {
      final result = addRunAttachments(
        const <RunAttachmentDraft>[],
        <RunAttachmentCandidate>[
          RunAttachmentCandidate(
            fileName: 'fake.png',
            sizeBytes: 8,
            bytes: Uint8List.fromList(utf8.encode('%PDF-1.7')),
          ),
        ],
      );

      expect(result.accepted, isEmpty);
      expect(result.rejected, <(String, RunAttachmentRejection)>[
        ('fake.png', RunAttachmentRejection.type),
      ]);
    });

    test('rejects the 11th image with limits reason', () {
      final current = <RunAttachmentDraft>[
        for (var i = 0; i < RunAttachmentLimits.maxCount; i++)
          RunAttachmentDraft(
            fileName: 'img_$i.png',
            mimeType: 'image/png',
            bytes: _pngBytes(),
          ),
      ];

      final result = addRunAttachments(current, <RunAttachmentCandidate>[
        RunAttachmentCandidate(
          fileName: 'img_10.png',
          sizeBytes: _pngBytes().length,
          bytes: _pngBytes(),
        ),
      ]);

      expect(result.accepted, isEmpty);
      expect(result.rejected, <(String, RunAttachmentRejection)>[
        ('img_10.png', RunAttachmentRejection.limits),
      ]);
    });

    test('rejects an oversize single image (null bytes or > maxBytesEach)', () {
      final oversizeBytes = Uint8List(RunAttachmentLimits.maxBytesEach + 1)
        ..setAll(0, _pngBytes(0));

      final result = addRunAttachments(
        const <RunAttachmentDraft>[],
        <RunAttachmentCandidate>[
          const RunAttachmentCandidate(
            fileName: 'too-big-unread.png',
            sizeBytes: RunAttachmentLimits.maxBytesEach + 1,
            bytes: null,
          ),
          RunAttachmentCandidate(
            fileName: 'too-big-read.png',
            sizeBytes: oversizeBytes.length,
            bytes: oversizeBytes,
          ),
        ],
      );

      expect(result.accepted, isEmpty);
      expect(result.rejected, <(String, RunAttachmentRejection)>[
        ('too-big-unread.png', RunAttachmentRejection.limits),
        ('too-big-read.png', RunAttachmentRejection.limits),
      ]);
    });

    test('rejects candidates that would exceed maxTotalBytes (25 MiB)', () {
      final nineMb = Uint8List(9 * 1024 * 1024)..setAll(0, _pngBytes(0));
      final current = <RunAttachmentDraft>[
        RunAttachmentDraft(
          fileName: 'a.png',
          mimeType: 'image/png',
          bytes: nineMb,
        ),
        RunAttachmentDraft(
          fileName: 'b.png',
          mimeType: 'image/png',
          bytes: nineMb,
        ),
      ];

      final result = addRunAttachments(current, <RunAttachmentCandidate>[
        RunAttachmentCandidate(
          fileName: 'c.png',
          sizeBytes: nineMb.length,
          bytes: nineMb,
        ),
        RunAttachmentCandidate(
          fileName: 'd.png',
          sizeBytes: _pngBytes().length,
          bytes: _pngBytes(),
        ),
      ]);

      expect(result.accepted.map((a) => a.fileName), <String>['d.png']);
      expect(result.rejected, <(String, RunAttachmentRejection)>[
        ('c.png', RunAttachmentRejection.limits),
      ]);
    });

    test('partially accepts valid items from a mixed list', () {
      final result = addRunAttachments(
        const <RunAttachmentDraft>[],
        <RunAttachmentCandidate>[
          RunAttachmentCandidate(
            fileName: 'valid.jpg',
            sizeBytes: _jpegBytes().length,
            bytes: _jpegBytes(),
          ),
          RunAttachmentCandidate(
            fileName: 'notes.pdf',
            sizeBytes: 8,
            bytes: Uint8List.fromList(utf8.encode('%PDF-1.7')),
          ),
          const RunAttachmentCandidate(
            fileName: 'huge.webp',
            sizeBytes: RunAttachmentLimits.maxBytesEach + 100,
            bytes: null,
          ),
          RunAttachmentCandidate(
            fileName: 'ok.webp',
            sizeBytes: _webpBytes().length,
            bytes: _webpBytes(),
          ),
        ],
      );

      expect(result.accepted.length, 2);
      expect(result.accepted[0].fileName, 'valid.jpg');
      expect(result.accepted[0].mimeType, 'image/jpeg');
      expect(result.accepted[1].fileName, 'ok.webp');
      expect(result.accepted[1].mimeType, 'image/webp');
      expect(result.rejected, <(String, RunAttachmentRejection)>[
        ('notes.pdf', RunAttachmentRejection.type),
        ('huge.webp', RunAttachmentRejection.limits),
      ]);
    });
  });

  group('RunAttachmentDraft.toPayload', () {
    test('encodes bytes as base64 in RunAttachmentPayload', () {
      final bytes = _pngBytes();
      final draft = RunAttachmentDraft(
        fileName: 'shot.png',
        mimeType: 'image/png',
        bytes: bytes,
      );

      final payload = draft.toPayload();
      expect(payload.fileName, 'shot.png');
      expect(payload.mimeType, 'image/png');
      expect(payload.data, base64Encode(bytes));
    });
  });
}
