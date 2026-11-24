import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// Which surface step a [HiveCard] sits on.
enum HiveCardSurface {
  /// `surface1`: cards on the page background.
  surface1(_surface1),

  /// `surface2`: cards nested inside a `surface1` container.
  surface2(_surface2);

  new(this.color);

  /// The surface color role.
  final HiveColorRole color;
}

Color _surface1(HiveColors c) => c.surface1;
Color _surface2(HiveColors c) => c.surface2;

/// A rounded (`radiusCard`) surface with a hairline border.
///
/// Pass [onPressed] and [semanticLabel] to make the whole card interactive;
/// it then gains hover, pressed and keyboard focus states.
///
/// Pass [busy] and [semanticLabel] (and optionally [statusLabel]) when the
/// card represents an in-progress operation: the card becomes inert and
/// announces [statusLabel] as a live-region value.
class HiveCard extends StatelessWidget {
  /// Creates a card.
  const new({
    required this.child,
    this.surface = HiveCardSurface.surface1,
    this.onPressed,
    this.semanticLabel,
    this.statesController,
    this.focusNode,
    this.busy = false,
    this.statusLabel,
    super.key,
  }) : assert(
         onPressed == null || semanticLabel != null,
         'Interactive cards need a semanticLabel.',
       ),
       assert(
         !busy || semanticLabel != null,
         'Busy cards need a semanticLabel.',
       ),
       assert(
         statusLabel == null || busy,
         'statusLabel describes a busy card.',
       );

  /// The content. Padding is `space3`.
  final Widget child;

  /// Surface step.
  final HiveCardSurface surface;

  /// Makes the card interactive.
  final VoidCallback? onPressed;

  /// Accessibility label; required when [onPressed] is set.
  final String? semanticLabel;

  /// Optional external states controller (hover, focus, pressed).
  final WidgetStatesController? statesController;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Whether the card is busy (for example a row being deleted). A busy card
  /// is inert: it ignores [onPressed], takes no focus and draws like a static
  /// card. Requires [semanticLabel].
  final bool busy;

  /// What the busy card is doing, announced as the live-region value of the
  /// card's semantics node (for example "Deleting…"). Only valid while [busy].
  /// The card draws nothing for it; the consumer shows any visible status.
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      final status = statusLabel;
      return Semantics(
        container: true,
        explicitChildNodes: true,
        label: semanticLabel,
        value: status,
        liveRegion: status != null,
        child: _decorated(context, const <WidgetState>{}),
      );
    }
    final label = semanticLabel;
    if (onPressed == null || label == null) {
      final card = _decorated(context, const <WidgetState>{});
      return label == null ? card : Semantics(label: label, child: card);
    }
    return HiveInteraction(
      semanticLabel: label,
      onPressed: onPressed,
      statesController: statesController,
      focusNode: focusNode,
      builder: (context, states) => HiveFocusRing(
        focused: states.contains(WidgetState.focused),
        shape: RoundedRectangleBorder(borderRadius: context.hiveRadii.card),
        child: _decorated(context, states),
      ),
    );
  }

  Widget _decorated(BuildContext context, Set<WidgetState> states) {
    final colors = context.hiveColors;
    final motion = context.hiveMotion;
    return AnimatedContainer(
      duration: motion.resolve(context, motion.short),
      curve: motion.standardCurve,
      padding: EdgeInsets.all(context.hiveSpacing.space3),
      decoration: BoxDecoration(
        color: hiveStateLayer(
          base: surface.color(colors),
          foreground: colors.onSurface,
          states: states,
          colors: colors,
        ),
        borderRadius: context.hiveRadii.card,
        border: Border.all(
          color: colors.borderSubtle,
          width: context.hiveElevation.hairline,
        ),
      ),
      child: child,
    );
  }
}
