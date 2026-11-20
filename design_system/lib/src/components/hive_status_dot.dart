import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:design_system/src/visuals/hive_status.dart';
import 'package:material_ui/material_ui.dart';

/// A node status glyph: a distinct shape plus a color per status, so status
/// never depends on color alone.
class HiveStatusDot extends StatelessWidget {
  /// Creates a status glyph for [status].
  const new({
    required this.status,
    required this.semanticLabel,
    this.size,
    super.key,
  });

  /// The status to show.
  final HiveNodeStatus status;

  /// Localized status name announced by screen readers.
  final String semanticLabel;

  /// Logical size; defaults to `space2`.
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size ?? context.hiveSpacing.space2,
        child: CustomPaint(
          painter: HiveStatusShapePainter(
            shape: status.shape,
            color: status.color(context.hiveColors),
          ),
        ),
      ),
    );
  }
}
