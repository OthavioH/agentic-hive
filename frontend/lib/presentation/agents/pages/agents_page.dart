import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/shared/widgets/area_placeholder_page.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Placeholder page for the Agents product area.
class AgentsPage extends StatelessWidget {
  /// Creates an [AgentsPage].
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AreaPlaceholderPage(
      title: l10n.navAgents,
      icon: HiveIcons.agents,
      emptyTitle: l10n.agentsEmptyTitle,
      emptyDescription: l10n.agentsEmptyDescription,
    );
  }
}
