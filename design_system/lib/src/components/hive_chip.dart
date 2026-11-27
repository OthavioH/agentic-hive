import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/foundation/hive_tooltip.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A pill chip (height `space4`, `label` text).
///
/// Three variants:
/// - [HiveChip.removable]: a value in a chip editor (tags, tool names) with a
///   trailing `×` that removes it.
/// - [HiveChip.filter]: a toggle in a filter row (tag filters); selected
///   chips use the inverse `onSurface` fill and a check icon, so selection
///   is shown by shape and color.
/// - [HiveChip.readOnly]: a non-interactive chip with no remove button and no
///   selection; `removed: true` mutes it.
abstract class HiveChip extends StatelessWidget {
  /// Creates a chip. Use [HiveChip.removable], [HiveChip.filter], or
  /// [HiveChip.readOnly].
  const new({required this.label, super.key});

  /// A chip with a remove button. A null [onRemoved] hides the button.
  const factory removable({
    required String label,
    required String removeSemanticLabel,
    required VoidCallback? onRemoved,
    HiveIconData? icon,
    WidgetStatesController? removeStatesController,
    Key? key,
  }) = HiveRemovableChip;

  /// A selectable filter chip. A null [onSelected] disables it.
  const factory filter({
    required String label,
    required bool selected,
    required ValueChanged<bool>? onSelected,
    String? semanticLabel,
    WidgetStatesController? statesController,
    FocusNode? focusNode,
    Key? key,
  }) = HiveChipFilter;

  /// A read-only chip: no remove button, no selection. [removed] mutes it.
  const factory readOnly({
    required String label,
    bool removed,
    HiveIconData? icon,
    String? semanticLabel,
    Key? key,
  }) = HiveReadOnlyChip;

  /// Visible text.
  final String label;
}

/// The removable variant of [HiveChip].
class HiveRemovableChip extends HiveChip {
  /// Creates a removable chip.
  const new({
    required super.label,
    required this.removeSemanticLabel,
    required this.onRemoved,
    this.icon,
    this.removeStatesController,
    super.key,
  });

  /// Semantics label of the remove button, for example "Remove tag review".
  final String removeSemanticLabel;

  /// Called when the remove button is activated; null hides it.
  final VoidCallback? onRemoved;

  /// Optional leading icon.
  final HiveIconData? icon;

  /// Optional external states of the remove button for static previews.
  final WidgetStatesController? removeStatesController;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final remove = onRemoved;
    final leading = icon;
    return HiveTooltip(
      message: label,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: label,
        child: _ChipFrame(
          background: colors.surface3,
          border: colors.borderSubtle,
          padding: EdgeInsetsDirectional.only(
            start: spacing.space2,
            end: remove == null ? spacing.space2 : spacing.spaceHalf,
          ),
          children: <Widget>[
            if (leading != null) ...<Widget>[
              HiveIcon(leading, size: spacing.space2, color: colors.onSurface),
              SizedBox(width: spacing.spaceHalf),
            ],
            Flexible(
              child: ExcludeSemantics(
                child: _ChipLabel(label: label, color: colors.onSurface),
              ),
            ),
            if (remove != null) ...<Widget>[
              SizedBox(width: spacing.spaceHalf),
              _RemoveButton(
                semanticLabel: removeSemanticLabel,
                onPressed: remove,
                statesController: removeStatesController,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The filter (toggle) variant of [HiveChip].
class HiveChipFilter extends HiveChip {
  /// Creates a filter chip.
  const new({
    required super.label,
    required this.selected,
    required this.onSelected,
    this.semanticLabel,
    this.statesController,
    this.focusNode,
    super.key,
  });

  /// Whether the filter is on.
  final bool selected;

  /// Called with the new selection; null disables the chip.
  final ValueChanged<bool>? onSelected;

  /// Accessibility label; defaults to [label].
  final String? semanticLabel;

  /// Optional external states controller (hover, focus, pressed).
  final WidgetStatesController? statesController;

  /// Optional focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final select = onSelected;
    final foreground = selected ? colors.background : colors.onSurface;
    return HiveInteraction(
      semanticLabel: semanticLabel ?? label,
      selected: selected,
      onPressed: select == null ? null : () => select(!selected),
      statesController: statesController,
      focusNode: focusNode,
      builder: (context, states) => Opacity(
        opacity: states.contains(WidgetState.disabled)
            ? colors.disabledOpacity
            : 1,
        child: HiveFocusRing(
          focused: states.contains(WidgetState.focused),
          shape: const StadiumBorder(),
          child: _ChipFrame(
            background: hiveStateLayer(
              base: selected ? colors.onSurface : colors.surface3,
              foreground: foreground,
              states: states,
              colors: colors,
            ),
            border: selected ? colors.onSurface : colors.borderSubtle,
            padding: EdgeInsets.symmetric(horizontal: spacing.space2),
            children: <Widget>[
              if (selected) ...<Widget>[
                HiveIcon(
                  HiveIcons.check,
                  size: spacing.space2,
                  color: foreground,
                ),
                SizedBox(width: spacing.spaceHalf),
              ],
              Flexible(
                child: _ChipLabel(label: label, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The read-only variant of [HiveChip].
class HiveReadOnlyChip extends HiveChip {
  /// Creates a read-only chip.
  ///
  /// When [removed] is true, consumers should pass a descriptive
  /// [semanticLabel] (for example `"shot.png, removed"`) so the removed state
  /// is not conveyed by color alone.
  const new({
    required super.label,
    this.removed = false,
    this.icon,
    this.semanticLabel,
    super.key,
  });

  /// Whether the chip shows the muted removed appearance.
  final bool removed;

  /// Optional leading icon.
  final HiveIconData? icon;

  /// Accessibility label; defaults to [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final foreground = removed ? colors.onSurfaceMuted : colors.onSurface;
    final leading = icon;
    return HiveTooltip(
      message: label,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: semanticLabel ?? label,
        child: _ChipFrame(
          background: colors.surface3,
          border: colors.borderSubtle,
          padding: EdgeInsets.symmetric(horizontal: spacing.space2),
          children: <Widget>[
            if (leading != null) ...<Widget>[
              HiveIcon(leading, size: spacing.space2, color: foreground),
              SizedBox(width: spacing.spaceHalf),
            ],
            Flexible(
              child: ExcludeSemantics(
                child: _ChipLabel(label: label, color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipFrame extends StatelessWidget {
  const new({
    required this.background,
    required this.border,
    required this.padding,
    required this.children,
  });

  final Color background;
  final Color border;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final motion = context.hiveMotion;
    return AnimatedContainer(
      duration: motion.resolve(context, motion.short),
      curve: motion.standardCurve,
      height: context.hiveSpacing.space4,
      padding: padding,
      decoration: ShapeDecoration(
        color: background,
        shape: StadiumBorder(
          side: BorderSide(
            color: border,
            width: context.hiveElevation.hairline,
          ),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const new({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.hiveTypography.label.copyWith(color: color),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const new({
    required this.semanticLabel,
    required this.onPressed,
    required this.statesController,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final WidgetStatesController? statesController;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final diameter = spacing.space3;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.backspace): onPressed,
        const SingleActivator(LogicalKeyboardKey.delete): onPressed,
      },
      child: HiveInteraction(
        semanticLabel: semanticLabel,
        onPressed: onPressed,
        statesController: statesController,
        builder: (context, states) => HiveFocusRing(
          focused: states.contains(WidgetState.focused),
          shape: const CircleBorder(),
          child: Container(
            width: diameter,
            height: diameter,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: hiveStateLayer(
                base: colors.surface3,
                foreground: colors.onSurface,
                states: states,
                colors: colors,
              ),
            ),
            child: HiveIcon(
              HiveIcons.close,
              size: spacing.space2,
              color: colors.onSurfaceMuted,
            ),
          ),
        ),
      ),
    );
  }
}
