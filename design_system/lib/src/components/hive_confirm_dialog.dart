import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// What a [HiveConfirmDialog] asks the user to confirm.
enum HiveConfirmTone {
  /// A reversible or safe action: the confirm button is `primary` and takes
  /// the initial focus.
  standard(HiveButtonVariant.primary, autofocusConfirm: true),

  /// A destructive action (delete, overwrite): the confirm button is
  /// `danger` and the cancel button takes the initial focus.
  destructive(HiveButtonVariant.danger, autofocusConfirm: false);

  new(this.confirmVariant, {required this.autofocusConfirm});

  /// Variant of the confirm button.
  final HiveButtonVariant confirmVariant;

  /// Whether the confirm button (rather than cancel) gets initial focus.
  final bool autofocusConfirm;
}

/// The button a user chose in a [HiveConfirmDialog].
enum HiveConfirmChoice {
  /// The confirm button.
  confirm,

  /// The optional secondary button (for example "Reload from disk").
  secondary,

  /// The cancel button, Escape or a tap on the scrim.
  cancel,
}

/// A `radiusPanel` confirmation dialog: an optional icon, a title, a message,
/// optional [detail] and a cancel, optional secondary and confirm button.
///
/// Show it with [showHiveConfirmDialog]. Escape cancels; the dialog is a
/// named semantics route.
class HiveConfirmDialog extends StatelessWidget {
  /// Creates a confirmation dialog.
  const new({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
    this.tone = HiveConfirmTone.standard,
    this.icon,
    this.detail,
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  }) : assert(
         (secondaryLabel == null) == (onSecondary == null),
         'secondaryLabel and onSecondary go together.',
       );

  /// Short question, for example "Delete agent?".
  final String title;

  /// What happens if the user confirms.
  final String message;

  /// Confirm button label, for example "Delete".
  final String confirmLabel;

  /// Cancel button label.
  final String cancelLabel;

  /// Called by the confirm button.
  final VoidCallback onConfirm;

  /// Called by the cancel button and Escape.
  final VoidCallback onCancel;

  /// Standard or destructive.
  final HiveConfirmTone tone;

  /// Optional icon above the title.
  final HiveIconData? icon;

  /// Optional extra content under the message.
  final Widget? detail;

  /// Optional third action label, for example "Reload from disk".
  final String? secondaryLabel;

  /// Called by the secondary button.
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final leading = icon;
    final extra = detail;
    final secondary = secondaryLabel;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: FocusScope(
        autofocus: true,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.space8 * 7),
            child: Container(
              padding: EdgeInsets.all(spacing.space4),
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: context.hiveRadii.panel,
                border: Border.all(
                  color: colors.borderSubtle,
                  width: context.hiveElevation.hairline,
                ),
                boxShadow: context.hiveElevation.shadowMedium,
              ),
              child: DefaultTextStyle(
                style: typography.body.copyWith(
                  color: colors.onSurface,
                  decoration: TextDecoration.none,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (leading != null) ...<Widget>[
                              Container(
                                width: spacing.space6,
                                height: spacing.space6,
                                alignment: Alignment.center,
                                decoration: ShapeDecoration(
                                  color: tone == HiveConfirmTone.destructive
                                      ? colors.danger
                                      : colors.surface3,
                                  shape: const CircleBorder(),
                                ),
                                child: HiveIcon(
                                  leading,
                                  size: spacing.space3,
                                  color: tone == HiveConfirmTone.destructive
                                      ? colors.onDanger
                                      : colors.onSurface,
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
                            SizedBox(height: spacing.space1),
                            Text(
                              message,
                              style: typography.body.copyWith(
                                color: colors.onSurfaceMuted,
                              ),
                            ),
                            if (extra != null) ...<Widget>[
                              SizedBox(height: spacing.space2),
                              extra,
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.space4),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: spacing.space1,
                      runSpacing: spacing.space1,
                      children: <Widget>[
                        HiveButton(
                          label: cancelLabel,
                          variant: HiveButtonVariant.ghost,
                          autofocus: !tone.autofocusConfirm,
                          onPressed: onCancel,
                        ),
                        if (secondary != null)
                          HiveButton(
                            label: secondary,
                            variant: HiveButtonVariant.secondary,
                            onPressed: onSecondary,
                          ),
                        HiveButton(
                          label: confirmLabel,
                          variant: tone.confirmVariant,
                          autofocus: tone.autofocusConfirm,
                          onPressed: onConfirm,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a [HiveConfirmDialog] over a `background` scrim and completes with
/// the user's choice ([HiveConfirmChoice.cancel] on Escape or a scrim tap).
///
/// The entrance fades and scales with the motion tokens and respects
/// `MediaQuery.disableAnimations`.
Future<HiveConfirmChoice> showHiveConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  HiveConfirmTone tone = HiveConfirmTone.standard,
  HiveIconData? icon,
  Widget? detail,
  String? secondaryLabel,
}) async {
  final colors = context.hiveColors;
  final motion = context.hiveMotion;
  final choice = await showGeneralDialog<HiveConfirmChoice>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: colors.background.withValues(alpha: colors.scrimOpacity),
    transitionDuration: motion.resolve(context, motion.medium),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: motion.emphasizedCurve,
        reverseCurve: motion.exitCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      void close(HiveConfirmChoice value) =>
          Navigator.of(dialogContext).pop(value);
      return SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(dialogContext.hiveSpacing.space4),
            child: HiveConfirmDialog(
              title: title,
              message: message,
              confirmLabel: confirmLabel,
              cancelLabel: cancelLabel,
              tone: tone,
              icon: icon,
              detail: detail,
              secondaryLabel: secondaryLabel,
              onSecondary: secondaryLabel == null
                  ? null
                  : () => close(HiveConfirmChoice.secondary),
              onConfirm: () => close(HiveConfirmChoice.confirm),
              onCancel: () => close(HiveConfirmChoice.cancel),
            ),
          ),
        ),
      );
    },
  );
  return choice ?? HiveConfirmChoice.cancel;
}
