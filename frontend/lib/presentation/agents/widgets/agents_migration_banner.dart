import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Dismissible banner listing the agent files the move into `~/.agents/agents`
/// could not merge (ADR 0022).
class AgentsMigrationBanner extends StatelessWidget {
  /// Creates an [AgentsMigrationBanner].
  const new({required this.status, required this.onDismiss, super.key});

  /// The migration status; its conflicts are listed.
  final AgentsMigrationStatus status;

  /// Called when the user dismisses the banner.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    return HiveBanner(
      key: const Key('agents_migration_banner'),
      tone: HiveFeedbackTone.warning,
      title: l10n.agentsMigrationBannerTitle,
      message: l10n.agentsMigrationBannerMessage(
        status.legacyDir,
        status.targetDir,
      ),
      detail: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final conflict in status.conflicts)
            Text(
              conflict,
              style: typography.mono.copyWith(color: colors.onSurface),
            ),
        ],
      ),
      liveRegion: true,
      onDismiss: onDismiss,
      dismissSemanticLabel: l10n.agentsDismissTooltip,
    );
  }
}
