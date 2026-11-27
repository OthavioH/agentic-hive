import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// A single mono-spaced output line with an optional `stderr` gutter marker.
class HiveLogLineRow extends StatelessWidget {
  /// Creates a log line row.
  const new({
    required this.text,
    required this.isStderr,
    required this.stderrSemanticLabel,
    super.key,
  });

  /// The line text.
  final String text;

  /// Whether the line came from `stderr`.
  final bool isStderr;

  /// Localized semantics prefix announced before `stderr` lines.
  final String stderrSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: spacing.space2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Gutter: `space2` wide, with a `spaceHalf` danger bar for
            // stderr so the stream reads by shape, not only by color.
            SizedBox(
              width: spacing.space2,
              child: isStderr
                  ? Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: spacing.spaceHalf,
                        ),
                        child: SizedBox(
                          width: spacing.spaceHalf,
                          child: DecoratedBox(
                            key: const ValueKey<String>('stderr-marker'),
                            decoration: BoxDecoration(
                              color: colors.danger,
                              borderRadius: context.hiveRadii.pill,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                text,
                semanticsLabel: isStderr ? '$stderrSemanticLabel: $text' : null,
                style: context.hiveTypography.mono.copyWith(
                  color: isStderr ? colors.danger : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
