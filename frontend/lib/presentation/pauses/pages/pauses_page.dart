import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_controller.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pauses_state.dart';
import 'package:agentic_hive_frontend/presentation/pauses/utils/pause_l10n.dart';
import 'package:agentic_hive_frontend/presentation/pauses/widgets/pause_detail_pane.dart';
import 'package:agentic_hive_frontend/presentation/pauses/widgets/pause_list_pane.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Master-detail Pauses inbox screen (`/pauses`).
class PausesPage extends ConsumerWidget {
  /// Creates a [PausesPage].
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final state = ref.watch(pausesControllerProvider);
    final controller = ref.read(pausesControllerProvider.notifier);

    final announcement = switch (state.lastAnnouncement) {
      PauseArrivedAnnouncement(:final nodeLabel) => l10n.pausesAnnounceCreated(
        nodeLabel,
      ),
      PauseResolvedAnnouncement(:final nodeLabel) =>
        l10n.pausesAnnounceResolved(nodeLabel),
      null => null,
    };

    return Padding(
      padding: EdgeInsets.all(spacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (announcement != null)
            Semantics(
              liveRegion: true,
              label: announcement,
              child: const SizedBox.shrink(),
            ),
          HivePageHeader(title: l10n.navPauses),
          Expanded(
            child: state.pauses.when(
              loading: () => const _PausesLoadingSkeleton(),
              error: (error, _) => HiveEmptyState(
                icon: HiveIcons.alert,
                title: l10n.pausesLoadErrorTitle,
                message: PauseL10n.localizeError(l10n, error),
                action: HiveButton(
                  key: const Key('pauses_retry_button'),
                  label: l10n.pausesRetryAction,
                  onPressed: () => unawaited(controller.loadPauses()),
                ),
              ),
              data: (pauses) {
                if (pauses.isEmpty) {
                  return HiveEmptyState(
                    icon: HiveIcons.pauses,
                    title: l10n.pausesEmptyTitle,
                    message: l10n.pausesEmptyDescription,
                  );
                }

                final selected = state.selectedPause;
                return HiveMasterDetail(
                  detailVisible: selected != null,
                  master: PauseListPane(
                    pauses: pauses,
                    selectedPauseId: state.selectedPauseId,
                    onSelectPause: controller.selectPause,
                  ),
                  detail: selected == null
                      ? HiveEmptyState(
                          icon: HiveIcons.pauses,
                          title: l10n.pausesSelectPrompt,
                        )
                      : PauseDetailPane(
                          pause: selected,
                          state: state,
                          onOpenRun: (runId) =>
                              RunDetailRoute(id: runId).go(context),
                          onApprove: (feedback) => unawaited(
                            controller.submitApproval(
                              pauseId: selected.id,
                              approved: true,
                              feedback: feedback,
                            ),
                          ),
                          onReject: (feedback) => unawaited(
                            controller.submitApproval(
                              pauseId: selected.id,
                              approved: false,
                              feedback: feedback,
                            ),
                          ),
                          onSubmitAnswer: (answer) => unawaited(
                            controller.submitAnswer(
                              pauseId: selected.id,
                              answer: answer,
                            ),
                          ),
                          onDismissNotice: controller.dismissNotice,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PausesLoadingSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final radii = context.hiveRadii;

    return ListView.separated(
      itemCount: 3,
      separatorBuilder: (_, _) => SizedBox(height: spacing.space2),
      itemBuilder: (context, _) => HiveCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: spacing.space8 * 2,
              height: spacing.space2,
              decoration: BoxDecoration(
                color: colors.surface3,
                borderRadius: radii.pill,
              ),
            ),
            SizedBox(height: spacing.space2),
            Container(
              width: spacing.space8 * 4,
              height: spacing.space2,
              decoration: BoxDecoration(
                color: colors.surface3,
                borderRadius: radii.pill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
