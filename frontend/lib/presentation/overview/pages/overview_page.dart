import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/shared/widgets/area_placeholder_page.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Placeholder page for the Overview product area.
class OverviewPage extends StatelessWidget {
  /// Creates an [OverviewPage].
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AreaPlaceholderPage(
      title: l10n.navOverview,
      icon: HiveIcons.overview,
      emptyTitle: l10n.overviewEmptyTitle,
      emptyDescription: l10n.overviewEmptyDescription,
    );
  }
}
