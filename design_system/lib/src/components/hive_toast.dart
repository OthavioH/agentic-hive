import 'dart:async';

import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// The color pair and default icon of a [HiveToast].
enum HiveToastTone {
  /// `surface3` with `onSurface` and a hairline; no default icon.
  neutral(_surface3, _onSurface, _borderSubtle, null),

  /// `success` with `onSuccess`; a check icon.
  success(_success, _onSuccess, null, HiveIcons.check),

  /// `warning` with `onWarning`; an alert icon.
  warning(_warning, _onWarning, null, HiveIcons.alert),

  /// `danger` with `onDanger`; an alert icon.
  danger(_danger, _onDanger, null, HiveIcons.alert),

  /// `info` with `onInfo`; an information icon.
  info(_info, _onInfo, null, HiveIcons.info);

  new(this.background, this.foreground, this.border, this.icon);

  /// Background role.
  final HiveColorRole background;

  /// Message and icon role.
  final HiveColorRole foreground;

  /// Hairline border role, or null for none.
  final HiveColorRole? border;

  /// Icon shown when the toast does not set one, or null for none.
  final HiveIconData? icon;
}

Color _surface3(HiveColors c) => c.surface3;
Color _onSurface(HiveColors c) => c.onSurface;
Color _borderSubtle(HiveColors c) => c.borderSubtle;
Color _success(HiveColors c) => c.success;
Color _onSuccess(HiveColors c) => c.onSuccess;
Color _warning(HiveColors c) => c.warning;
Color _onWarning(HiveColors c) => c.onWarning;
Color _danger(HiveColors c) => c.danger;
Color _onDanger(HiveColors c) => c.onDanger;
Color _info(HiveColors c) => c.info;
Color _onInfo(HiveColors c) => c.onInfo;

/// A brief, non-blocking confirmation such as "Path copied".
///
/// Show one with [HiveToast.show]: it slides in at the bottom center of the
/// root overlay, stays for [HiveToast.displayDuration] (paused while the
/// pointer is over it) and fades out. A new toast replaces the visible one.
/// Screen readers announce the message through a live region.
///
/// The widget itself is the static pill, for previews and custom hosts.
class HiveToast extends StatelessWidget {
  /// Creates the toast pill.
  const new({
    required this.message,
    this.tone = HiveToastTone.neutral,
    this.icon,
    super.key,
  });

  /// How long a shown toast stays before it leaves: four seconds.
  static const Duration displayDuration = Duration(seconds: 4);

  /// The visible message, also announced to screen readers.
  final String message;

  /// Color pair and default icon.
  final HiveToastTone tone;

  /// Leading icon; defaults to the [tone]'s icon.
  final HiveIconData? icon;

  /// Shows a toast with [message] in the root overlay of [context] and
  /// replaces any toast already visible there.
  ///
  /// Returns a handle that dismisses the toast early.
  static HiveToastHandle show(
    BuildContext context, {
    required String message,
    HiveToastTone tone = HiveToastTone.neutral,
    HiveIconData? icon,
    Duration duration = displayDuration,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    _visible[overlay]?._removeNow();
    final handle = HiveToastHandle._(overlay);
    _visible[overlay] = handle;
    handle._entry = OverlayEntry(
      builder: (context) => themes.wrap(
        _HiveToastHost(
          key: handle._hostKey,
          duration: duration,
          onGone: handle._removeNow,
          child: HiveToast(message: message, tone: tone, icon: icon),
        ),
      ),
    );
    overlay.insert(handle._entry!);
    return handle;
  }

  static final Expando<HiveToastHandle> _visible = Expando<HiveToastHandle>(
    'HiveToast visible toast',
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final elevation = context.hiveElevation;
    final foreground = tone.foreground(colors);
    final borderRole = tone.border;
    final leading = icon ?? tone.icon;
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spacing.space8 * 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tone.background(colors),
              borderRadius: context.hiveRadii.pill,
              border: borderRole == null
                  ? null
                  : Border.all(
                      color: borderRole(colors),
                      width: elevation.hairline,
                    ),
              boxShadow: elevation.shadowSmall,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.space3,
                vertical: spacing.space1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    HiveIcon(leading, size: spacing.space2, color: foreground),
                    SizedBox(width: spacing.space1),
                  ],
                  Flexible(
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.hiveTypography.body.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A toast shown by [HiveToast.show].
class HiveToastHandle {
  new _(this._overlay);

  final OverlayState _overlay;
  final GlobalKey<_HiveToastHostState> _hostKey =
      GlobalKey<_HiveToastHostState>();
  OverlayEntry? _entry;

  /// Whether the toast is still in the overlay.
  bool get isVisible => _entry != null;

  /// Plays the exit motion and removes the toast. Does nothing once gone.
  void dismiss() {
    final host = _hostKey.currentState;
    if (host == null) {
      _removeNow();
    } else {
      host.leave();
    }
  }

  void _removeNow() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    if (identical(HiveToast._visible[_overlay], this)) {
      HiveToast._visible[_overlay] = null;
    }
    entry
      ..remove()
      ..dispose();
  }
}

/// Positions, animates and times one toast.
class _HiveToastHost extends StatefulWidget {
  const new({
    required this.duration,
    required this.onGone,
    required this.child,
    super.key,
  });

  final Duration duration;
  final VoidCallback onGone;
  final Widget child;

  @override
  State<_HiveToastHost> createState() => _HiveToastHostState();
}

class _HiveToastHostState extends State<_HiveToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  CurvedAnimation? _curved;
  Timer? _timer;
  bool _leaving = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.hiveMotion;
    _controller
      ..duration = motion.resolve(context, motion.medium)
      ..reverseDuration = motion.resolve(context, motion.short);
    _curved?.dispose();
    _curved = CurvedAnimation(
      parent: _controller,
      curve: motion.emphasizedCurve,
      reverseCurve: motion.exitCurve,
    );
    if (!_started) {
      _started = true;
      _controller.forward();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curved?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.duration, leave);
  }

  void _pauseTimer() => _timer?.cancel();

  void leave() {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    unawaited(
      _controller.reverse().whenComplete(() {
        if (mounted) widget.onGone();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final curved = _curved!;
    return DefaultTextStyle(
      style: typography.body.copyWith(
        color: colors.onSurface,
        decoration: TextDecoration.none,
      ),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.all(spacing.space4),
            child: MouseRegion(
              onEnter: (_) => _pauseTimer(),
              onExit: (_) {
                if (!_leaving) _startTimer();
              },
              child: AnimatedBuilder(
                animation: curved,
                builder: (context, child) => Opacity(
                  opacity: curved.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, spacing.space2 * (1 - curved.value)),
                    child: child,
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
