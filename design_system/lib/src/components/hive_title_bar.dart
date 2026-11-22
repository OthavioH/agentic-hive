import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/components/hive_icon_button.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Custom desktop window title bar with a drag strip and right-aligned caption
/// buttons (minimize, maximize/restore, close).
///
/// Purely visual: it knows nothing about the windowing plugin and delegates all
/// window actions through callbacks.
class HiveTitleBar extends StatelessWidget {
  /// Creates a custom title bar.
  const new({
    required this.isMaximized,
    required this.minimizeLabel,
    required this.maximizeLabel,
    required this.restoreLabel,
    required this.closeLabel,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
    this.onDragStart,
    this.onSystemMenu,
    super.key,
  });

  /// Whether the window is currently maximized.
  final bool isMaximized;

  /// Accessible label and tooltip for the minimize button.
  final String minimizeLabel;

  /// Accessible label and tooltip for the maximize button when restored.
  final String maximizeLabel;

  /// Accessible label and tooltip for the restore button when maximized.
  final String restoreLabel;

  /// Accessible label and tooltip for the close button.
  final String closeLabel;

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
    final toggleLabel = isMaximized ? restoreLabel : maximizeLabel;
    final toggleIcon = isMaximized ? HiveIcons.restore : HiveIcons.maximize;
    final menuOnRelease = defaultTargetPlatform == TargetPlatform.windows;

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
                  onSecondaryTapDown: onSystemMenu == null || menuOnRelease
                      ? null
                      : (details) => onSystemMenu!(details.globalPosition),
                  onSecondaryTapUp: onSystemMenu == null || !menuOnRelease
                      ? null
                      : (details) => onSystemMenu!(details.globalPosition),
                  child: const SizedBox.expand(),
                ),
              ),
              Tooltip(
                message: minimizeLabel,
                excludeFromSemantics: true,
                child: HiveIconButton(
                  icon: HiveIcons.minimize,
                  semanticLabel: minimizeLabel,
                  size: HiveButtonSize.small,
                  onPressed: onMinimize,
                ),
              ),
              SizedBox(width: spacing.spaceHalf),
              Tooltip(
                message: toggleLabel,
                excludeFromSemantics: true,
                child: HiveIconButton(
                  icon: toggleIcon,
                  semanticLabel: toggleLabel,
                  size: HiveButtonSize.small,
                  onPressed: onToggleMaximize,
                ),
              ),
              SizedBox(width: spacing.spaceHalf),
              Tooltip(
                message: closeLabel,
                excludeFromSemantics: true,
                child: HiveIconButton.dangerHover(
                  icon: HiveIcons.close,
                  semanticLabel: closeLabel,
                  size: HiveButtonSize.small,
                  onPressed: onClose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
