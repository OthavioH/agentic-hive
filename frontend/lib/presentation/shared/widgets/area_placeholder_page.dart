import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Shared layout for product area placeholder pages.
class AreaPlaceholderPage extends StatelessWidget {
  /// Creates an [AreaPlaceholderPage].
  const new({
    required this.title,
    required this.icon,
    required this.emptyTitle,
    required this.emptyDescription,
    super.key,
  });

  /// Localized page header title.
  final String title;

  /// Design-system icon displayed in the empty state.
  final HiveIconData icon;

  /// Localized empty-state headline.
  final String emptyTitle;

  /// Localized empty-state description.
  final String emptyDescription;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    return Padding(
      padding: EdgeInsets.all(spacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HivePageHeader(title: title),
          Expanded(
            child: HiveEmptyState(
              icon: icon,
              title: emptyTitle,
              message: emptyDescription,
            ),
          ),
        ],
      ),
    );
  }
}
