import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/skills/controllers/outdated_tools_controller.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Global warning banner notifying the user when detected harnesses have an
/// outdated skill or Hive MCP installation.
class OutdatedToolsBanner extends ConsumerWidget {
  /// Creates an [OutdatedToolsBanner].
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outdated = ref.watch(outdatedHarnessesProvider);
    if (outdated.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final names = outdated
        .map((harness) => harness.displayName)
        .join(l10n.skillNoticeNamesSeparator);

    return HiveSlideIn(
      child: HiveBanner(
        key: const ValueKey<String>('outdated_tools_banner'),
        tone: HiveFeedbackTone.warning,
        liveRegion: true,
        title: l10n.outdatedBannerTitle(names),
        actions: <Widget>[
          HiveButton(
            key: const ValueKey<String>('outdated_tools_open'),
            label: l10n.outdatedBannerOpen,
            variant: HiveButtonVariant.secondary,
            size: HiveButtonSize.small,
            onPressed: () {
              unawaited(
                ref
                    .read(outdatedBannerAcknowledgementProvider.notifier)
                    .acknowledge(),
              );
              const HarnessesRoute().go(context);
            },
          ),
        ],
        onDismiss: () => unawaited(
          ref
              .read(outdatedBannerAcknowledgementProvider.notifier)
              .acknowledge(),
        ),
        dismissSemanticLabel: l10n.outdatedBannerDismiss,
      ),
    );
  }
}
