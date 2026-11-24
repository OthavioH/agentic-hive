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

  static const String _sentinel = '\u0000';

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
    final prefixStyle = typography.label.copyWith(color: colors.onSurfaceMuted);
    final valueStyle = typography.mono.copyWith(color: colors.onSurface);

    if (state.isPartial) {
      final failures = state.failures;
      return HiveSlideIn(
        child: HiveBanner(
          tone: HiveFeedbackTone.warning,
          liveRegion: true,
          title: l10n.skillNoticePartialTitle,
          detail: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final failure in failures) ...<Widget>[
                _richDetailLine(
                  template: switch (failure.step) {
                    SkillNoticeStep.skill => l10n.skillNoticeFailureSkill(
                      failure.harnessId.displayName,
                      _sentinel,
                    ),
                    SkillNoticeStep.mcp => l10n.skillNoticeFailureMcp(
                      failure.harnessId.displayName,
                      _sentinel,
                    ),
                  },
                  value: _detailMessage(failure.message, l10n),
                  prefixStyle: prefixStyle,
                  valueStyle: valueStyle,
                ),
                if (failure != failures.last)
                  SizedBox(height: spacing.spaceHalf),
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
        ),
      );
    }

    final installedNames = <String>[
      for (final result in notice.results)
        if (result.skill.outcome == SkillAutoInstallOutcome.installed ||
            result.mcp.outcome == SkillAutoInstallOutcome.installed)
          result.harnessId.displayName,
    ].join(l10n.skillNoticeNamesSeparator);

    final pathEntries = <({String template, String path})>[
      for (final result in notice.results)
        for (final path in result.skill.paths)
          (
            template: l10n.skillNoticePathLine(
              result.harnessId.displayName,
              _sentinel,
            ),
            path: path,
          ),
    ];

    return HiveSlideIn(
      child: HiveBanner(
        tone: HiveFeedbackTone.success,
        liveRegion: true,
        title: l10n.skillNoticeInstalledTitle(installedNames),
        detail: pathEntries.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var i = 0; i < pathEntries.length; i++) ...<Widget>[
                    _richDetailLine(
                      template: pathEntries[i].template,
                      value: pathEntries[i].path,
                      prefixStyle: prefixStyle,
                      valueStyle: valueStyle,
                    ),
                    if (i < pathEntries.length - 1)
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
      ),
    );
  }

  Widget _richDetailLine({
    required String template,
    required String value,
    required TextStyle prefixStyle,
    required TextStyle valueStyle,
  }) {
    final parts = template.split(_sentinel);
    final fullLine = parts.join(value);
    return Semantics(
      label: fullLine,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            if (parts.first.isNotEmpty)
              TextSpan(text: parts.first, style: prefixStyle),
            TextSpan(text: value, style: valueStyle),
            if (parts.length > 1 && parts[1].isNotEmpty)
              TextSpan(text: parts[1], style: prefixStyle),
          ],
        ),
        softWrap: true,
      ),
    );
  }

  String _detailMessage(String? message, AppLocalizations l10n) =>
      message != null && message.trim().isNotEmpty
      ? message
      : l10n.skillNoticeFailureFallback;
}
