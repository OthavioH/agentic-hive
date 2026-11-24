import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// An on/off toggle with an optional visible [label] to its right.
///
/// The pill track is `accent` with an `onAccent` thumb when on, and
/// `surface3` with a hairline and an `onSurfaceMuted` thumb when off, so the
/// state reads from the thumb position and contrast, not hue alone. It has
/// a hover layer and focus ring, toggles on tap, Enter and Space, animates
/// the thumb with the motion tokens and is announced as a toggle. A null
/// [onChanged] disables it.
class HiveSwitch extends StatelessWidget {
  /// Creates a switch. Give a visible [label], a [semanticLabel], or both.
  const new({
    required this.value,
    required this.onChanged,
    this.label,
    this.helperText,
    this.semanticLabel,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : assert(
         label != null || semanticLabel != null,
         'A switch needs a label or a semanticLabel.',
       ),
       assert(
         helperText == null || label != null,
         'A switch with helperText needs a visible label.',
       );

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value; null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Optional visible text next to the track; tapping it toggles too.
  final String? label;

  /// Optional muted helper text below [label], aligned to its start edge.
  final String? helperText;

  /// Accessibility label; defaults to [label].
  final String? semanticLabel;

  /// Optional external states controller (hover, focus, pressed).
  final WidgetStatesController? statesController;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Whether to request focus when first built.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final typography = context.hiveTypography;
    final onChanged = this.onChanged;
    final text = label;
    final helper = helperText;
    final duration = motion.resolve(context, motion.short);
    final trackColor = value ? colors.accent : colors.surface3;
    final thumbColor = value ? colors.onAccent : colors.onSurfaceMuted;

    final interaction = HiveInteraction(
      semanticLabel: semanticLabel ?? text!,
      toggled: value,
      onPressed: onChanged == null ? null : () => onChanged(!value),
      statesController: statesController,
      focusNode: focusNode,
      autofocus: autofocus,
      builder: (context, states) {
        final track = HiveFocusRing(
          focused: states.contains(WidgetState.focused),
          shape: const StadiumBorder(),
          child: AnimatedContainer(
            duration: duration,
            curve: motion.standardCurve,
            width: spacing.space6,
            height: spacing.space3,
            padding: EdgeInsets.all(spacing.spaceHalf),
            decoration: ShapeDecoration(
              color: hiveStateLayer(
                base: trackColor,
                foreground: thumbColor,
                states: states,
                colors: colors,
              ),
              shape: StadiumBorder(
                side: BorderSide(
                  color: value ? trackColor : colors.borderSubtle,
                  width: context.hiveElevation.hairline,
                ),
              ),
            ),
            child: AnimatedAlign(
              duration: duration,
              curve: motion.emphasizedCurve,
              alignment: value
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: AnimatedContainer(
                duration: duration,
                curve: motion.standardCurve,
                width: spacing.space2,
                height: spacing.space2,
                decoration: ShapeDecoration(
                  color: thumbColor,
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ),
        );

        return Opacity(
          opacity: states.contains(WidgetState.disabled)
              ? colors.disabledOpacity
              : 1,
          child: text == null
              ? track
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    track,
                    SizedBox(width: spacing.space1),
                    Flexible(
                      child: Text(
                        text,
                        style: typography.body.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );

    if (helper == null) return interaction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        interaction,
        Opacity(
          opacity: onChanged == null ? colors.disabledOpacity : 1,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: spacing.space6 + spacing.space1,
              top: spacing.spaceHalf,
            ),
            child: Text(
              helper,
              style: typography.bodySmall.copyWith(
                color: colors.onSurfaceMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
