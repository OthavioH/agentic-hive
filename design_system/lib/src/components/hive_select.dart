import 'package:design_system/src/foundation/hive_field_frame.dart';
import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// One choice of a [HiveSelect].
@immutable
class HiveSelectOption<T> {
  /// Creates an option showing [label] for [value].
  const new({required this.value, required this.label, this.icon});

  /// The value reported to `onChanged`.
  final T value;

  /// Visible text.
  final String label;

  /// Optional leading icon.
  final HiveIconData? icon;
}

/// A labelled dropdown that picks one of [options].
///
/// The trigger is a pill field (`surface3`, hairline, hover layer, focus
/// ring) that shows the chosen option or the [hint]. The menu is a
/// `radiusCard` `surface2` panel of pill items; the chosen one carries a
/// check. Enter, Space and arrow keys open and move through the menu,
/// Escape closes it. A null [onChanged] disables the select.
class HiveSelect<T> extends StatefulWidget {
  /// Creates a select.
  const new({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Visible label above the field.
  final String label;

  /// The choices, in display order.
  final List<HiveSelectOption<T>> options;

  /// The chosen value, or null when nothing is chosen yet.
  final T? value;

  /// Called with the picked value; null disables the select.
  final ValueChanged<T>? onChanged;

  /// Placeholder shown while [value] matches no option.
  final String? hint;

  /// Supporting text below the field; hidden while [errorText] is set.
  final String? helperText;

  /// Error message below the field; also turns the hairline `danger`.
  final String? errorText;

  /// Accessibility label; defaults to [label].
  final String? semanticLabel;

  /// Optional external states controller (hover, focus), for previews.
  final WidgetStatesController? statesController;

  /// Optional focus node of the trigger.
  final FocusNode? focusNode;

  /// Whether to request focus when first built.
  final bool autofocus;

  @override
  State<HiveSelect<T>> createState() => _HiveSelectState<T>();
}

class _HiveSelectState<T> extends State<HiveSelect<T>> {
  final MenuController _menu = MenuController();
  final List<FocusNode> _itemFocusNodes = <FocusNode>[];
  HiveSelectOption<T>? get _selected {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _syncItemFocusNodes();
  }

  @override
  void didUpdateWidget(HiveSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncItemFocusNodes();
    if (widget.onChanged == null && _menu.isOpen) _menu.close();
  }

  @override
  void dispose() {
    for (final node in _itemFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncItemFocusNodes() {
    while (_itemFocusNodes.length < widget.options.length) {
      _itemFocusNodes.add(FocusNode());
    }
    while (_itemFocusNodes.length > widget.options.length) {
      _itemFocusNodes.removeLast().dispose();
    }
  }

  void _toggle() {
    if (_menu.isOpen) {
      _menu.close();
      return;
    }
    _menu.open();
    final index = widget.options.indexWhere((o) => o.value == widget.value);
    final target = index < 0 ? 0 : index;
    if (target >= _itemFocusNodes.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _menu.isOpen) _itemFocusNodes[target].requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final motion = context.hiveMotion;
    final elevation = context.hiveElevation;
    final onChanged = widget.onChanged;
    final selected = _selected;
    final hint = widget.hint;

    return LayoutBuilder(
      builder: (context, constraints) {
        final menuStyle = MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(colors.surface2),
          surfaceTintColor: WidgetStatePropertyAll<Color>(colors.surface2),
          shadowColor: WidgetStatePropertyAll<Color>(
            colors.background.withValues(alpha: 0),
          ),
          elevation: const WidgetStatePropertyAll<double>(0),
          padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.all(spacing.spaceHalf),
          ),
          minimumSize: WidgetStatePropertyAll<Size>(
            Size(constraints.hasBoundedWidth ? constraints.maxWidth : 0, 0),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: context.hiveRadii.card,
              side: BorderSide(
                color: colors.borderSubtle,
                width: elevation.hairline,
              ),
            ),
          ),
        );

        final itemStyle = ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            return hiveStateLayer(
              base: colors.surface2,
              foreground: colors.onSurface,
              states: states.contains(WidgetState.focused)
                  ? <WidgetState>{...states, WidgetState.hovered}
                  : states,
              colors: colors,
            );
          }),
          foregroundColor: WidgetStatePropertyAll<Color>(colors.onSurface),
          iconColor: WidgetStatePropertyAll<Color>(colors.onSurface),
          overlayColor: WidgetStatePropertyAll<Color>(
            colors.background.withValues(alpha: 0),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle>(typography.body),
          minimumSize: WidgetStatePropertyAll<Size>(Size(0, spacing.space5)),
          padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: spacing.space2),
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
          side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
            if (!states.contains(WidgetState.focused)) return null;
            return BorderSide(
              color: colors.focusRing,
              width: elevation.focusRingWidth,
            );
          }),
          mouseCursor: const WidgetStatePropertyAll<MouseCursor>(
            SystemMouseCursors.click,
          ),
        );

        return MenuAnchor(
          controller: _menu,
          style: menuStyle,
          alignmentOffset: Offset(0, spacing.spaceHalf),
          menuChildren: <Widget>[
            for (var i = 0; i < widget.options.length; i++)
              _item(widget.options[i], i, itemStyle, spacing.space2),
          ],
          builder: (context, menu, child) {
            return HiveInteraction(
              semanticLabel: widget.semanticLabel ?? widget.label,
              semanticValue: selected?.label ?? hint,
              semanticHint: widget.errorText ?? widget.helperText,
              onPressed: onChanged == null ? null : _toggle,
              statesController: widget.statesController,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              builder: (context, states) {
                return HiveFieldFrame(
                  label: widget.label,
                  states: states,
                  shape: const StadiumBorder(),
                  padding: EdgeInsets.symmetric(horizontal: spacing.space2),
                  helperText: widget.helperText,
                  errorText: widget.errorText,
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: <Widget>[
                      if (selected?.icon case final icon?) ...<Widget>[
                        HiveIcon(
                          icon,
                          size: spacing.space2,
                          color: colors.onSurface,
                        ),
                        SizedBox(width: spacing.space1),
                      ],
                      Expanded(
                        child: Text(
                          selected?.label ?? hint ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.body.copyWith(
                            color: selected == null
                                ? colors.onSurfaceMuted
                                : colors.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.space1),
                      AnimatedRotation(
                        turns: menu.isOpen ? 0.5 : 0,
                        duration: motion.resolve(context, motion.short),
                        curve: motion.standardCurve,
                        child: HiveIcon(
                          HiveIcons.chevronDown,
                          size: spacing.space2,
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _item(
    HiveSelectOption<T> option,
    int index,
    ButtonStyle style,
    double iconSize,
  ) {
    final onChanged = widget.onChanged;
    final chosen = option.value == widget.value;
    final icon = option.icon;
    return MenuItemButton(
      focusNode: _itemFocusNodes[index],
      style: style,
      onPressed: onChanged == null ? null : () => onChanged(option.value),
      leadingIcon: icon == null ? null : HiveIcon(icon, size: iconSize),
      trailingIcon: chosen
          ? HiveIcon(HiveIcons.check, size: iconSize)
          : SizedBox(width: iconSize),
      child: Semantics(selected: chosen, child: Text(option.label)),
    );
  }
}
