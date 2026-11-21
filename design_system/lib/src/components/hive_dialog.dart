import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A modal panel that asks the user to confirm or choose: a title, an
/// optional message or custom content, and a row of actions.
///
/// The panel is `surface2` with a `radiusPanel` (32) shape and a hairline
/// `borderSubtle` border. Actions are usually `HiveButton`s, with the safe
/// choice (for example "Cancel") first and the confirming action last. Give
/// the safe action `autofocus: true` so keyboard users land on it.
///
/// Show it with [showHiveDialog]; it can also be placed inline (Widgetbook,
/// tests).
class HiveDialog extends StatelessWidget {
  /// Creates a dialog.
  const new({
    required this.title,
    required this.actions,
    this.message,
    this.content,
    this.icon,
    super.key,
  });

  /// Short headline, also the accessibility name of the dialog.
  final String title;

  /// Optional explanation below the title.
  final String? message;

  /// Optional custom content below the message.
  final Widget? content;

  /// Optional icon shown in a circle above the title.
  final HiveIconData? icon;

  /// The actions, laid out at the end of the panel in order.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final elevation = context.hiveElevation;
    final glyph = icon;
    final body = message;
    final extra = content;

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
            child: FocusTraversalGroup(
              child: DecoratedBox(
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
/// The dialog fades in with the `medium` motion token (instantly when the
/// platform asks for no animation). When [barrierDismissible] is true, a
/// click on the scrim or the Escape key closes it with a null result.
/// [barrierLabel] names the scrim for screen readers, for example "Dismiss".
Future<T?> showHiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required String barrierLabel,
  bool barrierDismissible = true,
}) {
  final colors = context.hiveColors;
  final motion = context.hiveMotion;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: colors.background.withValues(alpha: colors.scrimOpacity),
    transitionDuration: motion.resolve(context, motion.medium),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        builder(dialogContext),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: motion.emphasizedCurve,
          reverseCurve: motion.exitCurve,
        ),
        child: child,
      );
    },
  );
}
