import 'dart:async';

import 'package:agentic_hive_frontend/core/shell/side_rail_pin_controller.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/pauses/controllers/pending_pauses_count_provider.dart';
import 'package:agentic_hive_frontend/presentation/skills/widgets/skill_notice_host.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/side_rail_tree_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/side_rail_tree.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/workspace_switcher_bar.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

typedef _DestinationSpec = ({
  String path,
  HiveIconData icon,
  String label,
  int? badgeCount,
  String? semanticLabel,
  void Function(BuildContext context) navigate,
});

/// Desktop application shell hosting [HiveSideRail] and the active route.
class AppShell extends ConsumerStatefulWidget {
  /// Creates an [AppShell].
  const new({required this.location, required this.child, super.key});

  /// Current router path used to highlight the active rail destination.
  final String location;

  /// Active child page rendered beside the navigation rail.
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final HiveRailSectionController _sectionController =
      HiveRailSectionController();

  @override
  void dispose() {
    _sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final pendingPausesCount =
        ref.watch(pendingPausesCountProvider).asData?.value ?? 0;
    final pinned = ref.watch(sideRailPinControllerProvider);
    final treeAsync = ref.watch(sideRailTreeControllerProvider);
    final treeState = treeAsync.asData?.value;
    final isRefreshing = treeState?.isRefreshing ?? false;
    final activeRunsCount = treeState == null
        ? 0
        : treeState.workspaces.fold<int>(
            0,
            (sum, ws) =>
                sum +
                ws.worktrees.fold<int>(
                  0,
                  (wtSum, wt) => wtSum + wt.activeRuns.length,
                ),
          );
    final specs = <_DestinationSpec>[
      (
        path: OverviewRoute.path,
        icon: HiveIcons.overview,
        label: l10n.navOverview,
        badgeCount: null,
        semanticLabel: null,
        navigate: (context) => const OverviewRoute().go(context),
      ),
      (
        path: WorkflowsRoute.path,
        icon: HiveIcons.workflows,
        label: l10n.navWorkflows,
        badgeCount: null,
        semanticLabel: null,
        navigate: (context) => const WorkflowsRoute().go(context),
      ),
      (
        path: RunsRoute.path,
        icon: HiveIcons.runs,
        label: l10n.navRuns,
        badgeCount: null,
        semanticLabel: null,
        navigate: (context) => const RunsRoute().go(context),
      ),
      (
        path: PausesRoute.path,
        icon: HiveIcons.pauses,
        label: l10n.navPauses,
        badgeCount: pendingPausesCount > 0 ? pendingPausesCount : null,
        semanticLabel: pendingPausesCount > 0
            ? l10n.navPausesPendingSemantic(pendingPausesCount)
            : null,
        navigate: (context) => const PausesRoute().go(context),
      ),
      (
        path: AgentsRoute.path,
        icon: HiveIcons.agents,
        label: l10n.navAgents,
        badgeCount: null,
        semanticLabel: null,
        navigate: (context) => const AgentsRoute().go(context),
      ),
      (
        path: HarnessesRoute.path,
        icon: HiveIcons.harnesses,
        label: l10n.navHarnesses,
        badgeCount: null,
        semanticLabel: null,
        navigate: (context) => const HarnessesRoute().go(context),
      ),
      (
        path: SettingsRoute.path,
        icon: HiveIcons.settings,
        label: l10n.navSettings,
        badgeCount: null,
        semanticLabel: null,
        navigate: (context) => const SettingsRoute().go(context),
      ),
    ];

    final matchedIndex = specs.indexWhere(
      (spec) =>
          widget.location == spec.path ||
          widget.location.startsWith('${spec.path}/'),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              HiveSideRail(
                destinations: <HiveRailDestination>[
                  for (final spec in specs)
                    HiveRailDestination(
                      icon: spec.icon,
                      label: spec.label,
                      badgeCount: spec.badgeCount,
                      semanticLabel: spec.semanticLabel,
                    ),
                ],
                selectedIndex: matchedIndex >= 0 ? matchedIndex : null,
                onSelected: (index) => specs[index].navigate(context),
                markLabel: l10n.appTitle,
                expandLabel: l10n.railExpandTooltip,
                collapseLabel: l10n.railCollapseTooltip,
                section: HiveRailSection(
                  icon: HiveIcons.folder,
                  label: l10n.navWorkspaces,
                  title: l10n.sideRailTreeTitle,
                  badgeCount: activeRunsCount > 0 ? activeRunsCount : null,
                  semanticLabel: activeRunsCount > 0
                      ? l10n.navWorkspacesActiveSemantic(activeRunsCount)
                      : null,
                  pinned: pinned,
                  onPinnedChanged: (value) => unawaited(
                    ref
                        .read(sideRailPinControllerProvider.notifier)
                        .setPinned(value),
                  ),
                  pinLabel: l10n.railPanelPin,
                  unpinLabel: l10n.railPanelUnpin,
                  controller: _sectionController,
                  trailing: HiveIconButton(
                    key: const Key('side_rail_tree_refresh_button'),
                    icon: HiveIcons.refresh,
                    size: HiveButtonSize.small,
                    semanticLabel: l10n.sideRailTreeRefreshTooltip,
                    loading: isRefreshing,
                    onPressed: () => unawaited(
                      ref
                          .read(sideRailTreeControllerProvider.notifier)
                          .refresh(),
                    ),
                  ),
                  child: SideRailTree(
                    currentLocation: widget.location,
                    onRunSelected: _sectionController.close,
                  ),
                ),
              ),
              SizedBox(width: spacing.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const WorkspaceSwitcherBar(),
                    SizedBox(height: spacing.space2),
                    SkillNoticeHost(location: widget.location),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
