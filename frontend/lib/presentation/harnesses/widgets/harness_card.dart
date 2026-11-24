import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/skill_row_models.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/widgets/harness_skill_row.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Displays a single detected CLI harness, its status, version, executable
/// path, copy/re-check actions, and actionable guidance.
class HarnessCard extends StatelessWidget {
  /// Creates a [HarnessCard].
  const new({
    required this.harness,
    required this.isRefreshing,
    required this.isGlobalRefreshing,
    required this.onRecheck,
    required this.onCopyPath,
    this.isInstallingMcp = false,
    this.onInstallMcp,
    this.skillAction,
    this.skillError,
    this.onInstallSkill,
    this.onUpdateSkill,
    this.onRemoveSkill,
    this.onRetrySkill,
    super.key,
  });

  /// Detected harness metadata.
  final HarnessInfo harness;

  /// Whether this card's individual re-check request is in flight.
  final bool isRefreshing;

  /// Whether a global refresh is currently in flight.
  final bool isGlobalRefreshing;

  /// Whether installing or updating the Hive MCP server is in flight for this
  /// card.
  final bool isInstallingMcp;

  /// Called when the user triggers an individual re-check.
  final VoidCallback onRecheck;

  /// Called when the user copies [HarnessInfo.executablePath].
  final ValueChanged<String> onCopyPath;

  /// Called when the user triggers Hive MCP installation or update.
  final VoidCallback? onInstallMcp;

  /// In-flight skill operation for this harness, if any.
  final SkillRowAction? skillAction;

  /// Last failed skill operation for this harness, if any.
  final SkillRowError? skillError;

  /// Called when the user triggers skill installation.
  final VoidCallback? onInstallSkill;

  /// Called when the user triggers skill update.
  final VoidCallback? onUpdateSkill;

  /// Called when the user triggers skill removal.
  final VoidCallback? onRemoveSkill;

  /// Called when the user taps Retry on a failed skill banner.
  final VoidCallback? onRetrySkill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;

    final statusSpec = _statusSpec(harness.status, l10n);
    final guidance = _guidanceText(harness, l10n);
    final executablePath = harness.executablePath;
    final version = harness.version;

    return HiveCard(
      key: ValueKey<String>('harness_card_${harness.id.wireName}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              HiveInsetPanel(
                padding: HiveInsetPadding.tight,
                child: HiveIcon(
                  _harnessLogo(harness.id),
                  size: spacing.space3,
                  color: colors.onSurface,
                ),
              ),
              SizedBox(width: spacing.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      harness.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.titleSmall.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    SizedBox(height: spacing.spaceHalf),
                    Text(
                      version != null && version.isNotEmpty
                          ? l10n.harnessesVersionLabel(version)
                          : l10n.harnessesVersionUnknown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodySmall.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.space1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  HiveStatusDot(
                    status: statusSpec.nodeStatus,
                    semanticLabel: statusSpec.label,
                  ),
                  SizedBox(width: spacing.space1),
                  HiveBadge(
                    label: statusSpec.label,
                    tone: statusSpec.tone,
                    icon: statusSpec.icon,
                  ),
                  SizedBox(width: spacing.space1),
                  HiveIconButton(
                    key: ValueKey<String>(
                      'harness_recheck_${harness.id.wireName}',
                    ),
                    icon: HiveIcons.refresh,
                    semanticLabel: l10n.harnessesRecheckTooltip(
                      harness.displayName,
                    ),
                    variant: HiveButtonVariant.secondary,
                    size: HiveButtonSize.small,
                    loading: isRefreshing,
                    onPressed: isGlobalRefreshing ? null : onRecheck,
                  ),
                ],
              ),
            ],
          ),
          if (executablePath != null && executablePath.isNotEmpty) ...<Widget>[
            SizedBox(height: spacing.space2),
            HiveInsetPanel(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          l10n.harnessesExecutablePathLabel,
                          style: typography.label.copyWith(
                            color: colors.onSurfaceMuted,
                          ),
                        ),
                        SizedBox(height: spacing.spaceHalf),
                        Text(
                          executablePath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.mono.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: spacing.space1),
                  HiveIconButton(
                    key: ValueKey<String>(
                      'harness_copy_${harness.id.wireName}',
                    ),
                    icon: HiveIcons.copy,
                    semanticLabel: l10n.harnessesCopyPathTooltip(
                      harness.displayName,
                    ),
                    size: HiveButtonSize.small,
                    onPressed: () => onCopyPath(executablePath),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: spacing.space2),
          _McpStatusSection(
            harness: harness,
            isBusy: isRefreshing || isGlobalRefreshing || isInstallingMcp,
            isInstallingMcp: isInstallingMcp,
            onInstallMcp: onInstallMcp,
          ),
          if (harness.skillStatus != null) ...<Widget>[
            SizedBox(height: spacing.space2),
            HarnessSkillRow(
              harness: harness,
              isDisabled: isRefreshing || isGlobalRefreshing,
              busyAction: skillAction,
              error: skillError,
              onInstall: onInstallSkill ?? _noop,
              onUpdate: onUpdateSkill ?? _noop,
              onRemove: onRemoveSkill ?? _noop,
              onRecheck: onRecheck,
              onRetry: onRetrySkill ?? _noop,
            ),
          ],
          if (guidance != null) ...<Widget>[
            SizedBox(height: spacing.space2),
            HiveInsetPanel(
              padding: HiveInsetPadding.comfortable,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  HiveIcon(
                    statusSpec.icon,
                    size: spacing.space2,
                    color: _guidanceIconColor(harness.status, colors),
                  ),
                  SizedBox(width: spacing.space1),
                  Expanded(
                    child: Text(
                      guidance,
                      style: typography.bodySmall.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  HiveIconData _harnessLogo(HarnessId id) => switch (id) {
    HarnessId.claudeCode => HiveIcons.harnessClaudeCode,
    HarnessId.codex => HiveIcons.harnessCodex,
    HarnessId.geminiCli => HiveIcons.harnessGeminiCli,
    HarnessId.antigravity => HiveIcons.harnessAntigravity,
  };

  ({
    String label,
    HiveBadgeTone tone,
    HiveIconData icon,
    HiveNodeStatus nodeStatus,
  })
  _statusSpec(HarnessStatus status, AppLocalizations l10n) => switch (status) {
    HarnessStatus.ready => (
      label: l10n.harnessStatusReady,
      tone: HiveBadgeTone.success,
      icon: HiveIcons.check,
      nodeStatus: HiveNodeStatus.succeeded,
    ),
    HarnessStatus.notInstalled => (
      label: l10n.harnessStatusNotInstalled,
      tone: HiveBadgeTone.neutral,
      icon: HiveIcons.close,
      nodeStatus: HiveNodeStatus.idle,
    ),
    HarnessStatus.authError => (
      label: l10n.harnessStatusAuthError,
      tone: HiveBadgeTone.warning,
      icon: HiveIcons.alert,
      nodeStatus: HiveNodeStatus.paused,
    ),
    HarnessStatus.outdated => (
      label: l10n.harnessStatusOutdated,
      tone: HiveBadgeTone.warning,
      icon: HiveIcons.alert,
      nodeStatus: HiveNodeStatus.paused,
    ),
    HarnessStatus.unavailable => (
      label: l10n.harnessStatusUnavailable,
      tone: HiveBadgeTone.danger,
      icon: HiveIcons.alert,
      nodeStatus: HiveNodeStatus.failed,
    ),
  };

  String? _guidanceText(
    HarnessInfo info,
    AppLocalizations l10n,
  ) => switch (info.status) {
    HarnessStatus.ready => null,
    HarnessStatus.notInstalled => l10n.harnessGuidanceNotInstalled,
    HarnessStatus.authError => l10n.harnessGuidanceAuthError(info.displayName),
    HarnessStatus.outdated => l10n.harnessGuidanceOutdated(info.displayName),
    HarnessStatus.unavailable => l10n.harnessGuidanceUnavailable,
  };

  Color _guidanceIconColor(HarnessStatus status, HiveColors colors) =>
      switch (status) {
        HarnessStatus.ready => colors.success,
        HarnessStatus.notInstalled => colors.onSurfaceMuted,
        HarnessStatus.authError || HarnessStatus.outdated => colors.warning,
        HarnessStatus.unavailable => colors.danger,
      };

  static void _noop() {}
}

class _McpStatusSection extends StatelessWidget {
  const new({
    required this.harness,
    required this.isBusy,
    required this.isInstallingMcp,
    required this.onInstallMcp,
  });

  final HarnessInfo harness;
  final bool isBusy;
  final bool isInstallingMcp;
  final VoidCallback? onInstallMcp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;

    final cliNotInstalled = harness.status == HarnessStatus.notInstalled;
    final mcpSpec = _mcpStatusSpec(harness.mcpStatus, cliNotInstalled, l10n);
    final showAction =
        !cliNotInstalled &&
        (harness.mcpStatus == HarnessMcpStatus.notInstalled ||
            harness.mcpStatus == HarnessMcpStatus.outdated ||
            harness.mcpStatus == HarnessMcpStatus.unknown);
    final mcpMessage = harness.mcpMessage;

    return HiveInsetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: HiveBadge(
                    label: mcpSpec.label,
                    tone: mcpSpec.tone,
                    icon: mcpSpec.icon,
                  ),
                ),
              ),
              if (showAction) ...<Widget>[
                SizedBox(width: spacing.space1),
                HiveButton(
                  key: ValueKey<String>(
                    'harness_mcp_install_${harness.id.wireName}',
                  ),
                  label: harness.mcpStatus == HarnessMcpStatus.outdated
                      ? l10n.harnessesMcpUpdate
                      : l10n.harnessesMcpInstall,
                  variant: HiveButtonVariant.secondary,
                  size: HiveButtonSize.small,
                  loading: isInstallingMcp,
                  onPressed: isBusy ? null : onInstallMcp,
                ),
              ],
            ],
          ),
          if (!cliNotInstalled &&
              mcpMessage != null &&
              mcpMessage.isNotEmpty) ...<Widget>[
            SizedBox(height: spacing.space1),
            Text(
              mcpMessage,
              style: typography.bodySmall.copyWith(
                color: colors.onSurfaceMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  ({String label, HiveBadgeTone tone, HiveIconData icon}) _mcpStatusSpec(
    HarnessMcpStatus status,
    bool cliNotInstalled,
    AppLocalizations l10n,
  ) {
    if (cliNotInstalled) {
      return (
        label: l10n.harnessesMcpStatusNotApplicable,
        tone: HiveBadgeTone.neutral,
        icon: HiveIcons.close,
      );
    }
    return switch (status) {
      HarnessMcpStatus.installed => (
        label: l10n.harnessesMcpStatusInstalled,
        tone: HiveBadgeTone.success,
        icon: HiveIcons.check,
      ),
      HarnessMcpStatus.notInstalled => (
        label: l10n.harnessesMcpStatusNotInstalled,
        tone: HiveBadgeTone.warning,
        icon: HiveIcons.close,
      ),
      HarnessMcpStatus.outdated => (
        label: l10n.harnessesMcpStatusOutdated,
        tone: HiveBadgeTone.warning,
        icon: HiveIcons.alert,
      ),
      HarnessMcpStatus.unsupported => (
        label: l10n.harnessesMcpStatusUnsupported,
        tone: HiveBadgeTone.neutral,
        icon: HiveIcons.info,
      ),
      HarnessMcpStatus.unknown => (
        label: l10n.harnessesMcpStatusUnknown,
        tone: HiveBadgeTone.neutral,
        icon: HiveIcons.info,
      ),
    };
  }
}
