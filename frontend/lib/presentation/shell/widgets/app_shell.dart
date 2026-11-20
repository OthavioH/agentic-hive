import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

typedef _DestinationSpec = ({
  String path,
  HiveIconData icon,
  String label,
  void Function(BuildContext context) navigate,
});

/// Desktop application shell hosting [HiveSideRail] and the active route.
class AppShell extends StatelessWidget {
  /// Creates an [AppShell].
  const new({required this.location, required this.child, super.key});

  /// Current router path used to highlight the active rail destination.
  final String location;

  /// Active child page rendered beside the navigation rail.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final specs = <_DestinationSpec>[
      (
        path: OverviewRoute.path,
        icon: HiveIcons.overview,
        label: l10n.navOverview,
        navigate: (context) => const OverviewRoute().go(context),
      ),
      (
        path: WorkflowsRoute.path,
        icon: HiveIcons.workflows,
        label: l10n.navWorkflows,
        navigate: (context) => const WorkflowsRoute().go(context),
      ),
      (
        path: RunsRoute.path,
        icon: HiveIcons.runs,
        label: l10n.navRuns,
        navigate: (context) => const RunsRoute().go(context),
      ),
      (
        path: PausesRoute.path,
        icon: HiveIcons.pauses,
        label: l10n.navPauses,
        navigate: (context) => const PausesRoute().go(context),
      ),
      (
        path: AgentsRoute.path,
        icon: HiveIcons.agents,
        label: l10n.navAgents,
        navigate: (context) => const AgentsRoute().go(context),
      ),
      (
        path: HarnessesRoute.path,
        icon: HiveIcons.harnesses,
        label: l10n.navHarnesses,
        navigate: (context) => const HarnessesRoute().go(context),
      ),
      (
        path: SettingsRoute.path,
        icon: HiveIcons.settings,
        label: l10n.navSettings,
        navigate: (context) => const SettingsRoute().go(context),
      ),
    ];

    final matchedIndex = specs.indexWhere(
      (spec) => location == spec.path || location.startsWith('${spec.path}/'),
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
                    HiveRailDestination(icon: spec.icon, label: spec.label),
                ],
                selectedIndex: matchedIndex >= 0 ? matchedIndex : null,
                onSelected: (index) => specs[index].navigate(context),
                markLabel: l10n.appTitle,
                expandLabel: l10n.railExpandTooltip,
                collapseLabel: l10n.railCollapseTooltip,
              ),
              SizedBox(width: spacing.space2),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
