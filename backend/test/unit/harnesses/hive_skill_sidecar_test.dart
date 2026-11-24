import 'dart:convert';

import 'package:agentic_hive_backend/src/data/harnesses/hive_skill_sidecar.dart';
import 'package:test/test.dart';

void main() {
  const validHash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  group('HiveSkillSidecar', () {
    test(
      'encode produces pretty JSON with exact key order and trailing LF',
      () {
        const sidecar = HiveSkillSidecar(
          appVersion: '1.2.3',
          contentHash: validHash,
        );

        final encoded = sidecar.encode();

        expect(encoded.endsWith('\n'), isTrue);
        expect(encoded, '''
{
  "schemaVersion": 1,
  "appVersion": "1.2.3",
  "contentHash": "$validHash"
}
''');
      },
    );

    test('tryParse(encode()) round-trips', () {
      const sidecar = HiveSkillSidecar(
        appVersion: '2.0.0-dev.1',
        contentHash: validHash,
      );

      final parsed = HiveSkillSidecar.tryParse(sidecar.encode());

      expect(parsed, isNotNull);
      expect(parsed!.appVersion, '2.0.0-dev.1');
      expect(parsed.contentHash, validHash);
    });

    test('tryParse returns null for invalid inputs', () {
      final invalidInputs = <String>[
        '',
        '   ',
        '[]',
        'not json',
        '{}',
        '{"schemaVersion": 1, "appVersion": "1.0.0"}',
        '{"schemaVersion": 1, "contentHash": "$validHash"}',
        '{"appVersion": "1.0.0", "contentHash": "$validHash"}',
        jsonEncode({
          'schemaVersion': '1',
          'appVersion': '1.0.0',
          'contentHash': validHash,
        }),
        '{"schemaVersion": 1, "appVersion": 123, "contentHash": "$validHash"}',
        '{"schemaVersion": 1, "appVersion": "1.0.0", "contentHash": 123}',
        jsonEncode({
          'schemaVersion': 2,
          'appVersion': '1.0.0',
          'contentHash': validHash,
        }),
        jsonEncode({
          'schemaVersion': 1,
          'appVersion': '1.0.0',
          'contentHash': validHash.toUpperCase(),
        }),
        jsonEncode({
          'schemaVersion': 1,
          'appVersion': '1.0.0',
          'contentHash': validHash.substring(0, 63),
        }),
        jsonEncode({
          'schemaVersion': 1,
          'appVersion': '1.0.0',
          'contentHash': '${validHash}a',
        }),
      ];

      for (final input in invalidInputs) {
        expect(
          HiveSkillSidecar.tryParse(input),
          isNull,
          reason: 'Expected null for: $input',
        );
      }
    });
  });
}
