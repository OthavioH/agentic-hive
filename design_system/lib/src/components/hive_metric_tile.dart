import 'package:design_system/src/components/hive_card.dart';
import 'package:design_system/src/foundation/hive_feedback_tone.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:design_system/src/tokens/hive_typography.dart';
import 'package:material_ui/material_ui.dart';

/// The size of a [HiveMetricTile].
enum HiveMetricTileSize {
  /// The one focal number of a screen: `number` (48/56) inside `space3`.
  focal(_number, _space3),

  /// Secondary metrics in a row or grid: `display` (32/40) inside `space2`.
  compact(_display, _space2);

  new(this.valueStyle, this._padding);

  /// The Bricolage Grotesque role used for the value.
  final TextStyle Function(HiveTypography typography) valueStyle;

  final double Function(BuildContext context) _padding;

  /// The inner padding of the tile.
  double padding(BuildContext context) => _padding(context);
}

TextStyle _number(HiveTypography t) => t.number;
TextStyle _display(HiveTypography t) => t.display;
double _space3(BuildContext context) => context.hiveSpacing.space3;
double _space2(BuildContext context) => context.hiveSpacing.space2;

/// A metric: a large display number above a short label.
///
/// Sits on a [HiveCardSurface] step with `radiusCard` and a hairline border.
/// The value uses Bricolage Grotesque (`number` for [HiveMetricTileSize.focal],
/// `display` for [HiveMetricTileSize.compact]) and the label uses Geist
/// `label`. Both stay in `onSurface` / `onSurfaceMuted`: light `success` and
/// `warning` miss 4.5:1 as text, so an optional [tone] colors only a leading
/// tone icon (shape plus color) beside the label, never the text.
///
/// The tile is one semantics node labelled `label: value` unless
/// [semanticLabel] is given; pass one that names the tone's meaning when it
/// matters (for example `Failed runs: 3, needs attention`).
class HiveMetricTile extends StatelessWidget {
  /// Creates a metric tile.
  const new({
    required this.value,
    required this.label,
    this.size = HiveMetricTileSize.compact,
    this.tone,
    this.surface = HiveCardSurface.surface1,
    this.semanticLabel,
    super.key,
  });

  /// The formatted value, for example `12`, `98%` or `4m 12s`.
  final String value;

  /// What the value counts, for example `Active runs`.
  final String label;

  /// Focal or compact.
  final HiveMetricTileSize size;

  /// Optional status accent shown as a tone icon before the label.
  final HiveFeedbackTone? tone;

  /// Surface step the tile sits on.
  final HiveCardSurface surface;

  /// Accessibility label; defaults to `label: value`.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final tone = this.tone;
    return Semantics(
      container: true,
      label: semanticLabel ?? '$label: $value',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface.color(colors),
            borderRadius: context.hiveRadii.card,
            border: Border.all(
              color: colors.borderSubtle,
              width: context.hiveElevation.hairline,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(size.padding(context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.spaceHalf,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: size
                        .valueStyle(typography)
                        .copyWith(color: colors.onSurface),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: spacing.spaceHalf,
                  children: <Widget>[
                    if (tone != null)
                      HiveIcon(
                        tone.icon,
                        size: spacing.space2,
                        color: tone.color(colors),
                      ),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: typography.label.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
