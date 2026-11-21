import 'dart:async';

import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/components/hive_icon_button.dart';
import 'package:design_system/src/foundation/hive_feedback_tone.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// Transient feedback that floats over the page (agent saved, agent changed
/// on disk). Show it with [showHiveToast]; the widget itself only draws.
///
/// A `radiusCard` `surface3` card with a tone-colored hairline, the small
/// `shadowMedium`, the tone icon, a message, an optional action and an
/// optional dismiss button. It is a live region, so screen readers announce
/// it when it appears.
class HiveToast extends StatelessWidget {
  /// Creates a toast.
  const new({
    required this.tone,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.dismissSemanticLabel,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction go together.',
       ),
       assert(
         onDismiss == null || dismissSemanticLabel != null,
         'A dismissible toast needs a dismissSemanticLabel.',
       );

  /// How long [showHiveToast] keeps a toast by default.
  static const Duration defaultDisplayDuration = Duration(seconds: 5);

  /// Color role pair and icon.
  final HiveFeedbackTone tone;

  /// The message.
  final String message;

  /// Optional action label, for example "Reload".
  final String? actionLabel;

  /// Called when the action is activated.
  final VoidCallback? onAction;

  /// Shows a dismiss button when set.
  final VoidCallback? onDismiss;

  /// Semantics label of the dismiss button.
  final String? dismissSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final label = actionLabel;
    final dismiss = onDismiss;
    final dismissLabel = dismissSemanticLabel;
    return Semantics(
      container: true,
      liveRegion: true,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: spacing.space8 * 7),
        child: Container(
          padding: EdgeInsets.all(spacing.space1),
          decoration: BoxDecoration(
            color: colors.surface3,
            borderRadius: context.hiveRadii.card,
            border: Border.all(
              color: tone.color(colors),
              width: context.hiveElevation.hairline,
            ),
            boxShadow: context.hiveElevation.shadowMedium,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HiveToneBadge(tone: tone, diameter: spacing.space4),
              SizedBox(width: spacing.space2),
              Flexible(
                child: Text(
                  message,
                  style: context.hiveTypography.body.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (label != null) ...<Widget>[
                SizedBox(width: spacing.space2),
                HiveButton(
                  label: label,
                  variant: HiveButtonVariant.secondary,
                  size: HiveButtonSize.small,
                  onPressed: onAction,
                ),
              ],
              SizedBox(width: spacing.space1),
              if (dismiss != null && dismissLabel != null)
                HiveIconButton(
                  icon: HiveIcons.close,
                  semanticLabel: dismissLabel,
                  size: HiveButtonSize.small,
                  onPressed: dismiss,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A shown toast; [dismiss] removes it early.
class HiveToastHandle {
  new _(this._remove);

  final VoidCallback _remove;
  bool _dismissed = false;

  /// Whether the toast is gone.
  bool get isDismissed => _dismissed;

  /// Removes the toast if it is still shown.
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _remove();
  }
}

HiveToastHandle? _current;

/// Shows a [HiveToast] at the bottom end of the root [Overlay].
///
/// One toast shows at a time; a new one replaces the previous. It leaves
/// after [duration] (pass null to keep it until dismissed). The entrance uses
/// the motion tokens and respects `MediaQuery.disableAnimations`. The action
/// and the dismiss button also remove the toast.
HiveToastHandle showHiveToast(
  BuildContext context, {
  required HiveFeedbackTone tone,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  String? dismissSemanticLabel,
  Duration? duration = HiveToast.defaultDisplayDuration,
}) {
  _current?.dismiss();
  final overlay = Overlay.of(context, rootOverlay: true);
  OverlayEntry? entry;
  Timer? timer;
  HiveToastHandle? handle;
  final created = HiveToastHandle._(() {
    timer?.cancel();
    entry?.remove();
    if (identical(_current, handle)) _current = null;
  });
  handle = created;
  final action = onAction;
  entry = OverlayEntry(
    builder: (context) {
      final spacing = context.hiveSpacing;
      return PositionedDirectional(
        end: spacing.space4,
        bottom: spacing.space4,
        child: _ToastEntrance(
          child: HiveToast(
            tone: tone,
            message: message,
            actionLabel: actionLabel,
            onAction: action == null
                ? null
                : () {
                    created.dismiss();
                    action();
                  },
            onDismiss: dismissSemanticLabel == null ? null : created.dismiss,
            dismissSemanticLabel: dismissSemanticLabel,
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  _current = created;
  if (duration != null) timer = Timer(duration, created.dismiss);
  return created;
}

class _ToastEntrance extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_ToastEntrance> createState() => _ToastEntranceState();
}

class _ToastEntranceState extends State<_ToastEntrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.hiveMotion;
    final duration = motion.resolve(context, motion.medium);
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: duration,
      curve: motion.emphasizedCurve,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, 0.25),
        duration: duration,
        curve: motion.emphasizedCurve,
        child: widget.child,
      ),
    );
  }
}
