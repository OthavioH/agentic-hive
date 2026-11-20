// The Flux Motion trial (ADR 0018) is isolated to this file. To leave the
// trial, replace these internals with Flutter animations; the public widgets
// keep their API, so features do not change.
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter_flux_motion/flutter_flux_motion.dart';
import 'package:material_ui/material_ui.dart';

/// Fades [child] in on mount with the `medium` duration and `standard` curve.
///
/// Renders [child] directly when `MediaQuery.disableAnimations` is set.
class HiveFadeIn extends StatelessWidget {
  /// Creates a fade-in entrance.
  const new({required this.child, super.key});

  /// The content to reveal.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final motion = context.hiveMotion;
    return FluxFade(
      spec: FadeSpec(duration: motion.medium, curve: motion.standardCurve),
      child: child,
    );
  }
}

/// Slides [child] up by `space2` while fading it in, with the `medium`
/// duration and `emphasized` curve.
///
/// Renders [child] directly when `MediaQuery.disableAnimations` is set.
class HiveSlideIn extends StatelessWidget {
  /// Creates a slide-in entrance.
  const new({required this.child, super.key});

  /// The content to reveal.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final motion = context.hiveMotion;
    return FluxFade(
      spec: FadeSpec(duration: motion.medium, curve: motion.standardCurve),
      child: FluxSlide(
        spec: SlideSpec(
          begin: Offset(0, context.hiveSpacing.space2),
          duration: motion.medium,
          curve: motion.emphasizedCurve,
        ),
        child: child,
      ),
    );
  }
}

/// Reveals [children] one after another in a column.
///
/// Each child enters over `medium` with the `emphasized` curve, `short / 2`
/// after the previous one, rising by `space2`. Renders a plain [Column]
/// when `MediaQuery.disableAnimations` is set.
class HiveStagger extends StatelessWidget {
  /// Creates a staggered entrance.
  const new({required this.children, super.key});

  /// The widgets to reveal in order.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Column(mainAxisSize: MainAxisSize.min, children: children);
    }
    final motion = context.hiveMotion;
    return FluxStagger(
      spec: StaggerSpec(
        interval: motion.short ~/ 2,
        itemDuration: motion.medium,
        curve: motion.emphasizedCurve,
        beginOffset: Offset(0, context.hiveSpacing.space2),
      ),
      children: children,
    );
  }
}

/// Page transitions built from the motion tokens.
abstract final class HiveMotion {
  /// A [Navigator] route that fades through to [builder]'s page over the
  /// `long` duration.
  ///
  /// Flux Motion already renders the page without motion when
  /// `MediaQuery.disableAnimations` is set.
  static Route<T> route<T>(BuildContext context, WidgetBuilder builder) {
    final motion = context.hiveMotion;
    return FluxPageRoute<T>(
      builder: builder,
      spec: FluxPageRouteSpec.fadeThrough(
        duration: motion.long,
        reverseDuration: motion.medium,
        curve: motion.emphasizedCurve,
        reverseCurve: motion.exitCurve,
      ),
    );
  }
}

/// The page transition for router pages that take a transitions builder
/// (for example go_router's `CustomTransitionPage`).
///
/// Uses the same Flux Motion fade-through as [HiveMotion.route], and returns
/// [child] unchanged when `MediaQuery.disableAnimations` is set.
class HivePageTransition extends StatelessWidget {
  /// Wraps [child] in the page transition driven by [animation].
  const new({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    super.key,
  });

  /// The route's primary animation.
  final Animation<double> animation;

  /// The route's secondary animation (a page pushed on top).
  final Animation<double> secondaryAnimation;

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final motion = context.hiveMotion;
    // FluxPageRoute only exposes its transition through the route's public
    // transitionsBuilder, so build one route per token set and reuse that
    // builder for every frame.
    final builder = _builders[motion] ??= (HiveMotion.route<void>(
      context,
      _emptyPage,
    ) as PageRouteBuilder<void>).transitionsBuilder;
    return builder(context, animation, secondaryAnimation, child);
  }

  static final Expando<RouteTransitionsBuilder> _builders =
      Expando<RouteTransitionsBuilder>('HivePageTransition builders');

  static Widget _emptyPage(BuildContext context) => const SizedBox.shrink();
}
