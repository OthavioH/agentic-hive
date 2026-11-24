import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const requiredKeys = <String, List<String>>{
    'harnessesSkillStatusInstalled': <String>[],
    'harnessesSkillStatusNotInstalled': <String>[],
    'harnessesSkillStatusOutdated': <String>[],
    'harnessesSkillStatusModified': <String>[],
    'harnessesSkillStatusConflict': <String>[],
    'harnessesSkillStatusUnknown': <String>[],
    'harnessesSkillConflictExplanation': <String>[],
    'harnessesSkillInstall': <String>[],
    'harnessesSkillUpdate': <String>[],
    'harnessesSkillRemove': <String>[],
    'harnessesSkillRetry': <String>[],
    'harnessesSkillInstalling': <String>[],
    'harnessesSkillUpdating': <String>[],
    'harnessesSkillRemoving': <String>[],
    'harnessesSkillMcpMissing': <String>[],
    'harnessesSkillErrorTitle': <String>[],
    'harnessesSkillErrorFallback': <String>[],
    'harnessesSkillInstallSuccess': <String>['name'],
    'harnessesSkillRemoveSuccess': <String>['name'],
    'harnessesSkillOverwriteTitle': <String>[],
    'harnessesSkillOverwriteMessage': <String>['name'],
    'harnessesSkillOverwriteConfirm': <String>[],
    'harnessesSkillRemoveTitle': <String>['name'],
    'harnessesSkillRemoveMessage': <String>['name'],
    'harnessesSkillRemoveConfirm': <String>[],
    'harnessesSkillCancel': <String>[],
    'skillNoticeInstalledTitle': <String>['harnesses'],
    'skillNoticePathLine': <String>['harness', 'path'],
    'skillNoticeUndo': <String>[],
    'skillNoticePartialTitle': <String>[],
    'skillNoticeFailureSkill': <String>['harness', 'message'],
    'skillNoticeFailureMcp': <String>['harness', 'message'],
    'skillNoticeFailureFallback': <String>[],
    'skillNoticeRetry': <String>[],
    'skillNoticeDismiss': <String>[],
    'skillNoticeNamesSeparator': <String>[],
    'skillNoticeUndoSuccess': <String>['harnesses'],
    'skillNoticeUndoError': <String>['message'],
    'outdatedBannerTitle': <String>['harnesses'],
    'outdatedBannerOpen': <String>[],
    'outdatedBannerDismiss': <String>[],
    'settingsAutoInstallSkillsLabel': <String>[],
    'settingsAutoInstallSkillsHelp': <String>[],
  };

  test(
    'every app_*.arb contains all skill keys, descriptions, and placeholders',
    () {
      final l10nDir = Directory('lib/l10n').existsSync()
          ? Directory('lib/l10n')
          : Directory('frontend/lib/l10n');
      final arbFiles = l10nDir
          .listSync()
          .whereType<File>()
          .where((f) => RegExp(r'app_.*\.arb$').hasMatch(f.path))
          .toList();
      expect(arbFiles, isNotEmpty);

      for (final file in arbFiles) {
        final map = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        for (final entry in requiredKeys.entries) {
          final key = entry.key;
          final expectedPlaceholders = entry.value;
          final value = map[key];
          expect(value, isA<String>(), reason: '${file.path} missing $key');
          expect(
            (value! as String).trim(),
            isNotEmpty,
            reason: '${file.path} empty $key',
          );

          final meta = map['@$key'] as Map<String, Object?>?;
          expect(meta, isNotNull, reason: '${file.path} missing @$key');
          expect(
            (meta!['description'] as String?)?.trim(),
            isNotEmpty,
            reason: '${file.path} missing description for $key',
          );

          if (expectedPlaceholders.isNotEmpty) {
            final placeholders = meta['placeholders'] as Map<String, Object?>?;
            expect(
              placeholders,
              isNotNull,
              reason: '${file.path} missing placeholders for $key',
            );
            for (final p in expectedPlaceholders) {
              expect(
                value,
                contains('{$p}'),
                reason: '${file.path} $key missing {$p}',
              );
              expect(
                placeholders!.containsKey(p),
                isTrue,
                reason: '${file.path} @$key missing placeholder $p',
              );
            }
          }
        }
      }
    },
  );

  test('exact English #120 matrix copy matches AppLocalizations', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(l10n.harnessesSkillStatusInstalled, 'Skill installed');
    expect(l10n.harnessesSkillStatusNotInstalled, 'Skill not installed');
    expect(l10n.harnessesSkillStatusOutdated, 'Skill outdated');
    expect(l10n.harnessesSkillStatusModified, 'Skill modified');
    expect(l10n.harnessesSkillStatusConflict, 'Skill conflict');
    expect(l10n.harnessesSkillStatusUnknown, 'Skill status unknown');
    expect(
      l10n.harnessesSkillConflictExplanation,
      'A skill named agentic-hive already exists here and was not installed '
      'by Agentic Hive.',
    );
    expect(l10n.harnessesSkillInstall, 'Install');
    expect(l10n.harnessesSkillUpdate, 'Update');
    expect(l10n.harnessesSkillRemove, 'Remove');
    expect(l10n.harnessesSkillInstalling, 'Installing…');
    expect(l10n.harnessesSkillUpdating, 'Updating…');
    expect(l10n.harnessesSkillRemoving, 'Removing…');
    expect(
      l10n.harnessesSkillMcpMissing,
      'The skill needs the Hive MCP server.',
    );
    expect(l10n.harnessesSkillOverwriteTitle, 'Replace your edited skill?');
    expect(
      l10n.harnessesSkillRemoveTitle('Claude Code'),
      'Remove the skill from Claude Code?',
    );
    expect(
      l10n.settingsAutoInstallSkillsLabel,
      'Install the skill automatically for new harnesses',
    );
  });
}
