import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// A scrollable showcase page with a title and sections.
class ShowcasePage extends StatelessWidget {
  /// Creates a page.
  const new({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  /// Page title.
  final String title;

  /// Optional description.
  final String? subtitle;

  /// Sections.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          HivePageHeader(title: title, subtitle: subtitle),
          for (final child in children) ...<Widget>[
            child,
            SizedBox(height: spacing.space4),
          ],
        ],
      ),
    );
  }
}

/// A titled group of examples laid out in a wrap.
class ShowcaseSection extends StatelessWidget {
  /// Creates a section.
  const new({
    required this.title,
    required this.children,
    this.description,
    super.key,
  });

  /// Section title.
  final String title;

  /// Optional description below the title.
  final String? description;

  /// Examples.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final text = description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: typography.titleSmall.copyWith(color: colors.onSurface),
        ),
        if (text != null) ...<Widget>[
          SizedBox(height: spacing.spaceHalf),
          Text(
            text,
            style: typography.bodySmall.copyWith(color: colors.onSurfaceMuted),
          ),
        ],
        SizedBox(height: spacing.space2),
        Wrap(
          spacing: spacing.space3,
          runSpacing: spacing.space3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ],
    );
  }
}

/// An example with a caption underneath.
class Labeled extends StatelessWidget {
  /// Creates a captioned example.
  const new({required this.label, required this.child, super.key});

  /// Caption.
  final String label;

  /// The example.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        child,
        SizedBox(height: context.hiveSpacing.space1),
        Text(
          label,
          style: context.hiveTypography.mono.copyWith(
            color: colors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}

/// Centers a single use case on the canvas with page padding.
class UseCaseFrame extends StatelessWidget {
  /// Creates a frame around [child].
  const new({required this.child, super.key});

  /// The use case content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.hiveSpacing.space4),
        child: child,
      ),
    );
  }
}

/// Builds a component with a [WidgetStatesController] seeded with [states],
/// so a hover, focus or pressed state can be reviewed without a pointer.
class StatesPreview extends StatefulWidget {
  /// Creates a preview with fixed [states].
  const new({required this.states, required this.builder, super.key});

  /// The states to show.
  final Set<WidgetState> states;

  /// Builds the component with the seeded controller.
  final Widget Function(WidgetStatesController controller) builder;

  @override
  State<StatesPreview> createState() => _StatesPreviewState();
}

class _StatesPreviewState extends State<StatesPreview> {
  late final WidgetStatesController _controller = WidgetStatesController(
    widget.states,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}

/// The interaction states every interactive component is shown in.
enum PreviewState {
  /// Resting.
  resting('Default', <WidgetState>{}),

  /// Pointer over the component.
  hovered('Hovered', <WidgetState>{WidgetState.hovered}),

  /// Keyboard focus.
  focused('Focused', <WidgetState>{WidgetState.focused}),

  /// Pointer down.
  pressed('Pressed', <WidgetState>{WidgetState.pressed}),

  /// No callback.
  disabled('Disabled', <WidgetState>{});

  new(this.label, this.states);

  /// Use case name suffix.
  final String label;

  /// Seeded states.
  final Set<WidgetState> states;

  /// Whether the component gets a null callback.
  bool get isDisabled => this == PreviewState.disabled;
}
