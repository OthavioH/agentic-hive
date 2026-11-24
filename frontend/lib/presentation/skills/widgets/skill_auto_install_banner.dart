import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/skills/controllers/skill_notice_state.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Global banner reporting what the automatic skill and MCP installation did
/// on first harness detection.
class SkillAutoInstallBanner extends StatelessWidget {
  /// Creates a [SkillAutoInstallBanner].
  const new({
    required this.state,
    required this.onUndo,
    required this.onRetry,
    required this.onDismiss,
    super.key,
  });

  /// Current notice state.
  final SkillNoticeState state;

  /// Called when the user taps Undo on the installed variant.
  final VoidCallback onUndo;

  /// Called when the user taps Retry on the partial-failure variant.
  final VoidCallback onRetry;

  /// Called when the user dismisses the banner.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final notice = state.notice;
    if (notice == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;

    if (state.isPartial) {
      final failures = state.failures;
      return HiveBanner(
        tone: HiveFeedbackTone.warning,
        liveRegion: true,
        title: l10n.skillNoticePartialTitle,
        detail: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final failure in failures) ...<Widget>[
              Text(
                switch (failure.step) {
                  SkillNoticeStep.skill => l10n.skillNoticeFailureSkill(
                    failure.harnessId.displayName,
                    _detailMessage(failure.message, l10n),
                  ),
                  SkillNoticeStep.mcp => l10n.skillNoticeFailureMcp(
                    failure.harnessId.displayName,
                    _detailMessage(failure.message, l10n),
                  ),
                },
                style: typography.bodySmall.copyWith(
                  color: colors.onSurfaceMuted,
                ),
              ),
              if (failure != failures.last) SizedBox(height: spacing.spaceHalf),
            ],
          ],
        ),
        actions: <Widget>[
          HiveButton(
            key: const ValueKey<String>('skill_notice_retry'),
            label: l10n.skillNoticeRetry,
            variant: HiveButtonVariant.secondary,
            size: HiveButtonSize.small,
            loading: state.isWorking,
            onPressed: state.isWorking ? null : onRetry,
          ),
        ],
        onDismiss: onDismiss,
        dismissSemanticLabel: l10n.skillNoticeDismiss,
      );
    }

    final installedNames = <String>[
      for (final result in notice.results)
        if (result.skill.outcome == SkillAutoInstallOutcome.installed ||
            result.mcp.outcome == SkillAutoInstallOutcome.installed)
          result.harnessId.displayName,
    ].join(l10n.skillNoticeNamesSeparator);

    final pathLines = <String>[
      for (final result in notice.results)
        for (final path in result.skill.paths)
          l10n.skillNoticePathLine(result.harnessId.displayName, path),
    ];

    return HiveBanner(
      tone: HiveFeedbackTone.success,
      liveRegion: true,
      title: l10n.skillNoticeInstalledTitle(installedNames),
      detail: pathLines.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < pathLines.length; i++) ...<Widget>[
                  Text(
                    pathLines[i],
                    style: typography.mono.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                  if (i < pathLines.length - 1)
                    SizedBox(height: spacing.spaceHalf),
                ],
              ],
            ),
      actions: <Widget>[
        HiveButton(
          key: const ValueKey<String>('skill_notice_undo'),
          label: l10n.skillNoticeUndo,
          variant: HiveButtonVariant.secondary,
          size: HiveButtonSize.small,
          loading: state.isWorking,
          onPressed: state.isWorking ? null : onUndo,
        ),
      ],
      onDismiss: onDismiss,
      dismissSemanticLabel: l10n.skillNoticeDismiss,
    );
  }

  String _detailMessage(String? message, AppLocalizations l10n) =>
      message != null && message.trim().isNotEmpty
      ? message
      : l10n.skillNoticeFailureFallback;
}
