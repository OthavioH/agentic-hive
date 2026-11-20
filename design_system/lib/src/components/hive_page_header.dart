import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// The header at the top of every page: title, optional subtitle and actions.
///
/// Keep at most one primary action among [actions].
class HivePageHeader extends StatelessWidget {
  /// Creates a page header.
  const new({
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    super.key,
  });

  /// Page title.
  final String title;

  /// Optional one-line description below the title.
  final String? subtitle;

  /// Actions aligned to the end, for example `HiveButton`s.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final description = subtitle;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.title.copyWith(color: colors.onSurface),
                  ),
                ),
                if (description != null) ...<Widget>[
                  SizedBox(height: spacing.spaceHalf),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.body.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final action in actions) ...<Widget>[
            SizedBox(width: spacing.space1),
            action,
          ],
        ],
      ),
    );
  }
}
