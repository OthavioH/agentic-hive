import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_controller.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/widgets/harness_card.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/widgets/harness_skill_dialogs.dart';
import 'package:agentic_hive_frontend/presentation/skills/controllers/outdated_tools_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Displays detected local CLI harnesses, their readiness statuses, versions,
/// executable paths, and refresh actions.
class HarnessesPage extends ConsumerWidget {
  /// Creates a [HarnessesPage].
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final asyncState = ref.watch(harnessesControllerProvider);
    final isRefreshingAll = asyncState.value?.isRefreshingAll ?? false;

    return Padding(
      padding: EdgeInsets.all(spacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _AcknowledgeOnOpen(),
          HivePageHeader(
            title: l10n.navHarnesses,
            subtitle: l10n.harnessesPageSubtitle,
            actions: <Widget>[
              HiveButton(
                key: const ValueKey<String>('harnesses_refresh_all_button'),
                label: l10n.harnessesRefreshAll,
                icon: HiveIcons.refresh,
                loading: isRefreshingAll,
                onPressed: asyncState.hasValue && !isRefreshingAll
                    ? () => _refreshAll(context, ref, l10n)
                    : null,
              ),
            ],
          ),
          Expanded(
            child: switch (asyncState) {
              AsyncLoading<HarnessesState>() => Center(
                child: HiveConnectionIndicator(
                  state: HiveConnectionState.connecting,
                  label: l10n.harnessesLoading,
                ),
              ),
              AsyncError<HarnessesState>(:final error) => HiveEmptyState(
                icon: HiveIcons.alert,
                title: l10n.harnessesLoadErrorTitle,
                message: _localizedErrorMessage(error, l10n),
                action: HiveButton(
                  key: const ValueKey<String>('harnesses_retry_button'),
                  label: l10n.harnessesRetry,
                  icon: HiveIcons.refresh,
                  onPressed: () => ref.invalidate(harnessesControllerProvider),
                ),
              ),
              AsyncData<HarnessesState>(:final value)
                  when value.harnesses.isEmpty =>
                HiveEmptyState(
                  icon: HiveIcons.harnesses,
                  title: l10n.harnessesEmptyTitle,
                  message: l10n.harnessesEmptyDescription,
                  action: HiveButton(
                    label: l10n.harnessesRefreshAll,
                    icon: HiveIcons.refresh,
                    loading: value.isRefreshingAll,
                    onPressed: value.isRefreshingAll
                        ? null
                        : () => _refreshAll(context, ref, l10n),
                  ),
                ),
              AsyncData<HarnessesState>(:final value) => _HarnessesGrid(
                state: value,
                onRecheck: (id) => _refreshHarness(context, ref, l10n, id),
                onCopyPath: (path) => _copyPath(context, l10n, path),
                onInstallMcp: (harness) =>
                    _installMcp(context, ref, l10n, harness),
                onInstallSkill: (harness) =>
                    _installSkill(context, ref, l10n, harness),
                onUpdateSkill: (harness) =>
                    _updateSkill(context, ref, l10n, harness),
                onRemoveSkill: (harness) =>
                    _removeSkill(context, ref, l10n, harness),
                onRetrySkill: (harness, error) =>
                    _retrySkill(context, ref, l10n, harness, error),
              ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAll(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final result = await ref
        .read(harnessesControllerProvider.notifier)
        .refreshAll();
    if (!context.mounted) return;
    if (result case FailureResult<void>(:final failure)) {
      HiveToast.show(
        context,
        message: l10n.harnessesRefreshError(
          _localizedErrorMessage(failure, l10n),
        ),
        tone: HiveToastTone.danger,
      );
    }
  }

  Future<void> _refreshHarness(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    HarnessId id,
  ) async {
    final result = await ref
        .read(harnessesControllerProvider.notifier)
        .refreshHarness(id);
    if (!context.mounted) return;
    if (result case FailureResult<void>(:final failure)) {
      HiveToast.show(
        context,
        message: l10n.harnessesRefreshError(
          _localizedErrorMessage(failure, l10n),
        ),
        tone: HiveToastTone.danger,
      );
    }
  }

  Future<void> _installMcp(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    HarnessInfo harness,
  ) async {
    final result = await ref
        .read(harnessesControllerProvider.notifier)
        .installMcp(harness.id);
    if (!context.mounted) return;
    switch (result) {
      case Success<void>():
        HiveToast.show(
          context,
          message: l10n.harnessesMcpInstallSuccess(harness.displayName),
          tone: HiveToastTone.success,
        );
      case FailureResult<void>(:final failure):
        HiveToast.show(
          context,
          message: l10n.harnessesMcpInstallError(
            _mcpInstallErrorMessage(failure, l10n),
          ),
          tone: HiveToastTone.danger,
        );
    }
  }

  String _mcpInstallErrorMessage(Failure failure, AppLocalizations l10n) =>
      switch (failure) {
        NetworkFailure() => l10n.harnessesErrorNetwork,
        BackendFailure(:final statusCode) when statusCode == 409 =>
          l10n.harnessesMcpInstallCliNotInstalled,
        BackendFailure(:final message) when message.isNotEmpty => message,
        BackendFailure() => l10n.harnessesErrorBackend,
        NotFoundFailure() => l10n.harnessesErrorNotFound,
        ConflictFailure(:final message) when message.isNotEmpty => message,
        ConflictFailure() ||
        ValidationFailure() ||
        UnexpectedFailure() => l10n.harnessesErrorUnexpected,
      };

  String _localizedErrorMessage(Object error, AppLocalizations l10n) =>
      switch (error) {
        NetworkFailure() => l10n.harnessesErrorNetwork,
        BackendFailure() => l10n.harnessesErrorBackend,
        NotFoundFailure() => l10n.harnessesErrorNotFound,
        ValidationFailure() ||
        UnexpectedFailure() ||
        _ => l10n.harnessesErrorUnexpected,
      };

  Future<void> _copyPath(
    BuildContext context,
    AppLocalizations l10n,
    String path,
  ) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    HiveToast.show(
      context,
      message: l10n.harnessesPathCopiedToast,
      tone: HiveToastTone.success,
    );
  }

  Future<void> _installSkill(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    HarnessInfo harness,
  ) async {
    final result = await ref
        .read(harnessesControllerProvider.notifier)
        .installSkill(harness.id, action: SkillRowAction.install);
    if (!context.mounted) return;
    if (result is Success<void>) {
      HiveToast.show(
        context,
        message: l10n.harnessesSkillInstallSuccess(harness.displayName),
        tone: HiveToastTone.success,
      );
    }
  }

  Future<void> _updateSkill(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    HarnessInfo harness,
  ) async {
    final isModified = harness.skillStatus == HarnessSkillStatus.modified;
    if (isModified) {
      final confirmed = await confirmOverwriteModifiedSkill(
        context,
        harnessName: harness.displayName,
      );
      if (!confirmed || !context.mounted) return;
    }
    final result = await ref
        .read(harnessesControllerProvider.notifier)
        .installSkill(
          harness.id,
          action: SkillRowAction.update,
          overwriteModified: isModified,
        );
    if (!context.mounted) return;
    if (result is Success<void>) {
      HiveToast.show(
        context,
        message: l10n.harnessesSkillInstallSuccess(harness.displayName),
        tone: HiveToastTone.success,
      );
    }
  }

  Future<void> _removeSkill(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    HarnessInfo harness,
  ) async {
    final confirmed = await confirmRemoveSkill(
      context,
      harnessName: harness.displayName,
    );
    if (!confirmed || !context.mounted) return;
    final result = await ref
        .read(harnessesControllerProvider.notifier)
        .removeSkill(harness.id);
    if (!context.mounted) return;
    if (result is Success<void>) {
      HiveToast.show(
        context,
        message: l10n.harnessesSkillRemoveSuccess(harness.displayName),
        tone: HiveToastTone.success,
      );
    }
  }

  Future<void> _retrySkill(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    HarnessInfo harness,
    SkillRowError error,
  ) async {
    final notifier = ref.read(harnessesControllerProvider.notifier);
    final result = switch (error.action) {
      SkillRowAction.remove => await notifier.removeSkill(harness.id),
      SkillRowAction.install ||
      SkillRowAction.update => await notifier.installSkill(
        harness.id,
        action: error.action,
        overwriteModified: error.overwriteModified,
      ),
    };
    if (!context.mounted) return;
    if (result is Success<void>) {
      HiveToast.show(
        context,
        message: error.action == SkillRowAction.remove
            ? l10n.harnessesSkillRemoveSuccess(harness.displayName)
            : l10n.harnessesSkillInstallSuccess(harness.displayName),
        tone: HiveToastTone.success,
      );
    }
  }
}

class _AcknowledgeOnOpen extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_AcknowledgeOnOpen> createState() => _AcknowledgeOnOpenState();
}

class _AcknowledgeOnOpenState extends ConsumerState<_AcknowledgeOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(outdatedBannerAcknowledgementProvider.notifier).acknowledge(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _HarnessesGrid extends StatelessWidget {
  const new({
    required this.state,
    required this.onRecheck,
    required this.onCopyPath,
    required this.onInstallMcp,
    required this.onInstallSkill,
    required this.onUpdateSkill,
    required this.onRemoveSkill,
    required this.onRetrySkill,
  });

  final HarnessesState state;
  final ValueChanged<HarnessId> onRecheck;
  final ValueChanged<String> onCopyPath;
  final ValueChanged<HarnessInfo> onInstallMcp;
  final ValueChanged<HarnessInfo> onInstallSkill;
  final ValueChanged<HarnessInfo> onUpdateSkill;
  final ValueChanged<HarnessInfo> onRemoveSkill;
  final void Function(HarnessInfo harness, SkillRowError error) onRetrySkill;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    final twoColumnBreakpoint = spacing.space8 * 11;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= twoColumnBreakpoint;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - spacing.space2) / 2
            : constraints.maxWidth;

        return SingleChildScrollView(
          child: Wrap(
            spacing: spacing.space2,
            runSpacing: spacing.space2,
            children: <Widget>[
              for (final harness in state.harnesses)
                SizedBox(
                  width: cardWidth,
                  child: HarnessCard(
                    harness: harness,
                    isRefreshing: state.refreshingIds.contains(harness.id),
                    isGlobalRefreshing: state.isRefreshingAll,
                    isInstallingMcp: state.installingMcpIds.contains(
                      harness.id,
                    ),
                    skillAction: state.skillActions[harness.id],
                    skillError: state.skillErrors[harness.id],
                    onRecheck: () => onRecheck(harness.id),
                    onCopyPath: onCopyPath,
                    onInstallMcp: () => onInstallMcp(harness),
                    onInstallSkill: () => onInstallSkill(harness),
                    onUpdateSkill: () => onUpdateSkill(harness),
                    onRemoveSkill: () => onRemoveSkill(harness),
                    onRetrySkill: state.skillErrors[harness.id] == null
                        ? null
                        : () => onRetrySkill(
                            harness,
                            state.skillErrors[harness.id]!,
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
