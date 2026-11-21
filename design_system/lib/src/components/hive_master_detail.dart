import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A desktop two-pane layout: a fixed-width [master] list and a flexible
/// [detail] pane, in one `radiusPanel` `surface1` container split by a
/// `borderSubtle` hairline.
///
/// When the width cannot fit [masterWidth] plus [minDetailWidth], only one
/// pane shows: [detail] when [detailVisible], otherwise [master]. Needs a
/// bounded width and height (place it in an `Expanded` page body).
class HiveMasterDetail extends StatelessWidget {
  /// Creates a master-detail layout.
  const new({
    required this.master,
    required this.detail,
    this.masterWidth,
    this.minDetailWidth,
    this.detailVisible = false,
    super.key,
  });

  /// The list pane (search, filters, items).
  final Widget master;

  /// The detail pane (editor or empty state).
  final Widget detail;

  /// Width of the master pane; defaults to `space8 * 5` (320).
  final double? masterWidth;

  /// Narrowest detail pane before collapsing to one pane; defaults to
  /// `space8 * 6` (384).
  final double? minDetailWidth;

  /// Which pane shows when collapsed to one: the detail when true.
  final bool detailVisible;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final radius = context.hiveRadii.panel;
    final hairline = context.hiveElevation.hairline;
    final listWidth = masterWidth ?? spacing.space8 * 5;
    final detailMin = minDetailWidth ?? spacing.space8 * 6;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: radius,
        border: Border.all(color: colors.borderSubtle, width: hairline),
      ),
      child: Padding(
        padding: EdgeInsets.all(hairline),
        child: ClipRRect(
          borderRadius: radius,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final split =
                  constraints.maxWidth >= listWidth + hairline + detailMin;
              if (!split) {
                return detailVisible ? detail : master;
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(width: listWidth, child: master),
                  SizedBox(
                    width: hairline,
                    child: ColoredBox(color: colors.borderSubtle),
                  ),
                  Expanded(child: detail),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
