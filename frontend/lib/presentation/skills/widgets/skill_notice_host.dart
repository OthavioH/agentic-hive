import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/skills/controllers/outdated_tools_controller.dart';
import 'package:agentic_hive_frontend/presentation/skills/controllers/skill_notice_controller.dart';
import 'package:agentic_hive_frontend/presentation/skills/widgets/outdated_tools_banner.dart';
import 'package:agentic_hive_frontend/presentation/skills/widgets/skill_auto_install_banner.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Hosts the global automatic skill install notice and outdated-tools banner
/// inside the application shell.
class SkillNoticeHost extends ConsumerWidget {
  /// Creates a [SkillNoticeHost].
  const new({required this.location, super.key});

  /// Current router path, used to suppress the outdated banner on Harnesses.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticeState = ref.watch(skillNoticeControllerProvider).asData?.value;
    final showNotice = noticeState != null && noticeState.notice != null;
    final isHarnessesLocation =
        location == HarnessesRoute.path ||
        location.startsWith('${HarnessesRoute.path}/');
    final showOutdated =
        !isHarnessesLocation && ref.watch(showOutdatedBannerProvider);

    if (!showNotice && !showOutdated) {
      return const SizedBox.shrink();
    }

    final spacing = context.hiveSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showNotice) ...<Widget>[
          SkillAutoInstallBanner(
            state: noticeState,
            onUndo: () => unawaited(_undo(context, ref, noticeState)),
            onRetry: () => unawaited(
              ref.read(skillNoticeControllerProvider.notifier).retryFailed(),
            ),
            onDismiss: () => unawaited(
              ref.read(skillNoticeControllerProvider.notifier).dismiss(),
            ),
          ),
          SizedBox(height: spacing.space2),
        ],
        if (showOutdated) ...<Widget>[
          const OutdatedToolsBanner(),
          SizedBox(height: spacing.space2),
        ],
      ],
    );
  }

  Future<void> _undo(
    BuildContext context,
    WidgetRef ref,
    SkillNoticeState noticeState,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final names = noticeState.installedSkillHarnesses
        .map((id) => id.displayName)
        .join(l10n.skillNoticeNamesSeparator);
    final result = await ref
        .read(skillNoticeControllerProvider.notifier)
        .undo();
    if (!context.mounted) return;
    switch (result) {
      case Success<void>():
        if (names.isNotEmpty) {
          HiveToast.show(
            context,
            message: l10n.skillNoticeUndoSuccess(names),
            tone: HiveToastTone.success,
          );
        }
      case FailureResult<void>(:final failure):
        HiveToast.show(
          context,
          message: l10n.skillNoticeUndoError(
            failure.message.trim().isNotEmpty
                ? failure.message
                : l10n.harnessesSkillErrorFallback,
          ),
          tone: HiveToastTone.danger,
        );
    }
  }
}
