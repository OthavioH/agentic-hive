import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// What a page shows when it has nothing yet: an icon, a title, an
/// explanation and optionally one action.
class HiveEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const new({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  /// Icon shown in a circle above the title.
  final HiveIconData icon;

  /// Short headline, for example "No workflows yet".
  final String title;

  /// Optional explanation of what to do next.
  final String? message;

  /// Optional action, usually one `HiveButton`.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final body = message;
    final button = action;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: spacing.space8 * 6),
        child: Padding(
          padding: EdgeInsets.all(spacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface2,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.borderSubtle,
                    width: context.hiveElevation.hairline,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(spacing.space2),
                  child: HiveIcon(
                    icon,
                    size: spacing.space3,
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ),
              SizedBox(height: spacing.space2),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: typography.titleSmall.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (body != null) ...<Widget>[
                SizedBox(height: spacing.space1),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: typography.body.copyWith(color: colors.onSurfaceMuted),
                ),
              ],
              if (button != null) ...<Widget>[
                SizedBox(height: spacing.space3),
                button,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
