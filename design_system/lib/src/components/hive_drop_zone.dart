import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A visual-only drop-target highlight overlay toggled by [active].
///
/// The consumer owns drag-and-drop handling (for example, a platform drop
/// target in the frontend) and passes [active] to show or hide the overlay.
/// While [active], the overlay announces [caption] as a live region and
/// never intercepts pointer events.
class HiveDropZone extends StatelessWidget {
  /// Creates a drop-target highlight overlay around [child].
  const new({
    required this.child,
    required this.active,
    required this.caption,
    this.borderRadius,
    super.key,
  });

  /// Content beneath the drop-target overlay.
  final Widget child;

  /// Whether the drop-target highlight is visible.
  final bool active;

  /// Label shown in the overlay and announced as a live region when [active].
  final String caption;

  /// Corner radius of the overlay; defaults to `context.hiveRadii.panel`.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final elevation = context.hiveElevation;
    final motion = context.hiveMotion;
    final radius = borderRadius ?? context.hiveRadii.panel;

    return Stack(
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              excluding: !active,
              child: AnimatedOpacity(
                opacity: active ? 1.0 : 0.0,
                duration: motion.resolve(context, motion.short),
                curve: motion.standardCurve,
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: caption,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.background.withValues(
                        alpha: colors.scrimOpacity,
                      ),
                      borderRadius: radius,
                      border: Border.all(
                        color: colors.focusRing,
                        width: elevation.focusRingWidth,
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(spacing.space3),
                        child: ExcludeSemantics(
                          child: Text(
                            caption,
                            textAlign: TextAlign.center,
                            style: typography.titleSmall.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
