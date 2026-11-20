import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Error page displayed when navigation fails or a route is unknown.
class RouteErrorPage extends StatelessWidget {
  /// Creates a [RouteErrorPage].
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space4),
          child: HiveEmptyState(
            icon: HiveIcons.alert,
            title: l10n.routeErrorTitle,
            message: l10n.routeErrorDescription,
            action: HiveButton(
              label: l10n.routeErrorAction,
              icon: HiveIcons.overview,
              onPressed: () => const OverviewRoute().go(context),
            ),
          ),
        ),
      ),
    );
  }
}
