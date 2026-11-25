import 'package:design_system/src/tokens/hive_spacing.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// Padding presets for a [HiveInsetPanel].
enum HiveInsetPadding {
  /// `space1` on all sides (for compact icon tiles).
  tight(_tight),

  /// `space2` horizontal, `space1` vertical (default section row).
  compact(_compact),

  /// `space2` on all sides (guidance and explanation panels).
  comfortable(_comfortable);

  new(this.resolve);

  /// Resolves this preset into [EdgeInsets] from [HiveSpacing].
  final EdgeInsets Function(HiveSpacing spacing) resolve;
}

EdgeInsets _tight(HiveSpacing s) => EdgeInsets.all(s.space1);
EdgeInsets _compact(HiveSpacing s) =>
    EdgeInsets.symmetric(horizontal: s.space2, vertical: s.space1);
EdgeInsets _comfortable(HiveSpacing s) => EdgeInsets.all(s.space2);

/// A non-interactive `surface2` grouping panel with a `borderSubtle` hairline
/// and `radiusCard`, used for inset sections inside cards.
///
/// Adds no semantics node of its own.
class HiveInsetPanel extends StatelessWidget {
  /// Creates an inset panel.
  const new({
    required this.child,
    this.padding = HiveInsetPadding.compact,
    super.key,
  });

  /// Panel content.
  final Widget child;

  /// Padding preset.
  final HiveInsetPadding padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: context.hiveRadii.card,
        border: Border.all(
          color: colors.borderSubtle,
          width: context.hiveElevation.hairline,
        ),
      ),
      child: Padding(
        padding: padding.resolve(context.hiveSpacing),
        child: child,
      ),
    );
  }
}
