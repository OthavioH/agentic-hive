import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/components/hive_drop_zone.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A modal panel that asks the user to confirm or choose: a title, an
/// optional icon, message or custom content, and a row of actions.
///
/// Drawn as a `surface2` panel with `radiusPanel`, a `borderSubtle`
/// hairline and the medium shadow token. Show it with [HiveDialog.show] or
/// [showHiveDialog], or use [HiveDialog.confirm] for the common
/// cancel/confirm case. It can also be placed inline (Widgetbook, tests).
class HiveDialog extends StatelessWidget {
  /// Creates a dialog.
  const new({
    required this.title,
    required this.actions,
    this.message,
    this.content,
    this.icon,
    this.dropActive = false,
    this.dropCaption,
    super.key,
  }) : assert(
         !dropActive || dropCaption != null,
         'dropCaption must be provided when dropActive is true.',
       );

  /// Short headline; also names the dialog route for screen readers.
  final String title;

  /// Optional supporting text below the title.
  final String? message;

  /// Optional custom content (a form field, a list) below the message.
  final Widget? content;

  /// Optional icon shown in a circle above the title.
  final HiveIconData? icon;

  /// The actions, laid out at the end of the panel in order.
  final List<Widget> actions;

  /// Whether the dialog panel shows the drop-target highlight overlay.
  final bool dropActive;

  /// Caption for the drop-target overlay; when non-null, the panel is wrapped
  /// in a [HiveDropZone].
  final String? dropCaption;

  /// Shows the dialog built by [builder] over a `background` scrim.
  ///
  /// The scrim fades in over the `medium` duration with the `emphasized`
  /// curve (no motion when `MediaQuery.disableAnimations` is set). Escape and
  /// a scrim tap dismiss it with null when [barrierDismissible];
  /// [barrierLabel] names the scrim for screen readers.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    required String barrierLabel,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
  }) {
    final colors = context.hiveColors;
    final motion = context.hiveMotion;
    final spacing = context.hiveSpacing;
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: colors.background.withValues(alpha: colors.scrimOpacity),
      transitionDuration: motion.resolve(context, motion.medium),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return themes.wrap(SafeArea(child: Builder(builder: builder)));
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: motion.emphasizedCurve,
          reverseCurve: motion.exitCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: AnimatedBuilder(
            animation: curved,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, (1 - curved.value) * spacing.space2),
              child: child,
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// Shows a cancel/confirm dialog and completes with true only when the
  /// user confirms; cancel, Escape and a scrim tap complete with false.
  ///
  /// [destructive] styles the confirm button as `danger` (delete, discard) and
  /// gives Cancel the initial focus so Enter does not destroy; otherwise
  /// Confirm is the `primary` action and takes the initial focus.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String confirmLabel,
    required String cancelLabel,
    String? message,
    bool destructive = false,
  }) async {
    final result = await show<bool>(
      context: context,
      barrierLabel: cancelLabel,
      builder: (dialogContext) => HiveDialog(
        title: title,
        message: message,
        actions: <Widget>[
          HiveButton(
            label: cancelLabel,
            variant: HiveButtonVariant.secondary,
            autofocus: destructive,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          HiveButton(
            label: confirmLabel,
            variant: destructive
                ? HiveButtonVariant.danger
                : HiveButtonVariant.primary,
            autofocus: !destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final elevation = context.hiveElevation;
    final glyph = icon;
    final body = message;
    final extra = content;
    final caption = dropCaption;

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: context.hiveRadii.panel,
        border: Border.all(
          color: colors.borderSubtle,
          width: elevation.hairline,
        ),
        boxShadow: elevation.shadowMedium,
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.space4),
        child: DefaultTextStyle(
          style: typography.body.copyWith(color: colors.onSurface),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (glyph != null) ...<Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface3,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.borderSubtle,
                        width: elevation.hairline,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(spacing.space1),
                      child: HiveIcon(
                        glyph,
                        size: spacing.space3,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacing.space2),
              ],
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: typography.titleSmall.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (body != null || extra != null)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (body != null) ...<Widget>[
                          SizedBox(height: spacing.space1),
                          Text(
                            body,
                            style: typography.body.copyWith(
                              color: colors.onSurfaceMuted,
                            ),
                          ),
                        ],
                        if (extra != null) ...<Widget>[
                          SizedBox(height: spacing.space2),
                          extra,
                        ],
                      ],
                    ),
                  ),
                ),
              if (actions.isNotEmpty) ...<Widget>[
                SizedBox(height: spacing.space4),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: spacing.space1,
                  overflowSpacing: spacing.space1,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.space4),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: spacing.space8 * 8),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: title,
            child: Material(
              type: MaterialType.transparency,
              child: FocusTraversalGroup(
                child: caption == null
                    ? panel
                    : HiveDropZone(
                        active: dropActive,
                        caption: caption,
                        borderRadius: context.hiveRadii.panel,
                        child: panel,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a [HiveDialog] (or any widget from [builder]) as a modal route over
/// a `background` scrim at `scrimOpacity`.
///
/// Delegates to [HiveDialog.show].
Future<T?> showHiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required String barrierLabel,
  bool barrierDismissible = true,
}) => HiveDialog.show<T>(
  context: context,
  builder: builder,
  barrierLabel: barrierLabel,
  barrierDismissible: barrierDismissible,
);
