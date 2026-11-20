import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/shared/widgets/area_placeholder_page.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Placeholder page for the Settings product area.
class SettingsPage extends StatelessWidget {
  /// Creates a [SettingsPage].
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AreaPlaceholderPage(
      title: l10n.navSettings,
      icon: HiveIcons.settings,
      emptyTitle: l10n.settingsEmptyTitle,
      emptyDescription: l10n.settingsEmptyDescription,
    );
  }
}
