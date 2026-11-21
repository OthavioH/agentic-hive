import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_controller.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/widgets/harness_card.dart';
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
}

class _HarnessesGrid extends StatelessWidget {
  const new({
    required this.state,
    required this.onRecheck,
    required this.onCopyPath,
  });

  final HarnessesState state;
  final ValueChanged<HarnessId> onRecheck;
  final ValueChanged<String> onCopyPath;

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
                    onRecheck: () => onRecheck(harness.id),
                    onCopyPath: onCopyPath,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
