import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/components/hive_icon_button.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// Accessible labels and tooltips for [HiveTitleBar]'s caption buttons.
@immutable
final class HiveTitleBarLabels {
  /// Creates a [HiveTitleBarLabels].
  const new({
    required this.minimize,
    required this.maximize,
    required this.restore,
    required this.close,
  });

  /// Accessible label and tooltip for the minimize button.
  final String minimize;

  /// Accessible label and tooltip for the maximize button when restored.
  final String maximize;

  /// Accessible label and tooltip for the restore button when maximized.
  final String restore;

  /// Accessible label and tooltip for the close button.
  final String close;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveTitleBarLabels &&
          other.minimize == minimize &&
          other.maximize == maximize &&
          other.restore == restore &&
          other.close == close;

  @override
  int get hashCode => Object.hash(minimize, maximize, restore, close);
}

/// Custom desktop window title bar with a drag strip and right-aligned caption
/// buttons (minimize, maximize/restore, close).
///
/// Purely visual: it knows nothing about the windowing plugin and delegates all
/// window actions through callbacks.
class HiveTitleBar extends StatelessWidget {
  /// Creates a custom title bar.
  const new({
    required this.isMaximized,
    required this.labels,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
    this.showSystemMenuOnRelease = false,
    this.onDragStart,
    this.onSystemMenu,
    super.key,
  });

  /// Whether the window is currently maximized.
  final bool isMaximized;

  /// Accessible labels and tooltips for the caption buttons.
  final HiveTitleBarLabels labels;

  /// Whether [onSystemMenu] fires on secondary pointer release (`true`, as on
  /// Windows) or press (`false`).
  final bool showSystemMenuOnRelease;

  /// Called when the minimize button is pressed.
  final VoidCallback? onMinimize;

  /// Called when the maximize/restore button is pressed or the drag area is
  /// double-clicked.
  final VoidCallback? onToggleMaximize;

  /// Called when the close button is pressed.
  final VoidCallback? onClose;

  /// Called when the user begins dragging the empty strip.
  final VoidCallback? onDragStart;

  /// Called when the user secondary-clicks the empty strip, with the global
  /// pointer position.
  final ValueChanged<Offset>? onSystemMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final toggleLabel = isMaximized ? labels.restore : labels.maximize;
    final toggleIcon = isMaximized ? HiveIcons.restore : HiveIcons.maximize;

    return ColoredBox(
      color: colors.background,
      child: SizedBox(
        height: spacing.space5,
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space1),
          child: Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: onDragStart == null
                      ? null
                      : (_) => onDragStart!(),
                  onDoubleTap: onToggleMaximize,
                  onSecondaryTapDown:
                      onSystemMenu == null || showSystemMenuOnRelease
                      ? null
                      : (details) => onSystemMenu!(details.globalPosition),
                  onSecondaryTapUp:
                      onSystemMenu == null || !showSystemMenuOnRelease
                      ? null
                      : (details) => onSystemMenu!(details.globalPosition),
                  child: const SizedBox.expand(),
                ),
              ),
              _CaptionButton(
                icon: HiveIcons.minimize,
                label: labels.minimize,
                onPressed: onMinimize,
              ),
              SizedBox(width: spacing.spaceHalf),
              _CaptionButton(
                icon: toggleIcon,
                label: toggleLabel,
                onPressed: onToggleMaximize,
              ),
              SizedBox(width: spacing.spaceHalf),
              _CaptionButton(
                icon: HiveIcons.close,
                label: labels.close,
                dangerHover: true,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.dangerHover = false,
  });

  final HiveIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool dangerHover;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: dangerHover
          ? HiveIconButton.dangerHover(
              icon: icon,
              semanticLabel: label,
              size: HiveButtonSize.small,
              onPressed: onPressed,
            )
          : HiveIconButton(
              icon: icon,
              semanticLabel: label,
              size: HiveButtonSize.small,
              onPressed: onPressed,
            ),
    );
  }
}
