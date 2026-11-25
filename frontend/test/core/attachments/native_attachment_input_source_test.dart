import 'dart:convert';

import 'package:agentic_hive_frontend/core/attachments/native_attachment_input_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeClipboardImageBase64', () {
    test('decodes a data URL with base64 prefix', () {
      final bytes = <int>[0x89, 0x50, 0x4E, 0x47];
      final encoded = 'data:image/png;base64,${base64Encode(bytes)}';

      expect(decodeClipboardImageBase64(encoded), bytes);
    });

    test('decodes raw base64 without data URL prefix', () {
      final bytes = <int>[0xFF, 0xD8, 0xFF, 0xE0];
      final encoded = base64Encode(bytes);

      expect(decodeClipboardImageBase64(encoded), bytes);
    });

    test('returns null on null, empty, or invalid base64', () {
      expect(decodeClipboardImageBase64(null), isNull);
      expect(decodeClipboardImageBase64(''), isNull);
      expect(decodeClipboardImageBase64('not-valid-base64!!!'), isNull);
    });
  });
}
