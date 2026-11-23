import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('ExecutionSettings', () {
    test('every field is optional so an absent key means "inherit"', () {
      final settings = ExecutionSettings.fromJson(const {});

      expect(settings.defaultIsolationMode, isNull);
      expect(settings.ignorePatterns, isNull);
      expect(settings.defaultShell, isNull);
      expect(settings.isEmpty, isTrue);
    });

    test('round-trips through JSON', () {
      const settings = ExecutionSettings(
        defaultIsolationMode: WorkspaceIsolationMode.direct,
        ignorePatterns: ['build/', '*.log'],
        defaultShell: '/bin/zsh',
      );

      final json = settings.toJson();

      expect(json['defaultIsolationMode'], 'direct');
      expect(ExecutionSettings.fromJson(json), settings);
      expect(settings.isEmpty, isFalse);
    });

    test('throws FormatException on an unknown isolation mode', () {
      expect(
        () => ExecutionSettings.fromJson(const {
          'defaultIsolationMode': 'sideways',
        }),
        throwsFormatException,
      );
    });

    test('exposes the only keys a workspace may override', () {
      expect(ExecutionSettings.overridableKeys, {
        'defaultIsolationMode',
        'ignorePatterns',
        'defaultShell',
      });
    });
  });

  group('EffectiveExecutionSettings', () {
    test('round-trips through JSON', () {
      const effective = EffectiveExecutionSettings(
        defaultIsolationMode: WorkspaceIsolationMode.worktree,
        ignorePatterns: ['node_modules/'],
        defaultShell: 'cmd.exe',
      );

      expect(
        EffectiveExecutionSettings.fromJson(effective.toJson()),
        effective,
      );
    });
  });

  group('WorkspaceSettingsResponse', () {
    test('round-trips through JSON', () {
      const response = WorkspaceSettingsResponse(
        overrides: ExecutionSettings(defaultShell: 'pwsh'),
        global: EffectiveExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.worktree,
          ignorePatterns: [],
          defaultShell: 'cmd.exe',
        ),
        effective: EffectiveExecutionSettings(
          defaultIsolationMode: WorkspaceIsolationMode.worktree,
          ignorePatterns: [],
          defaultShell: 'pwsh',
        ),
      );

      expect(WorkspaceSettingsResponse.fromJson(response.toJson()), response);
    });
  });
}
