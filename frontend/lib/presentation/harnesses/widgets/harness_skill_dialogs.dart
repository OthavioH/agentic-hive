import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Asks for confirmation before overwriting locally edited skill files for
/// [harnessName].
Future<bool> confirmOverwriteModifiedSkill(
  BuildContext context, {
  required String harnessName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showHiveConfirmDialog(
    context,
    title: l10n.harnessesSkillOverwriteTitle,
    message: l10n.harnessesSkillOverwriteMessage(harnessName),
    confirmLabel: l10n.harnessesSkillOverwriteConfirm,
    cancelLabel: l10n.harnessesSkillCancel,
    tone: HiveConfirmTone.destructive,
    icon: HiveIcons.alert,
  );
  return choice == HiveConfirmChoice.confirm;
}

/// Asks for confirmation before removing the Agentic Hive skill from
/// [harnessName].
Future<bool> confirmRemoveSkill(
  BuildContext context, {
  required String harnessName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showHiveConfirmDialog(
    context,
    title: l10n.harnessesSkillRemoveTitle(harnessName),
    message: l10n.harnessesSkillRemoveMessage(harnessName),
    confirmLabel: l10n.harnessesSkillRemoveConfirm,
    cancelLabel: l10n.harnessesSkillCancel,
    tone: HiveConfirmTone.destructive,
    icon: HiveIcons.alert,
  );
  return choice == HiveConfirmChoice.confirm;
}
