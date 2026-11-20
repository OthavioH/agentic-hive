import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/shared/widgets/area_placeholder_page.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Placeholder page for the Workflows product area.
class WorkflowsPage extends StatelessWidget {
  /// Creates a [WorkflowsPage].
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AreaPlaceholderPage(
      title: l10n.navWorkflows,
      icon: HiveIcons.workflows,
      emptyTitle: l10n.workflowsEmptyTitle,
      emptyDescription: l10n.workflowsEmptyDescription,
    );
  }
}
