import 'package:agentic_hive_frontend/presentation/agents/pages/agents_page.dart';
import 'package:agentic_hive_frontend/presentation/connecting/pages/connecting_page.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/pages/harnesses_page.dart';
import 'package:agentic_hive_frontend/presentation/overview/pages/overview_page.dart';
import 'package:agentic_hive_frontend/presentation/pauses/pages/pauses_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/runs_page.dart';
import 'package:agentic_hive_frontend/presentation/settings/pages/settings_page.dart';
import 'package:agentic_hive_frontend/presentation/shell/widgets/app_shell.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflows_page.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

part 'app_routes.g.dart';

/// Shell route wrapping the desktop navigation rail and primary product areas.
@TypedShellRoute<AppShellRoute>(
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<OverviewRoute>(path: OverviewRoute.path),
    TypedGoRoute<WorkflowsRoute>(path: WorkflowsRoute.path),
    TypedGoRoute<RunsRoute>(path: RunsRoute.path),
    TypedGoRoute<PausesRoute>(path: PausesRoute.path),
    TypedGoRoute<AgentsRoute>(path: AgentsRoute.path),
    TypedGoRoute<HarnessesRoute>(path: HarnessesRoute.path),
    TypedGoRoute<SettingsRoute>(path: SettingsRoute.path),
  ],
)
class AppShellRoute extends ShellRouteData {
  /// Creates an [AppShellRoute].
  const new();

  @override
  Widget builder(BuildContext context, GoRouterState state, Widget navigator) {
    return AppShell(location: state.uri.path, child: navigator);
  }
}

/// Typed route for `/overview`.
class OverviewRoute extends GoRouteData with $OverviewRoute {
  /// Creates an [OverviewRoute].
  const new();

  /// Route path.
  static const String path = '/overview';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const OverviewPage();
}

/// Typed route for `/workflows`.
class WorkflowsRoute extends GoRouteData with $WorkflowsRoute {
  /// Creates a [WorkflowsRoute].
  const new();

  /// Route path.
  static const String path = '/workflows';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const WorkflowsPage();
}

/// Typed route for `/runs`.
class RunsRoute extends GoRouteData with $RunsRoute {
  /// Creates a [RunsRoute].
  const new();

  /// Route path.
  static const String path = '/runs';

  @override
  Widget build(BuildContext context, GoRouterState state) => const RunsPage();
}

/// Typed route for `/pauses`.
class PausesRoute extends GoRouteData with $PausesRoute {
  /// Creates a [PausesRoute].
  const new();

  /// Route path.
  static const String path = '/pauses';

  @override
  Widget build(BuildContext context, GoRouterState state) => const PausesPage();
}

/// Typed route for `/agents`.
class AgentsRoute extends GoRouteData with $AgentsRoute {
  /// Creates an [AgentsRoute].
  const new();

  /// Route path.
  static const String path = '/agents';

  @override
  Widget build(BuildContext context, GoRouterState state) => const AgentsPage();
}

/// Typed route for `/harnesses`.
class HarnessesRoute extends GoRouteData with $HarnessesRoute {
  /// Creates a [HarnessesRoute].
  const new();

  /// Route path.
  static const String path = '/harnesses';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const HarnessesPage();
}

/// Typed route for `/settings`.
class SettingsRoute extends GoRouteData with $SettingsRoute {
  /// Creates a [SettingsRoute].
  const new();

  /// Route path.
  static const String path = '/settings';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsPage();
}

/// Typed route for `/connecting`, shown outside the shell.
@TypedGoRoute<ConnectingRoute>(path: ConnectingRoute.path)
class ConnectingRoute extends GoRouteData with $ConnectingRoute {
  /// Creates a [ConnectingRoute].
  const new();

  /// Route path.
  static const String path = '/connecting';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ConnectingPage();
}
