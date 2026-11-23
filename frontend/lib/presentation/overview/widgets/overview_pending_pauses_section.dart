import 'package:agentic_hive_frontend/core/result/failure.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/overview/controllers/overview_state.dart';
import 'package:agentic_hive_frontend/presentation/overview/utils/overview_l10n.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_section_header.dart';
import 'package:agentic_hive_frontend/presentation/pauses/utils/pause_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Pending Pauses attention queue on the Overview dashboard (FIFO order).
class OverviewPendingPausesSection extends StatelessWidget {
  /// Creates an [OverviewPendingPausesSection].
  const new({
    required this.pauses,
    required this.now,
    required this.submittingPauses,
    required this.pauseErrors,
    required this.onViewAll,
    required this.onApprove,
    required this.onReject,
    required this.onOpenPauses,
    required this.onDismissError,
    super.key,
  });

  /// Pending pauses sorted oldest-first (FIFO).
  final List<PendingPauseSummary> pauses;

  /// Current timestamp for waiting-time labels.
  final DateTime now;

  /// In-flight inline decision actions keyed by `pauseId`.
  final Map<String, OverviewPauseAction> submittingPauses;

  /// Inline errors keyed by `pauseId`.
  final Map<String, Failure> pauseErrors;

  /// Called when "View all" is pressed.
  final VoidCallback onViewAll;

  /// Called when inline Approve is pressed for a `pauseId`.
  final ValueChanged<String> onApprove;

  /// Called when inline Reject is pressed for a `pauseId`.
  final ValueChanged<String> onReject;

  /// Called when navigation-only "Respond in Pauses" is pressed.
  final VoidCallback onOpenPauses;

  /// Called when an inline error banner is dismissed for a `pauseId`.
  final ValueChanged<String> onDismissError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OverviewSectionHeader(
          title: l10n.overviewSectionPendingPauses,
          count: pauses.length,
          actionLabel: l10n.overviewViewAllAction,
          actionKey: const Key('overview_pending_pauses_view_all'),
          onAction: onViewAll,
        ),
        if (pauses.isEmpty)
          HiveCard(
            child: Text(
              l10n.overviewPendingPausesEmpty,
              style: typography.body.copyWith(color: colors.onSurfaceMuted),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.space2,
            children: <Widget>[
              for (final pause in pauses)
                _PendingPauseCard(
                  pause: pause,
                  now: now,
                  submittingAction: submittingPauses[pause.pauseId],
                  error: pauseErrors[pause.pauseId],
                  onApprove: () => onApprove(pause.pauseId),
                  onReject: () => onReject(pause.pauseId),
                  onOpenPauses: onOpenPauses,
                  onDismissError: () => onDismissError(pause.pauseId),
                ),
            ],
          ),
      ],
    );
  }
}

class _PendingPauseCard extends StatelessWidget {
  const new({
    required this.pause,
    required this.now,
    required this.submittingAction,
    required this.error,
    required this.onApprove,
    required this.onReject,
    required this.onOpenPauses,
    required this.onDismissError,
  });

  final PendingPauseSummary pause;
  final DateTime now;
  final OverviewPauseAction? submittingAction;
  final Failure? error;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onOpenPauses;
  final VoidCallback onDismissError;

  bool get _supportsInlineDecision =>
      pause.pauseKind == PauseKind.humanApproval && !pause.requiresFeedback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final isBusy = submittingAction != null;
    final cardError = error;

    return HiveCard(
      key: ValueKey<String>('overview_pause_${pause.pauseId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.space1,
        children: <Widget>[
          Row(
            spacing: spacing.space1,
            children: <Widget>[
              Expanded(
                child: Text(
                  pause.nodeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.labelLarge.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              HiveBadge(
                label: pause.pauseKind.label(l10n),
                tone: pause.pauseKind.badgeTone,
              ),
            ],
          ),
          Text(
            '${pause.workflowName} · '
            '${PauseL10n.formatWaitingTime(l10n, pause.createdAt, now: now)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.bodySmall.copyWith(color: colors.onSurfaceMuted),
          ),
          if (pause.prompt.isNotEmpty)
            Text(
              pause.prompt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: typography.body.copyWith(color: colors.onSurface),
            ),
          if (cardError != null)
            HiveBanner(
              tone: HiveFeedbackTone.danger,
              title: l10n.overviewPauseActionErrorTitle,
              message: OverviewL10n.localizeFailure(l10n, cardError),
              onDismiss: onDismissError,
              dismissSemanticLabel: l10n.overviewDismissAction,
              liveRegion: true,
            ),
          Padding(
            padding: EdgeInsets.only(top: spacing.space1),
            child: _supportsInlineDecision
                ? Wrap(
                    spacing: spacing.space1,
                    runSpacing: spacing.space1,
                    children: <Widget>[
                      HiveButton(
                        key: ValueKey<String>(
                          'overview_pause_approve_${pause.pauseId}',
                        ),
                        label: l10n.overviewApproveAction,
                        size: HiveButtonSize.small,
                        loading:
                            submittingAction == OverviewPauseAction.approve,
                        onPressed: isBusy ? null : onApprove,
                      ),
                      HiveButton(
                        key: ValueKey<String>(
                          'overview_pause_reject_${pause.pauseId}',
                        ),
                        label: l10n.overviewRejectAction,
                        variant: HiveButtonVariant.secondary,
                        size: HiveButtonSize.small,
                        loading: submittingAction == OverviewPauseAction.reject,
                        onPressed: isBusy ? null : onReject,
                      ),
                    ],
                  )
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: HiveButton(
                      key: ValueKey<String>(
                        'overview_pause_open_${pause.pauseId}',
                      ),
                      label: l10n.overviewOpenPauseAction,
                      variant: HiveButtonVariant.secondary,
                      size: HiveButtonSize.small,
                      onPressed: onOpenPauses,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
