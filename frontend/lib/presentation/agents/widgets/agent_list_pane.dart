import 'package:agentic_hive_frontend/core/result/failure.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/agents/controllers/agents_state.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Master pane of the Agents library: search field, tag filter chips, and the
/// scrollable list of agents.
class AgentListPane extends StatefulWidget {
  /// Creates an [AgentListPane].
  const new({
    required this.state,
    required this.onSearchChanged,
    required this.onToggleTag,
    required this.onSelectAgent,
    required this.onCreate,
    required this.onRetry,
    super.key,
  });

  /// Current controller state.
  final AgentsState state;

  /// Called when the search input changes.
  final ValueChanged<String> onSearchChanged;

  /// Called when a tag filter chip is toggled.
  final ValueChanged<String> onToggleTag;

  /// Called when an agent item is selected.
  final ValueChanged<AgentSummary> onSelectAgent;

  /// Called when the user triggers creating a new agent from the empty state.
  final VoidCallback onCreate;

  /// Called when retrying a failed list load.
  final VoidCallback onRetry;

  @override
  State<AgentListPane> createState() => _AgentListPaneState();
}

class _AgentListPaneState extends State<AgentListPane> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.searchQuery);
  }

  @override
  void didUpdateWidget(AgentListPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.state.searchQuery) {
      _searchController.text = widget.state.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final availableTags = widget.state.availableTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(spacing.space2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HiveTextField(
                semanticLabel: l10n.agentsSearchHint,
                hintText: l10n.agentsSearchHint,
                controller: _searchController,
                leadingIcon: HiveIcons.search,
                onChanged: widget.onSearchChanged,
                trailing: widget.state.searchQuery.isEmpty
                    ? null
                    : HiveIconButton(
                        icon: HiveIcons.close,
                        semanticLabel: l10n.agentsSearchClearTooltip,
                        size: HiveButtonSize.small,
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearchChanged('');
                        },
                      ),
              ),
              if (availableTags.isNotEmpty) ...<Widget>[
                SizedBox(height: spacing.space1),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (
                        var i = 0;
                        i < availableTags.length;
                        i++
                      ) ...<Widget>[
                        if (i > 0) SizedBox(width: spacing.space1),
                        HiveChip.filter(
                          label: availableTags[i],
                          selected: widget.state.selectedTags.contains(
                            availableTags[i],
                          ),
                          onSelected: (_) =>
                              widget.onToggleTag(availableTags[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Divider(
          height: context.hiveElevation.hairline,
          thickness: context.hiveElevation.hairline,
          color: colors.borderSubtle,
        ),
        Expanded(child: _buildBody(context, l10n)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;

    return widget.state.agents.when(
      loading: () => Center(
        child: HiveSpinner(size: spacing.space4, color: colors.accent),
      ),
      error: (error, _) {
        final message = error is Failure ? error.message : error.toString();
        return Padding(
          padding: EdgeInsets.all(spacing.space2),
          child: Align(
            alignment: Alignment.topCenter,
            child: HiveBanner(
              tone: HiveFeedbackTone.danger,
              title: l10n.agentsLoadErrorTitle,
              message: message,
              actions: <Widget>[
                HiveButton(
                  label: l10n.agentsRetryAction,
                  variant: HiveButtonVariant.secondary,
                  size: HiveButtonSize.small,
                  onPressed: widget.onRetry,
                ),
              ],
            ),
          ),
        );
      },
      data: (allAgents) {
        if (allAgents.isEmpty) {
          return HiveEmptyState(
            icon: HiveIcons.agents,
            title: l10n.agentsEmptyTitle,
            message: l10n.agentsEmptyDescription,
            action: HiveButton(
              label: l10n.agentsNewAction,
              icon: HiveIcons.add,
              onPressed: widget.onCreate,
            ),
          );
        }

        final filtered = widget.state.filteredAgents;
        if (filtered.isEmpty) {
          return HiveEmptyState(
            icon: HiveIcons.search,
            title: l10n.agentsNoMatchesTitle,
            message: l10n.agentsNoMatchesDescription,
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(spacing.space2),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => SizedBox(height: spacing.space1),
          itemBuilder: (context, index) {
            final agent = filtered[index];
            final selected =
                !widget.state.isCreating &&
                widget.state.selectedAgentId == agent.id &&
                (widget.state.detail.value?.scope ?? agent.scope) ==
                    agent.scope;
            return _AgentListTile(
              agent: agent,
              selected: selected,
              borderColor: selected ? colors.accent : colors.borderSubtle,
              onTap: () => widget.onSelectAgent(agent),
            );
          },
        );
      },
    );
  }
}

class _AgentListTile extends StatelessWidget {
  const new({
    required this.agent,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });

  final AgentSummary agent;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final radius = context.hiveRadii.card;
    final displayTitle = agent.name.trim().isEmpty ? agent.id : agent.name;

    return Semantics(
      button: true,
      selected: selected,
      label: displayTitle,
      child: Material(
        color: selected ? colors.surface3 : colors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: borderColor,
            width: context.hiveElevation.hairline,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(spacing.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.labelLarge.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.space1),
                    HiveBadge(
                      label: agent.scope == AgentScope.workspace
                          ? l10n.agentsScopeWorkspaceBadge
                          : l10n.agentsScopeGlobalBadge,
                      tone: agent.scope == AgentScope.workspace
                          ? HiveBadgeTone.accentMuted
                          : HiveBadgeTone.neutral,
                    ),
                    if (agent.overridden) ...<Widget>[
                      SizedBox(width: spacing.space1),
                      HiveBadge(
                        label: l10n.agentsOverriddenBadge,
                        tone: HiveBadgeTone.warning,
                      ),
                    ],
                    if (agent.parseError != null) ...<Widget>[
                      SizedBox(width: spacing.space1),
                      HiveBadge(
                        label: l10n.agentsParseErrorBadge,
                        tone: HiveBadgeTone.danger,
                        icon: HiveIcons.alert,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: spacing.spaceHalf),
                Text(
                  agent.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.mono.copyWith(color: colors.onSurfaceMuted),
                ),
                if (agent.description.trim().isNotEmpty) ...<Widget>[
                  SizedBox(height: spacing.space1),
                  Text(
                    agent.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.bodySmall.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ],
                if (agent.tags.isNotEmpty) ...<Widget>[
                  SizedBox(height: spacing.space1),
                  Wrap(
                    spacing: spacing.spaceHalf,
                    runSpacing: spacing.spaceHalf,
                    children: <Widget>[
                      for (final tag in agent.tags) HiveBadge(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
