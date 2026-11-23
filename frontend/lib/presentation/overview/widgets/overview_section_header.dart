import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Composed section header using design-system typography, badge, and ghost
/// link button tokens.
class OverviewSectionHeader extends StatelessWidget {
  /// Creates an [OverviewSectionHeader].
  const new({
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    super.key,
  });

  /// Localized section title.
  final String title;

  /// Optional item count badge.
  final int? count;

  /// Optional trailing ghost button label (for example "View all").
  final String? actionLabel;

  /// Callback when the trailing ghost button is pressed.
  final VoidCallback? onAction;

  /// Optional key for the trailing ghost button.
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final itemCount = count;
    final trailingLabel = actionLabel;
    final trailingAction = onAction;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.space2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              spacing: spacing.space1,
              children: <Widget>[
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.titleSmall.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
                if (itemCount != null) HiveBadge(label: '$itemCount'),
              ],
            ),
          ),
          if (trailingLabel != null && trailingAction != null)
            HiveButton(
              key: actionKey,
              label: trailingLabel,
              variant: HiveButtonVariant.ghost,
              size: HiveButtonSize.small,
              onPressed: trailingAction,
            ),
        ],
      ),
    );
  }
}
