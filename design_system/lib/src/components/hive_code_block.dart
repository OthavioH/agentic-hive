import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/components/hive_icon_button.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A scrollable, selectable monospace block for structured payloads (event
/// log entries, checkpoint state).
///
/// It sits on `surface1` with a hairline border and `radiusCard`. Text uses
/// the `mono` role, never wraps, and scrolls both ways; set [maxHeight] to
/// cap its height. Pass [copyLabel] to show a copy button in the header.
class HiveCodeBlock extends StatefulWidget {
  /// Creates a code block showing [code].
  const new({
    required this.code,
    this.title,
    this.maxHeight,
    this.copyLabel,
    this.onCopied,
    this.emptyLabel,
    super.key,
  }) : assert(maxHeight == null || maxHeight > 0, 'maxHeight must be > 0.');

  /// The text to show verbatim (usually pretty-printed JSON).
  final String code;

  /// Optional header label, such as `payload` or `state.json`.
  final String? title;

  /// Maximum height of the scrolling body; null lets it grow with [code].
  final double? maxHeight;

  /// Localized label of the copy button; null hides the button.
  final String? copyLabel;

  /// Called after [code] was written to the clipboard.
  final VoidCallback? onCopied;

  /// Muted text shown instead of an empty [code], such as `No payload`.
  final String? emptyLabel;

  @override
  State<HiveCodeBlock> createState() => _HiveCodeBlockState();
}

class _HiveCodeBlockState extends State<HiveCodeBlock> {
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    widget.onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final hairline = context.hiveElevation.hairline;
    final title = widget.title;
    final copyLabel = widget.copyLabel;
    final emptyLabel = widget.emptyLabel;
    final showHeader = title != null || copyLabel != null;

    final Widget text;
    if (widget.code.isEmpty && emptyLabel != null) {
      text = Text(
        emptyLabel,
        style: typography.mono.copyWith(color: colors.onSurfaceMuted),
      );
    } else {
      text = SelectableText(
        widget.code,
        style: typography.mono.copyWith(color: colors.onSurface),
      );
    }

    final body = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.maxHeight ?? double.infinity,
      ),
      child: Scrollbar(
        controller: _vertical,
        child: SingleChildScrollView(
          controller: _vertical,
          child: Scrollbar(
            controller: _horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.all(spacing.space2),
              child: text,
            ),
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: context.hiveRadii.card,
        border: Border.all(color: colors.borderSubtle, width: hairline),
      ),
      child: ClipRRect(
        borderRadius: context.hiveRadii.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showHeader) ...<Widget>[
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing.space2,
                  end: spacing.space1,
                  top: spacing.space1,
                  bottom: spacing.space1,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: spacing.space4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: title == null
                            ? const SizedBox.shrink()
                            : Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.label.copyWith(
                                  color: colors.onSurfaceMuted,
                                ),
                              ),
                      ),
                      if (copyLabel != null)
                        HiveIconButton(
                          icon: HiveIcons.copy,
                          semanticLabel: copyLabel,
                          size: HiveButtonSize.small,
                          onPressed: _copy,
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: hairline,
                child: ColoredBox(color: colors.borderSubtle),
              ),
            ],
            body,
          ],
        ),
      ),
    );
  }
}
