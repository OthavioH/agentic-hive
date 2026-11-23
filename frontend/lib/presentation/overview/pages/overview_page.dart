import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/overview/controllers/overview_controller.dart';
import 'package:agentic_hive_frontend/presentation/overview/utils/overview_l10n.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_active_nodes_section.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_active_runs_section.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_metrics_section.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_pending_pauses_section.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_recent_runs_section.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Live operational dashboard (`/overview`).
class OverviewPage extends ConsumerWidget {
  /// Creates an [OverviewPage].
  const new({super.key});

  static const double _twoColumnBreakpoint = 960;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final snapshot = ref.watch(
      overviewControllerProvider.select((s) => s.snapshot),
    );
    final controller = ref.read(overviewControllerProvider.notifier);

    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HivePageHeader(
            title: l10n.navOverview,
            subtitle: l10n.overviewPageSubtitle,
            actions: <Widget>[
              Consumer(
                builder: (context, ref, _) {
                  final isRefreshing = ref.watch(
                    overviewControllerProvider.select((s) => s.isRefreshing),
                  );
                  return HiveButton(
                    key: const Key('overview_refresh_button'),
                    label: l10n.overviewRefreshAction,
                    icon: HiveIcons.refresh,
                    variant: HiveButtonVariant.secondary,
                    loading: isRefreshing,
                    onPressed: () => unawaited(controller.refresh()),
                  );
                },
              ),
            ],
          ),
          Consumer(
            builder: (context, ref, _) {
              final refreshFailure = ref.watch(
                overviewControllerProvider.select((s) => s.refreshFailure),
              );
              if (refreshFailure == null) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(bottom: spacing.space3),
                child: HiveBanner(
                  tone: HiveFeedbackTone.danger,
                  title: l10n.overviewLoadErrorTitle,
                  message: OverviewL10n.localizeFailure(l10n, refreshFailure),
                  actions: <Widget>[
                    HiveButton(
                      label: l10n.overviewRetryAction,
                      variant: HiveButtonVariant.secondary,
                      size: HiveButtonSize.small,
                      onPressed: () => unawaited(controller.refresh()),
                    ),
                  ],
                  onDismiss: controller.dismissRefreshFailure,
                  dismissSemanticLabel: l10n.overviewDismissAction,
                  liveRegion: true,
                ),
              );
            },
          ),
          snapshot.when(
            loading: () => Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.space8),
              child: Center(
                child: HiveSpinner(
                  size: spacing.space4,
                  color: context.hiveColors.accent,
                ),
              ),
            ),
            error: (error, _) => HiveEmptyState(
              icon: HiveIcons.alert,
              title: l10n.overviewLoadErrorTitle,
              message: OverviewL10n.localizeError(l10n, error),
              action: HiveButton(
                key: const Key('overview_error_retry_button'),
                label: l10n.overviewRetryAction,
                onPressed: () => unawaited(controller.refresh()),
              ),
            ),
            data: (data) => _OverviewBody(
              snapshot: data,
              controller: controller,
              twoColumnBreakpoint: _twoColumnBreakpoint,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  const new({
    required this.snapshot,
    required this.controller,
    required this.twoColumnBreakpoint,
  });

  final OverviewSnapshot snapshot;
  final OverviewController controller;
  final double twoColumnBreakpoint;

  bool get _isEmptyOperationalState =>
      snapshot.activeRuns.isEmpty &&
      snapshot.activeNodes.isEmpty &&
      snapshot.pendingPauses.isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final announcePendingPauses = ref.watch(
      overviewControllerProvider.select((s) => s.hasPendingPausesChanged),
    );

    if (_isEmptyOperationalState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.space4,
        children: <Widget>[
          OverviewMetricsSection(
            metrics: snapshot.metrics,
            announcePendingPauses: announcePendingPauses,
          ),
          HiveEmptyState(
            icon: HiveIcons.overview,
            title: l10n.overviewEmptyTitle,
            message: l10n.overviewEmptyDescription,
            action: HiveButton(
              key: const Key('overview_empty_cta_button'),
              label: l10n.overviewEmptyCta,
              onPressed: () => const WorkflowsRoute().go(context),
            ),
          ),
          if (snapshot.recentRuns.isNotEmpty)
            OverviewRecentRunsSection(
              runs: snapshot.recentRuns,
              onViewAll: () => const RunsRoute().go(context),
              onOpenRun: (runId) => RunDetailRoute(id: runId).go(context),
            ),
        ],
      );
    }

    final activeRunsSection = OverviewActiveRunsSection(
      runs: snapshot.activeRuns,
      onViewAll: () => const RunsRoute().go(context),
      onOpenRun: (runId) => RunDetailRoute(id: runId).go(context),
    );
    final activeNodesSection = OverviewActiveNodesSection(
      nodes: snapshot.activeNodes,
      onOpenRun: (runId) => RunDetailRoute(id: runId).go(context),
    );
    final recentRunsSection = snapshot.recentRuns.isNotEmpty
        ? OverviewRecentRunsSection(
            runs: snapshot.recentRuns,
            onViewAll: () => const RunsRoute().go(context),
            onOpenRun: (runId) => RunDetailRoute(id: runId).go(context),
          )
        : null;
    final pendingPausesSection = Consumer(
      builder: (context, ref, _) {
        final submittingPauses = ref.watch(
          overviewControllerProvider.select((s) => s.submittingPauses),
        );
        final pauseErrors = ref.watch(
          overviewControllerProvider.select((s) => s.pauseErrors),
        );
        final now = ref.read(overviewClockConfigProvider).now();
        return OverviewPendingPausesSection(
          pauses: snapshot.pendingPauses,
          now: now,
          submittingPauses: submittingPauses,
          pauseErrors: pauseErrors,
          onViewAll: () => const PausesRoute().go(context),
          onApprove: (pauseId) => unawaited(controller.approvePause(pauseId)),
          onReject: (pauseId) => unawaited(controller.rejectPause(pauseId)),
          onOpenPauses: () => const PausesRoute().go(context),
          onDismissError: controller.dismissPauseError,
        );
      },
    );
    final metricsSection = OverviewMetricsSection(
      metrics: snapshot.metrics,
      announcePendingPauses: announcePendingPauses,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= twoColumnBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.space4,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing.space4,
                  children: <Widget>[
                    activeRunsSection,
                    activeNodesSection,
                    ?recentRunsSection,
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing.space4,
                  children: <Widget>[pendingPausesSection, metricsSection],
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.space4,
          children: <Widget>[
            pendingPausesSection,
            metricsSection,
            activeRunsSection,
            activeNodesSection,
            ?recentRunsSection,
          ],
        );
      },
    );
  }
}
