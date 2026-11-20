import 'package:design_system/src/foundation/hive_spinner.dart';
import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:design_system/src/visuals/hive_status.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the glyph of a [HiveConnectionState].
typedef HiveConnectionGlyph = Widget Function(Color color, double size);

/// The backend connection as shown by [HiveConnectionIndicator].
///
/// Each state has its own glyph (shape) and color role.
enum HiveConnectionState {
  /// Connected: filled circle in `success`.
  connected(_success, _disc),

  /// Connecting: rotating arc in `warning` (still when animations are off).
  connecting(_warning, _spinner),

  /// Disconnected: diamond in `danger`.
  disconnected(_danger, _diamond);

  new(this.color, this.glyph);

  /// Color role of the glyph.
  final HiveColorRole color;

  /// The glyph builder.
  final HiveConnectionGlyph glyph;
}

Color _success(HiveColors c) => c.success;
Color _warning(HiveColors c) => c.warning;
Color _danger(HiveColors c) => c.danger;

Widget _shape(HiveStatusShape shape, Color color, double size) {
  return SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: HiveStatusShapePainter(shape: shape, color: color),
    ),
  );
}

Widget _disc(Color color, double size) =>
    _shape(const HiveDiscShape(), color, size);

Widget _diamond(Color color, double size) =>
    _shape(const HiveDiamondShape(), color, size);

Widget _spinner(Color color, double size) =>
    HiveSpinner(size: size, color: color);

/// A pill showing the backend connection state and a short label.
///
/// Announced as a live region, so screen readers hear state changes.
class HiveConnectionIndicator extends StatelessWidget {
  /// Creates an indicator.
  const new({required this.state, required this.label, super.key});

  /// Current connection state.
  final HiveConnectionState state;

  /// Localized state label, for example "Connecting to backend".
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: context.hiveRadii.pill,
            border: Border.all(
              color: colors.borderSubtle,
              width: context.hiveElevation.hairline,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.space2,
              vertical: spacing.space1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                state.glyph(state.color(colors), spacing.space1 * 1.5),
                SizedBox(width: spacing.space1),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.hiveTypography.label.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
