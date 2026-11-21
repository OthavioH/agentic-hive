import 'package:design_system/src/foundation/hive_text_input.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:material_ui/material_ui.dart';

/// A single-line pill input with hover, keyboard focus, error and disabled
/// states.
///
/// Give it a visible [label], or a [semanticLabel] when the context already
/// names it (a search input with a search icon).
class HiveTextField extends StatelessWidget {
  /// Creates a single-line input.
  const new({
    this.label,
    this.semanticLabel,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.errorText,
    this.leadingIcon,
    this.trailing,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.statesController,
    super.key,
  }) : assert(
         label != null || semanticLabel != null,
         'HiveTextField needs a visible label or a semanticLabel.',
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

  /// Optional leading icon, for example `HiveIcons.search`.
  final HiveIconData? leadingIcon;

  /// Optional trailing widget, for example a clear `HiveIconButton`.
  final Widget? trailing;

  /// Whether the input accepts focus and edits.
  final bool enabled;

  /// Whether the text is selectable but not editable.
  final bool readOnly;

  /// Whether to request focus when first built.
  final bool autofocus;

  /// Whether to hide the text.
  final bool obscureText;

  /// The keyboard action button.
  final TextInputAction? textInputAction;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the user presses Enter.
  final ValueChanged<String>? onSubmitted;

  /// Optional external states (hovered, focused) for static previews.
  final WidgetStatesController? statesController;

  @override
  Widget build(BuildContext context) {
    return HiveTextInput(
      kind: const HiveSingleLineInput(),
      label: label,
      semanticLabel: semanticLabel,
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      leadingIcon: leadingIcon,
      trailing: trailing,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      statesController: statesController,
    );
  }
}
