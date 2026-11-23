import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_delete_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/utils/workflow_l10n.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Notice shown above the Workflows list after a delete: success, partial
/// (runs kept) or error (with Retry, or Reload after a revision conflict).
class WorkflowDeleteNoticeBanner extends StatelessWidget {
  /// Creates a [WorkflowDeleteNoticeBanner] for [notice].
  const new({
    required this.notice,
    required this.onDismiss,
    required this.onRetry,
    required this.onReload,
    super.key,
  });

  /// The notice to show.
  final WorkflowDeleteNotice notice;

  /// Dismisses the notice.
  final VoidCallback onDismiss;

  /// Re-sends the failed delete request without confirmation.
  final VoidCallback onRetry;

  /// Reloads the list so the user can confirm the delete again.
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (notice) {
      WorkflowDeletedNotice() => HiveBanner(
        key: const Key('workflows_delete_notice_success'),
        tone: HiveFeedbackTone.success,
        title: l10n.workflowsDeletedNotice,
        liveRegion: true,
        onDismiss: onDismiss,
        dismissSemanticLabel: l10n.workflowsDismissNoticeAction,
      ),
      WorkflowDeletePartialNotice(:final orphanedRunIds) => HiveBanner(
        key: const Key('workflows_delete_notice_partial'),
        tone: HiveFeedbackTone.warning,
        title: l10n.workflowsDeletePartialNotice(orphanedRunIds.length),
        detail: _runIds(orphanedRunIds),
        liveRegion: true,
        onDismiss: onDismiss,
        dismissSemanticLabel: l10n.workflowsDismissNoticeAction,
      ),
      WorkflowDeleteFailedNotice(
        :final workflow,
        :final failure,
        :final orphanedRunIds,
        :final isRevisionConflict,
      ) =>
        HiveBanner(
          key: const Key('workflows_delete_notice_error'),
          tone: HiveFeedbackTone.danger,
          title: l10n.workflowsDeleteFailedTitle(workflow.name),
          message: _message(l10n, failure),
          detail: orphanedRunIds.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.workflowsDeleteKeptRunsDetail(orphanedRunIds.length),
                    ),
                    _runIds(orphanedRunIds),
                  ],
                ),
          liveRegion: true,
          actions: <Widget>[
            if (isRevisionConflict)
              HiveButton(
                key: const Key('workflows_delete_reload_button'),
                label: l10n.workflowsReloadAction,
                variant: HiveButtonVariant.secondary,
                size: HiveButtonSize.small,
                onPressed: onReload,
              )
            else
              HiveButton(
                key: const Key('workflows_delete_retry_button'),
                label: l10n.workflowsRetryAction,
                variant: HiveButtonVariant.secondary,
                size: HiveButtonSize.small,
                onPressed: onRetry,
              ),
          ],
          onDismiss: onDismiss,
          dismissSemanticLabel: l10n.workflowsDismissNoticeAction,
        ),
    };
  }

  Widget _runIds(List<String> ids) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (final id in ids) Text(id, key: Key('workflows_delete_kept_run_$id')),
    ],
  );

  String _message(AppLocalizations l10n, Failure failure) => switch (failure) {
    BackendFailure() ||
    NotFoundFailure() ||
    ValidationFailure() ||
    ConflictFailure() => failure.message,
    NetworkFailure() ||
    UnexpectedFailure() => WorkflowL10n.localizeFailure(l10n, failure),
  };
}
