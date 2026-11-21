import 'package:design_system/src/foundation/hive_field_frame.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// The shared frame of the list editors (`HiveKeyValueEditor`,
/// `HiveStringListField`).
///
/// Draws the optional group label, the rows (or [emptyText] when there are
/// none) spaced by `space1`, the add button and the helper or error line.
/// The group is one semantics container announced with [label].
class HiveListFieldFrame extends StatelessWidget {
  /// Creates a list field frame.
  const new({
    required this.rows,
    required this.addButton,
    required this.enabled,
    this.label,
    this.helperText,
    this.errorText,
    this.emptyText,
    super.key,
  });

  /// One widget per item.
  final List<Widget> rows;

  /// The button that appends an item.
  final Widget addButton;

  /// Whether the editor accepts input; dims the texts when false.
  final bool enabled;

  /// Visible group label above the rows.
  final String? label;

  /// Supporting text below the editor; hidden while [errorText] is set.
  final String? helperText;

  /// Error text below the editor.
  final String? errorText;

  /// Text shown in place of the rows while the list is empty.
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final groupLabel = label;
    final empty = emptyText;
    final helper = errorText ?? helperText;
    final textOpacity = enabled ? 1.0 : colors.disabledOpacity;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: groupLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (groupLabel != null) ...<Widget>[
            ExcludeSemantics(
              child: Opacity(
                opacity: textOpacity,
                child: Text(
                  groupLabel,
                  style: typography.label.copyWith(color: colors.onSurface),
                ),
              ),
            ),
            SizedBox(height: spacing.space1),
          ],
          if (rows.isEmpty && empty != null) ...<Widget>[
            Opacity(
              opacity: textOpacity,
              child: Text(
                empty,
                style: typography.body.copyWith(color: colors.onSurfaceMuted),
              ),
            ),
            SizedBox(height: spacing.space1),
          ],
          for (final row in rows) ...<Widget>[
            row,
            SizedBox(height: spacing.space1),
          ],
          Align(alignment: AlignmentDirectional.centerStart, child: addButton),
          if (helper != null) ...<Widget>[
            SizedBox(height: spacing.space1),
            Opacity(
              opacity: textOpacity,
              child: HiveFieldMessage(text: helper, isError: errorText != null),
            ),
          ],
        ],
      ),
    );
  }
}
