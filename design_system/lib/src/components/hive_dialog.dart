import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A modal panel with a title, an optional message and content, and a row
/// of `HiveButton` actions aligned to the end.
///
/// Drawn as a `surface2` panel with `radiusPanel`, a `borderSubtle`
/// hairline and the medium shadow token. Show it with [HiveDialog.show],
/// or use [HiveDialog.confirm] for the common cancel/confirm case.
class HiveDialog extends StatelessWidget {
  /// Creates a dialog.
  const new({
    required this.title,
    required this.actions,
    this.message,
    this.content,
    super.key,
  });

  /// Heading; also names the dialog route for screen readers.
  final String title;

  /// Short supporting text under the title.
  final String? message;

  /// Optional extra content (a form field, a list) under the message.
  final Widget? content;

  /// The buttons, least important first; the last one is the confirm.
  final List<Widget> actions;

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
  /// [destructive] styles the confirm button as `danger` (delete, discard);
  /// otherwise it is the `primary` action.
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
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          HiveButton(
            label: confirmLabel,
            variant: destructive
                ? HiveButtonVariant.danger
                : HiveButtonVariant.primary,
            autofocus: true,
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
    final text = message;
    final body = content;

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: typography.title.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      if (text != null) ...<Widget>[
                        SizedBox(height: spacing.space1),
                        Text(
                          text,
                          style: typography.body.copyWith(
                            color: colors.onSurfaceMuted,
                          ),
                        ),
                      ],
                      if (body != null) ...<Widget>[
                        SizedBox(height: spacing.space3),
                        Flexible(child: SingleChildScrollView(child: body)),
                      ],
                      SizedBox(height: spacing.space4),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: spacing.space1,
                        runSpacing: spacing.space1,
                        children: actions,
                      ),
                    ],
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
