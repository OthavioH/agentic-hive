import 'package:design_system/src/components/hive_status_dot.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_spacing.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:design_system/src/visuals/hive_status.dart';
import 'package:design_system/src/visuals/node_visual.dart';
import 'package:material_ui/material_ui.dart';

/// Diameter of a [HiveAgentAvatar], as a spacing token.
enum HiveAvatarSize {
  /// `space5` (40).
  small(_space5),

  /// `space6` (48).
  medium(_space6),

  /// `space8` (64).
  large(_space8);

  new(this.diameter);

  /// The diameter.
  final double Function(HiveSpacing spacing) diameter;
}

double _space5(HiveSpacing s) => s.space5;
double _space6(HiveSpacing s) => s.space6;
double _space8(HiveSpacing s) => s.space8;

/// An agent's face: its [NodeVisual] icon in a circle, with an optional
/// status glyph on the lower-right edge.
class HiveAgentAvatar extends StatelessWidget {
  /// Creates an avatar.
  const new({
    required this.visual,
    required this.semanticLabel,
    this.status,
    this.statusLabel,
    this.size = HiveAvatarSize.medium,
    super.key,
  }) : assert(
         status == null || statusLabel != null,
         'A status needs a statusLabel for screen readers.',
       );

  /// The node visual (harness logo, robot or kind icon).
  final NodeVisual visual;

  /// Accessibility label, for example the agent or node name.
  final String semanticLabel;

  /// Optional status shown on the edge.
  final HiveNodeStatus? status;

  /// Localized status name; required when [status] is set.
  final String? statusLabel;

  /// Diameter.
  final HiveAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final diameter = size.diameter(spacing);
    final current = status;
    final dotSize = diameter * 0.3;
    final accent = visual.accent;

    return Semantics(
      label: statusLabel == null
          ? semanticLabel
          : '$semanticLabel, $statusLabel',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: diameter,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.borderSubtle,
                      width: context.hiveElevation.hairline,
                    ),
                  ),
                  child: Center(
                    child: HiveIcon(
                      visual.icon,
                      size: diameter / 2,
                      color: accent == null ? colors.onSurface : accent(colors),
                    ),
                  ),
                ),
              ),
              if (current != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(spacing.spaceHalf / 2),
                      child: HiveStatusDot(
                        status: current,
                        semanticLabel: statusLabel ?? '',
                        size: dotSize,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
