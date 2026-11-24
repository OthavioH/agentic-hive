import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/skill_row_models.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/widgets/harness_section_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Displays the Agentic Hive skill status row, action button, inline error
/// banner, and MCP-missing warning banner inside a harness card.
class HarnessSkillRow extends StatelessWidget {
  /// Creates a [HarnessSkillRow].
  const new({
    required this.harness,
    required this.isDisabled,
    required this.onInstall,
    required this.onUpdate,
    required this.onRemove,
    required this.onRecheck,
    required this.onRetry,
    this.busyAction,
    this.error,
    super.key,
  });

  /// Harness metadata whose skill state is displayed.
  final HarnessInfo harness;

  /// Whether row actions are disabled by a refresh or another operation.
  final bool isDisabled;

  /// In-flight skill action for this harness, if any.
  final SkillRowAction? busyAction;

  /// Last failed skill action for this harness, if any.
  final SkillRowError? error;

  /// Called when the user taps Install.
  final VoidCallback onInstall;

  /// Called when the user taps Update.
  final VoidCallback onUpdate;

  /// Called when the user taps Remove.
  final VoidCallback onRemove;

  /// Called when the user taps Retry on an `unknown` skill status.
  final VoidCallback onRecheck;

  /// Called when the user taps Retry on the inline error banner.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final skillStatus = harness.skillStatus;
    if (skillStatus == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final wire = harness.id.wireName;

    final spec = _skillStatusSpec(skillStatus, l10n);
    final isBusy = busyAction != null;
    final controlsDisabled = isDisabled || isBusy;
    final actionSpec = _actionSpec(skillStatus, wire, l10n);
    final skillMessage = harness.skillMessage;
    final showConflictExplanation = skillStatus == HarnessSkillStatus.conflict;
    final showUnknownMessage =
        skillStatus == HarnessSkillStatus.unknown &&
        skillMessage != null &&
        skillMessage.isNotEmpty;
    final showMcpMissing =
        (skillStatus == HarnessSkillStatus.installed ||
            skillStatus == HarnessSkillStatus.outdated ||
            skillStatus == HarnessSkillStatus.modified) &&
        harness.mcpStatus == HarnessMcpStatus.notInstalled;

    final currentError = error;

    return HarnessSectionPanel(
      key: ValueKey<String>('harness_skill_row_$wire'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            container: true,
            liveRegion: true,
            explicitChildNodes: true,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: spacing.space1,
              runSpacing: spacing.space1,
              children: <Widget>[
                HiveBadge(label: spec.label, tone: spec.tone, icon: spec.icon),
                if (actionSpec != null)
                  HiveButton(
                    key: ValueKey<String>(actionSpec.key),
                    label: isBusy
                        ? _busyLabel(busyAction!, l10n)
                        : actionSpec.label,
                    variant: actionSpec.variant,
                    size: HiveButtonSize.small,
                    loading: isBusy,
                    // Keep onPressed non-null while busy so HiveInteraction
                    // retains focus on the acting button while ignoring taps.
                    onPressed: isDisabled
                        ? null
                        : (isBusy ? _noop : actionSpec.onPressed),
                  ),
              ],
            ),
          ),
          if (showConflictExplanation) ...<Widget>[
            SizedBox(height: spacing.space1),
            Text(
              l10n.harnessesSkillConflictExplanation,
              softWrap: true,
              style: typography.bodySmall.copyWith(color: colors.onSurface),
            ),
          ] else if (showUnknownMessage) ...<Widget>[
            SizedBox(height: spacing.space1),
            Text(
              skillMessage,
              softWrap: true,
              style: typography.bodySmall.copyWith(
                color: colors.onSurfaceMuted,
              ),
            ),
          ],
          if (currentError != null) ...<Widget>[
            SizedBox(height: spacing.space1),
            HiveBanner(
              key: ValueKey<String>('harness_skill_error_$wire'),
              tone: HiveFeedbackTone.danger,
              liveRegion: true,
              title: l10n.harnessesSkillErrorTitle,
              message: currentError.failure.message.trim().isNotEmpty
                  ? currentError.failure.message
                  : l10n.harnessesSkillErrorFallback,
              actions: <Widget>[
                HiveButton(
                  key: ValueKey<String>('harness_skill_retry_$wire'),
                  label: l10n.harnessesSkillRetry,
                  variant: HiveButtonVariant.secondary,
                  size: HiveButtonSize.small,
                  onPressed: controlsDisabled ? null : onRetry,
                ),
              ],
            ),
          ],
          if (showMcpMissing) ...<Widget>[
            SizedBox(height: spacing.space1),
            HiveBanner(
              key: ValueKey<String>('harness_skill_mcp_missing_$wire'),
              tone: HiveFeedbackTone.warning,
              liveRegion: true,
              title: l10n.harnessesSkillMcpMissing,
            ),
          ],
        ],
      ),
    );
  }

  ({String label, HiveBadgeTone tone, HiveIconData icon}) _skillStatusSpec(
    HarnessSkillStatus status,
    AppLocalizations l10n,
  ) => switch (status) {
    HarnessSkillStatus.installed => (
      label: l10n.harnessesSkillStatusInstalled,
      tone: HiveBadgeTone.success,
      icon: HiveIcons.check,
    ),
    HarnessSkillStatus.notInstalled => (
      label: l10n.harnessesSkillStatusNotInstalled,
      tone: HiveBadgeTone.neutral,
      icon: HiveIcons.close,
    ),
    HarnessSkillStatus.outdated => (
      label: l10n.harnessesSkillStatusOutdated,
      tone: HiveBadgeTone.warning,
      icon: HiveIcons.alert,
    ),
    HarnessSkillStatus.modified => (
      label: l10n.harnessesSkillStatusModified,
      tone: HiveBadgeTone.warning,
      icon: HiveIcons.alert,
    ),
    HarnessSkillStatus.conflict => (
      label: l10n.harnessesSkillStatusConflict,
      tone: HiveBadgeTone.danger,
      icon: HiveIcons.alert,
    ),
    HarnessSkillStatus.unknown => (
      label: l10n.harnessesSkillStatusUnknown,
      tone: HiveBadgeTone.neutral,
      icon: HiveIcons.info,
    ),
  };

  ({
    String key,
    String label,
    HiveButtonVariant variant,
    VoidCallback onPressed,
  })?
  _actionSpec(HarnessSkillStatus status, String wire, AppLocalizations l10n) =>
      switch (status) {
        HarnessSkillStatus.installed => (
          key: 'harness_skill_remove_$wire',
          label: l10n.harnessesSkillRemove,
          variant: HiveButtonVariant.ghost,
          onPressed: onRemove,
        ),
        HarnessSkillStatus.notInstalled => (
          key: 'harness_skill_install_$wire',
          label: l10n.harnessesSkillInstall,
          variant: HiveButtonVariant.secondary,
          onPressed: onInstall,
        ),
        HarnessSkillStatus.outdated || HarnessSkillStatus.modified => (
          key: 'harness_skill_update_$wire',
          label: l10n.harnessesSkillUpdate,
          variant: HiveButtonVariant.secondary,
          onPressed: onUpdate,
        ),
        HarnessSkillStatus.conflict => null,
        HarnessSkillStatus.unknown => (
          key: 'harness_skill_retry_$wire',
          label: l10n.harnessesSkillRetry,
          variant: HiveButtonVariant.secondary,
          onPressed: onRecheck,
        ),
      };

  String _busyLabel(SkillRowAction action, AppLocalizations l10n) =>
      switch (action) {
        SkillRowAction.install => l10n.harnessesSkillInstalling,
        SkillRowAction.update => l10n.harnessesSkillUpdating,
        SkillRowAction.remove => l10n.harnessesSkillRemoving,
      };

  static void _noop() {}
}
