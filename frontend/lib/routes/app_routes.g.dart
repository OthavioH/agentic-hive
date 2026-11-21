// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$appShellRoute, $connectingRoute];

RouteBase get $appShellRoute => ShellRouteData.$route(
  factory: $AppShellRouteExtension._fromState,
  routes: [
    GoRouteData.$route(
      path: '/overview',
      hasOverriddenOnExit: false,
      factory: $OverviewRoute._fromState,
    ),
    GoRouteData.$route(
      path: '/workflows',
      hasOverriddenOnExit: false,
      factory: $WorkflowsRoute._fromState,
      routes: [
        GoRouteData.$route(
          path: ':id',
          hasOverriddenOnExit: false,
          factory: $WorkflowEditorRoute._fromState,
        ),
      ],
    ),
    GoRouteData.$route(
      path: '/runs',
      hasOverriddenOnExit: false,
      factory: $RunsRoute._fromState,
    ),
    GoRouteData.$route(
      path: '/pauses',
      hasOverriddenOnExit: false,
      factory: $PausesRoute._fromState,
    ),
    GoRouteData.$route(
      path: '/agents',
      hasOverriddenOnExit: false,
      factory: $AgentsRoute._fromState,
    ),
    GoRouteData.$route(
      path: '/harnesses',
      hasOverriddenOnExit: false,
      factory: $HarnessesRoute._fromState,
    ),
    GoRouteData.$route(
      path: '/settings',
      hasOverriddenOnExit: false,
      factory: $SettingsRoute._fromState,
    ),
  ],
);

extension $AppShellRouteExtension on AppShellRoute {
  static AppShellRoute _fromState(GoRouterState state) => const AppShellRoute();
}

mixin $OverviewRoute on GoRouteData {
  static OverviewRoute _fromState(GoRouterState state) => const OverviewRoute();

  @override
  String get location => GoRouteData.$location('/overview');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $WorkflowsRoute on GoRouteData {
  static WorkflowsRoute _fromState(GoRouterState state) =>
      const WorkflowsRoute();

  @override
  String get location => GoRouteData.$location('/workflows');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $WorkflowEditorRoute on GoRouteData {
  static WorkflowEditorRoute _fromState(GoRouterState state) =>
      WorkflowEditorRoute(id: state.pathParameters['id']!);

  WorkflowEditorRoute get _self => this as WorkflowEditorRoute;

  @override
  String get location =>
      GoRouteData.$location('/workflows/${Uri.encodeComponent(_self.id)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $RunsRoute on GoRouteData {
  static RunsRoute _fromState(GoRouterState state) => const RunsRoute();

  @override
  String get location => GoRouteData.$location('/runs');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $PausesRoute on GoRouteData {
  static PausesRoute _fromState(GoRouterState state) => const PausesRoute();

  @override
  String get location => GoRouteData.$location('/pauses');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $AgentsRoute on GoRouteData {
  static AgentsRoute _fromState(GoRouterState state) => const AgentsRoute();

  @override
  String get location => GoRouteData.$location('/agents');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $HarnessesRoute on GoRouteData {
  static HarnessesRoute _fromState(GoRouterState state) =>
      const HarnessesRoute();

  @override
  String get location => GoRouteData.$location('/harnesses');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $connectingRoute => GoRouteData.$route(
  path: '/connecting',
  hasOverriddenOnExit: false,
  factory: $ConnectingRoute._fromState,
);

mixin $ConnectingRoute on GoRouteData {
  static ConnectingRoute _fromState(GoRouterState state) =>
      const ConnectingRoute();

  @override
  String get location => GoRouteData.$location('/connecting');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
