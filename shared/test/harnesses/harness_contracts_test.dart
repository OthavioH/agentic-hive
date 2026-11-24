import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

Matcher _formatErrorNaming(String field) => isA<FormatException>().having(
  (e) => e.message,
  'message',
  contains('"$field"'),
);

void main() {
  final checkedAt = DateTime.utc(2026, 11, 20, 18, 30);

  group('HarnessId', () {
    test('tryParse resolves canonical wire names and rejects unknown ids', () {
      expect(HarnessId.tryParse('claude_code'), HarnessId.claudeCode);
      expect(HarnessId.tryParse('codex'), HarnessId.codex);
      expect(HarnessId.tryParse('gemini_cli'), HarnessId.geminiCli);
      expect(HarnessId.tryParse('antigravity'), HarnessId.antigravity);
      expect(HarnessId.tryParse('unknown'), isNull);
      expect(HarnessId.tryParse(''), isNull);
    });
  });

  group('HarnessInfo', () {
    test('round-trips a ready harness through JSON', () {
      final info = HarnessInfo(
        id: HarnessId.claudeCode,
        displayName: 'Claude Code',
        status: HarnessStatus.ready,
        version: '2.1.0',
        executablePath: r'C:\tools\claude.exe',
        checkedAt: checkedAt,
      );

      final decoded = HarnessInfo.fromJson(_overTheWire(info.toJson()));

      expect(decoded, info);
      expect(info.toJson()['id'], 'claude_code');
      expect(info.toJson()['status'], 'ready');
      expect(info.toJson().containsKey('errorMessage'), isFalse);
    });

    test('round-trips all five HarnessStatus values', () {
      for (final status in HarnessStatus.values) {
        final info = HarnessInfo(
          id: HarnessId.codex,
          displayName: 'Codex',
          status: status,
          errorMessage: status == HarnessStatus.ready ? null : 'details',
          checkedAt: checkedAt,
        );

        final decoded = HarnessInfo.fromJson(_overTheWire(info.toJson()));
        expect(decoded.status, status);
      }
    });

    test('omits null optional fields from JSON', () {
      final info = HarnessInfo(
        id: HarnessId.geminiCli,
        displayName: 'Gemini CLI',
        status: HarnessStatus.notInstalled,
        checkedAt: checkedAt,
      );

      expect(info.toJson(), {
        'id': 'gemini_cli',
        'displayName': 'Gemini CLI',
        'status': 'notInstalled',
        'checkedAt': checkedAt.toIso8601String(),
        'mcpStatus': 'unknown',
      });
    });

    test('round-trips all five HarnessMcpStatus values and mcpMessage', () {
      const expectedWire = {
        HarnessMcpStatus.installed: 'installed',
        HarnessMcpStatus.notInstalled: 'not_installed',
        HarnessMcpStatus.outdated: 'outdated',
        HarnessMcpStatus.unsupported: 'unsupported',
        HarnessMcpStatus.unknown: 'unknown',
      };

      for (final mcpStatus in HarnessMcpStatus.values) {
        final info = HarnessInfo(
          id: HarnessId.claudeCode,
          displayName: 'Claude Code',
          status: HarnessStatus.ready,
          checkedAt: checkedAt,
          mcpStatus: mcpStatus,
          mcpMessage: mcpStatus == HarnessMcpStatus.installed ? null : 'note',
        );

        final json = _overTheWire(info.toJson());
        expect(json['mcpStatus'], expectedWire[mcpStatus]);
        expect(HarnessInfo.fromJson(json), info);
      }
    });

    test('defaults mcpStatus to unknown when omitted in JSON', () {
      final decoded = HarnessInfo.fromJson({
        'id': 'claude_code',
        'displayName': 'Claude Code',
        'status': 'ready',
        'checkedAt': checkedAt.toIso8601String(),
      });

      expect(decoded.mcpStatus, HarnessMcpStatus.unknown);
      expect(decoded.mcpMessage, isNull);
    });

    test('throws a FormatException naming "status" for an unknown status', () {
      expect(
        () => HarnessInfo.fromJson({
          'id': 'claude_code',
          'displayName': 'Claude Code',
          'status': 'broken',
          'checkedAt': checkedAt.toIso8601String(),
        }),
        throwsA(_formatErrorNaming('status')),
      );
    });

    test('throws a FormatException naming "id" when id is missing', () {
      expect(
        () => HarnessInfo.fromJson({
          'displayName': 'Claude Code',
          'status': 'ready',
          'checkedAt': checkedAt.toIso8601String(),
        }),
        throwsA(_formatErrorNaming('id')),
      );
    });

    test('round-trips all six HarnessSkillStatus values and skillMessage', () {
      const expectedWire = {
        HarnessSkillStatus.installed: 'installed',
        HarnessSkillStatus.notInstalled: 'not_installed',
        HarnessSkillStatus.outdated: 'outdated',
        HarnessSkillStatus.modified: 'modified',
        HarnessSkillStatus.conflict: 'conflict',
        HarnessSkillStatus.unknown: 'unknown',
      };

      for (final skillStatus in HarnessSkillStatus.values) {
        final info = HarnessInfo(
          id: HarnessId.claudeCode,
          displayName: 'Claude Code',
          status: HarnessStatus.ready,
          checkedAt: checkedAt,
          skillStatus: skillStatus,
          skillMessage: skillStatus == HarnessSkillStatus.installed
              ? null
              : 'skill note',
        );

        final json = _overTheWire(info.toJson());
        expect(json['skillStatus'], expectedWire[skillStatus]);
        expect(HarnessInfo.fromJson(json), info);
      }
    });

    test('defaults skillStatus to null when omitted in JSON', () {
      final decoded = HarnessInfo.fromJson({
        'id': 'claude_code',
        'displayName': 'Claude Code',
        'status': 'ready',
        'checkedAt': checkedAt.toIso8601String(),
      });

      expect(decoded.skillStatus, isNull);
      expect(decoded.skillMessage, isNull);
    });

    test('throws a FormatException for an unknown skillStatus', () {
      expect(
        () => HarnessInfo.fromJson({
          'id': 'claude_code',
          'displayName': 'Claude Code',
          'status': 'ready',
          'checkedAt': checkedAt.toIso8601String(),
          'skillStatus': 'bogus',
        }),
        throwsA(_formatErrorNaming('skillStatus')),
      );
    });

    test('copyWith clears skillStatus and skillMessage when set to null', () {
      final info = HarnessInfo(
        id: HarnessId.claudeCode,
        displayName: 'Claude Code',
        status: HarnessStatus.ready,
        checkedAt: checkedAt,
        skillStatus: HarnessSkillStatus.installed,
        skillMessage: 'msg',
      );
      final cleared = info.copyWith(skillStatus: null, skillMessage: null);
      expect(cleared.skillStatus, isNull);
      expect(cleared.skillMessage, isNull);
    });
  });

  group('HarnessListResponse', () {
    test('round-trips a list of harnesses through JSON', () {
      final response = HarnessListResponse(
        harnesses: [
          HarnessInfo(
            id: HarnessId.claudeCode,
            displayName: 'Claude Code',
            status: HarnessStatus.ready,
            version: '1.0.0',
            executablePath: '/usr/local/bin/claude',
            checkedAt: checkedAt,
          ),
          HarnessInfo(
            id: HarnessId.antigravity,
            displayName: 'Antigravity',
            status: HarnessStatus.authError,
            executablePath: '/usr/local/bin/agy',
            errorMessage: 'Sign in required.',
            checkedAt: checkedAt,
          ),
        ],
      );

      final decoded = HarnessListResponse.fromJson(
        _overTheWire(response.toJson()),
      );

      expect(decoded, response);
    });
  });

  group('HarnessStatusUpdatedPayload', () {
    test('round-trips through JSON and pairs with WsEnvelope', () {
      final payload = HarnessStatusUpdatedPayload(
        harness: HarnessInfo(
          id: HarnessId.codex,
          displayName: 'Codex',
          status: HarnessStatus.outdated,
          version: '0.1.0',
          executablePath: '/usr/bin/codex',
          errorMessage: 'Update required.',
          checkedAt: checkedAt,
        ),
      );

      final envelope = WsEnvelope(
        type: WsMessageType.harnessStatusUpdated,
        id: 'evt-1',
        payload: payload.toJson(),
      );
      final roundTripped = WsEnvelope.decode(envelope.encode());
      final decodedPayload = HarnessStatusUpdatedPayload.fromJson(
        roundTripped.payload,
      );

      expect(roundTripped.type, WsMessageType.harnessStatusUpdated);
      expect(decodedPayload, payload);
    });

    test('throws a FormatException naming "harness" when missing', () {
      expect(
        () => HarnessStatusUpdatedPayload.fromJson({}),
        throwsA(_formatErrorNaming('harness')),
      );
    });
  });
}
