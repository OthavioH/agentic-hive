import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  group('AppSettings', () {
    test('round-trips through JSON with all fields', () {
      const settings = AppSettings(
        agentsDir: '/custom/agents',
        effectiveAgentsDir: '/custom/agents',
        defaultAgentsDir: '/data/agents',
        defaultWorkspaceDir: '/projects/workspace',
        harnessOverrides: {
          HarnessId.claudeCode: '/opt/bin/claude',
          HarnessId.codex: r'C:\tools\codex.exe',
        },
      );

      final decoded = AppSettings.fromJson(_overTheWire(settings.toJson()));
      expect(decoded, settings);
    });

    test('defaults optional fields when omitted', () {
      final decoded = AppSettings.fromJson({
        'effectiveAgentsDir': '/data/agents',
        'defaultAgentsDir': '/data/agents',
      });

      expect(decoded.agentsDir, isNull);
      expect(decoded.defaultWorkspaceDir, isNull);
      expect(decoded.harnessOverrides, isEmpty);
    });

    test('throws FormatException on invalid shape', () {
      expect(
        () => AppSettings.fromJson({'effectiveAgentsDir': '/data/agents'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('UpdateSettingsRequest', () {
    test('round-trips through JSON with all fields', () {
      const request = UpdateSettingsRequest(
        agentsDir: '/custom/agents',
        defaultWorkspaceDir: '/projects/workspace',
        harnessOverrides: {
          HarnessId.geminiCli: '/usr/local/bin/gemini',
          HarnessId.antigravity: '',
        },
      );

      final decoded = UpdateSettingsRequest.fromJson(
        _overTheWire(request.toJson()),
      );
      expect(decoded, request);
    });

    test('defaults harnessOverrides to empty map when omitted', () {
      final decoded = UpdateSettingsRequest.fromJson({});

      expect(decoded.agentsDir, isNull);
      expect(decoded.defaultWorkspaceDir, isNull);
      expect(decoded.harnessOverrides, isEmpty);
    });
  });

  group('SettingsUpdatedPayload & WsMessageType', () {
    test('uses wire name settings.updated', () {
      expect(WsMessageType.settingsUpdated, 'settings.updated');
    });

    test('round-trips SettingsUpdatedPayload through JSON', () {
      const payload = SettingsUpdatedPayload(
        settings: AppSettings(
          effectiveAgentsDir: '/data/agents',
          defaultAgentsDir: '/data/agents',
          harnessOverrides: {HarnessId.codex: '/usr/local/bin/codex'},
        ),
      );

      final decoded = SettingsUpdatedPayload.fromJson(
        _overTheWire(payload.toJson()),
      );
      expect(decoded, payload);
    });
  });
}
