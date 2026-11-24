import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/components/hive_icon_button.dart';
import 'package:design_system/src/foundation/hive_feedback_tone.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_spacing.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:design_system/src/tokens/hive_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Spacing and text density of a [HiveBanner].
enum HiveBannerDensity {
  /// Full-size banner for page-level feedback.
  regular(
    padding: _regularPadding,
    badgeDiameter: _space4,
    titleMinHeight: _space4,
    messageStyle: _bodyStyle,
  ),

  /// Tighter banner for inline card sections.
  compact(
    padding: _compactPadding,
    badgeDiameter: _space3,
    titleMinHeight: _space3,
    messageStyle: _bodySmallStyle,
  );

  new({
    required this.padding,
    required this.badgeDiameter,
    required this.titleMinHeight,
    required this.messageStyle,
  });

  /// Outer container padding.
  final EdgeInsets Function(HiveSpacing spacing) padding;

  /// Leading [HiveToneBadge] diameter.
  final double Function(HiveSpacing spacing) badgeDiameter;

  /// Minimum height of the title row, matching the badge diameter.
  final double Function(HiveSpacing spacing) titleMinHeight;

  /// Text style of the optional message.
  final TextStyle Function(HiveTypography typography) messageStyle;
}

EdgeInsets _regularPadding(HiveSpacing s) => EdgeInsets.all(s.space2);
EdgeInsets _compactPadding(HiveSpacing s) => EdgeInsets.all(s.space1);
double _space4(HiveSpacing s) => s.space4;
double _space3(HiveSpacing s) => s.space3;
TextStyle _bodyStyle(HiveTypography t) => t.body;
TextStyle _bodySmallStyle(HiveTypography t) => t.bodySmall;

/// Inline feedback inside a page or pane: an external change, a parse error
/// with its details, a save confirmation that should stay visible.
///
/// A `radiusCard` `surface2` container with a tone-colored hairline, the
/// tone icon badge, a title, an optional message, an optional [detail]
/// (for example the raw parse error in `mono`), optional [actions] and an
/// optional dismiss button. Use [HiveBannerDensity.compact] for inline
/// feedback inside cards.
class HiveBanner extends StatelessWidget {
  /// Creates a banner.
  const new({
    required this.tone,
    required this.title,
    this.density = HiveBannerDensity.regular,
    this.message,
    this.detail,
    this.actions = const <Widget>[],
    this.onDismiss,
    this.dismissSemanticLabel,
    this.liveRegion = false,
    super.key,
  }) : assert(
         onDismiss == null || dismissSemanticLabel != null,
         'A dismissible banner needs a dismissSemanticLabel.',
       );

  /// Color role pair and icon.
  final HiveFeedbackTone tone;

  /// Spacing and text density.
  final HiveBannerDensity density;

  /// One-line summary.
  final String title;

  /// Optional explanation.
  final String? message;

  /// Optional extra content under the message, for example error details.
  final Widget? detail;

  /// Optional actions, usually small `HiveButton`s.
  final List<Widget> actions;

  /// Shows a dismiss button when set.
  final VoidCallback? onDismiss;

  /// Semantics label of the dismiss button.
  final String? dismissSemanticLabel;

  /// Whether screen readers announce the banner when it appears or changes.
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final body = message;
    final extra = detail;
    final dismiss = onDismiss;
    final badgeDiameter = density.badgeDiameter(spacing);
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      explicitChildNodes: true,
      child: Container(
        padding: density.padding(spacing),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: context.hiveRadii.card,
          border: Border.all(
            color: tone.color(colors),
            width: context.hiveElevation.hairline,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            HiveToneBadge(tone: tone, diameter: badgeDiameter),
            SizedBox(width: spacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: density.titleMinHeight(spacing),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        title,
                        style: typography.labelLarge.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (body != null)
                    Text(
                      body,
                      style: density
                          .messageStyle(typography)
                          .copyWith(color: colors.onSurfaceMuted),
                    ),
                  if (extra != null) ...<Widget>[
                    SizedBox(height: spacing.space1),
                    extra,
                  ],
                  if (actions.isNotEmpty) ...<Widget>[
                    SizedBox(height: spacing.space2),
                    Wrap(
                      spacing: spacing.space1,
                      runSpacing: spacing.space1,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
            if (dismiss != null) ...<Widget>[
              SizedBox(width: spacing.space1),
              HiveIconButton(
                icon: HiveIcons.close,
                semanticLabel: dismissSemanticLabel!,
                size: HiveButtonSize.small,
                onPressed: dismiss,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
