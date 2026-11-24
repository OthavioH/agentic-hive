import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Inset `surface2` panel used to group status sections inside a harness card.
class HarnessSectionPanel extends StatelessWidget {
  /// Creates a [HarnessSectionPanel].
  const new({required this.child, super.key});

  /// Section content displayed inside the inset panel.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
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
        padding: EdgeInsets.symmetric(
          horizontal: spacing.space2,
          vertical: spacing.space1,
        ),
        child: child,
      ),
    );
  }
}
