import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/overview/controllers/overview_controller.dart';
import 'package:agentic_hive_frontend/presentation/overview/utils/overview_l10n.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_section_header.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Active Agents & Nodes section on the Overview dashboard.
class OverviewActiveNodesSection extends StatelessWidget {
  /// Creates an [OverviewActiveNodesSection].
  const new({required this.nodes, required this.onOpenRun, super.key});

  /// Executing or paused nodes belonging to active runs.
  final List<ActiveNodeSummary> nodes;

  /// Called when an active node card is pressed to open its run.
  final ValueChanged<String> onOpenRun;

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
          title: l10n.overviewSectionActiveNodes,
          count: nodes.length,
        ),
        if (nodes.isEmpty)
          HiveCard(
            child: Text(
              l10n.overviewActiveNodesEmpty,
              style: typography.body.copyWith(color: colors.onSurfaceMuted),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.space2,
            children: <Widget>[
              for (final node in nodes)
                _ActiveNodeCard(
                  node: node,
                  onPressed: () => onOpenRun(node.runId),
                ),
            ],
          ),
      ],
    );
  }
}

class _ActiveNodeCard extends StatelessWidget {
  const new({required this.node, required this.onPressed});

  final ActiveNodeSummary node;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;

    final scope = context.dependOnInheritedWidgetOfExactType<NodeVisualScope>();
    final visual =
        scope?.registry.resolve(node.nodeType) ?? NodeVisual.fallback;
    final nodeTypeLabel = resolveNodeVisualLabel(l10n, visual.labelKey);

    final agentName = node.agentName?.trim();
    final primaryTitle = (agentName != null && agentName.isNotEmpty)
        ? agentName
        : (node.nodeLabel.isNotEmpty ? node.nodeLabel : nodeTypeLabel);
    final statusLabel = OverviewL10n.localizeActiveNodeStatus(
      l10n,
      node.status,
    );

    return HiveCard(
      key: ValueKey<String>(
        'overview_active_node_${node.runId}_${node.nodeId}',
      ),
      semanticLabel: l10n.overviewOpenNodeRunSemanticLabel(
        primaryTitle,
        node.workflowName,
      ),
      onPressed: onPressed,
      child: Row(
        spacing: spacing.space2,
        children: <Widget>[
          HiveAgentAvatar(
            visual: visual,
            semanticLabel: primaryTitle,
            status: OverviewL10n.nodeStatusFor(node.status),
            statusLabel: statusLabel,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.spaceHalf,
              children: <Widget>[
                Text(
                  primaryTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.labelLarge.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  '$nodeTypeLabel · ${node.workflowName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodySmall.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          HiveBadge(
            label: statusLabel,
            tone: OverviewL10n.nodeBadgeToneFor(node.status),
          ),
          _ActiveNodeElapsedText(startedAt: node.startedAt),
        ],
      ),
    );
  }
}

class _ActiveNodeElapsedText extends ConsumerWidget {
  const new({required this.startedAt});

  final DateTime startedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(overviewNowProvider);
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    return Text(
      OverviewL10n.formatElapsed(startedAt, now),
      style: typography.mono.copyWith(color: colors.onSurfaceMuted),
    );
  }
}
