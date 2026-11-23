import 'package:design_system/src/foundation/hive_text_input.dart';
import 'package:material_ui/material_ui.dart';

/// A multi-line rounded (`radiusCard`) input with hover, keyboard focus,
/// error and disabled states.
///
/// Set [mono] for Markdown, code or prompts so the text uses the Geist Mono
/// `mono` role. Set [expands] to fill the parent's height (an editor pane).
class HiveTextArea extends StatelessWidget {
  /// Creates a multi-line input.
  const new({
    this.label,
    this.semanticLabel,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.errorText,
    this.mono = false,
    this.minLines = 4,
    this.maxLines,
    this.expands = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.onChanged,
    this.statesController,
    super.key,
  }) : assert(
         label != null || semanticLabel != null,
         'HiveTextArea needs a visible label or a semanticLabel.',
       );

  /// Visible label above the input; also the semantics label.
  final String? label;

  /// Semantics label when there is no visible [label].
  final String? semanticLabel;

  /// Text controller; one is created when null.
  final TextEditingController? controller;

  /// Focus node; one is created when null.
  final FocusNode? focusNode;

  /// Placeholder shown while empty.
  final String? hintText;

  /// Help text below the input, hidden while [errorText] is set.
  final String? helperText;

  /// Error message below the input; non-null puts it in error state.
  final String? errorText;

  /// Whether the text uses the `mono` role instead of `body`.
  final bool mono;

  /// Minimum visible lines; ignored when [expands].
  final int minLines;

  /// Maximum visible lines before scrolling, or null to grow without limit;
  /// ignored when [expands].
  final int? maxLines;

  /// Whether the input fills its parent's height.
  final bool expands;

  /// Whether the input accepts focus and edits.
  final bool enabled;

  /// Whether the text is selectable but not editable.
  final bool readOnly;

  /// Whether to request focus when first built.
  final bool autofocus;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Optional external states (hovered, focused) for static previews.
  final WidgetStatesController? statesController;

  @override
  Widget build(BuildContext context) {
    return HiveTextInput(
      kind: HiveMultiLineInput(
        mono: mono,
        minLines: minLines,
        maxLines: maxLines,
        expands: expands,
      ),
      label: label,
      semanticLabel: semanticLabel,
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      textInputAction: TextInputAction.newline,
      onChanged: onChanged,
      statesController: statesController,
    );
  }
}
