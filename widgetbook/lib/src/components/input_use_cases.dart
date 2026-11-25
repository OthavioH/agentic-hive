import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

/// The text input states shown for `HiveTextField` and `HiveTextArea`.
enum _InputState {
  resting('Default', <WidgetState>{}),
  hovered('Hovered', <WidgetState>{WidgetState.hovered}),
  focused('Focused', <WidgetState>{WidgetState.focused}),
  error('Error', <WidgetState>{}),
  disabled('Disabled', <WidgetState>{});

  new(this.label, this.states);

  final String label;
  final Set<WidgetState> states;
}

Widget _inputWidth(BuildContext context, Widget child) =>
    SizedBox(width: context.hiveSpacing.space8 * 6, child: child);

/// `HiveTextField`: every state, filled, helper, search and playground.
WidgetbookComponent textFieldComponent() {
  return WidgetbookComponent(
    name: 'HiveTextField',
    useCases: <WidgetbookUseCase>[
      for (final state in _InputState.values)
        WidgetbookUseCase(
          name: state.label,
          builder: (context) => UseCaseFrame(
            child: _inputWidth(
              context,
              StatesPreview(
                states: state.states,
                builder: (controller) => HiveTextField(
                  label: 'Name',
                  hintText: 'Code reviewer',
                  helperText: 'Shown in the agent list and the editor.',
                  errorText: state == _InputState.error
                      ? 'Name is required'
                      : null,
                  enabled: state != _InputState.disabled,
                  statesController: controller,
                ),
              ),
            ),
          ),
        ),
      WidgetbookUseCase(
        name: 'Filled',
        builder: (context) =>
            UseCaseFrame(child: _inputWidth(context, const _FilledField())),
      ),
      WidgetbookUseCase(
        name: 'Search input',
        builder: (context) => UseCaseFrame(
          child: _inputWidth(
            context,
            const HiveTextField(
              semanticLabel: 'Search agents',
              hintText: 'Search by id, name, description or tag',
              leadingIcon: HiveIcons.search,
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) => UseCaseFrame(
          child: _inputWidth(
            context,
            HiveTextField(
              label: context.knobs.string(label: 'Label', initialValue: 'Id'),
              hintText: context.knobs.string(
                label: 'Hint',
                initialValue: 'code-reviewer',
              ),
              helperText: context.knobs.stringOrNull(
                label: 'Helper',
                initialValue: 'Lowercase letters, digits, - and _',
              ),
              errorText: context.knobs.stringOrNull(label: 'Error'),
              enabled: context.knobs.boolean(
                label: 'Enabled',
                initialValue: true,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _FilledField extends StatefulWidget {
  const new();

  @override
  State<_FilledField> createState() => _FilledFieldState();
}

class _FilledFieldState extends State<_FilledField> {
  final TextEditingController _controller = TextEditingController(
    text: 'Release checklist reviewer for the desktop app',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HiveTextField(label: 'Description', controller: _controller);
  }
}

const String _prompt = '''
# Code reviewer

You review pull requests for the Agentic Hive repository.

## Responsibilities
- Check that `dart analyze --fatal-infos` reports nothing.
- Flag literal colors, spacing and radii outside the design system.
''';

/// `HiveTextArea`: every state, body and mono roles, filled.
WidgetbookComponent textAreaComponent() {
  return WidgetbookComponent(
    name: 'HiveTextArea',
    useCases: <WidgetbookUseCase>[
      for (final state in _InputState.values)
        WidgetbookUseCase(
          name: state.label,
          builder: (context) => UseCaseFrame(
            child: _inputWidth(
              context,
              StatesPreview(
                states: state.states,
                builder: (controller) => HiveTextArea(
                  label: 'Description',
                  hintText: 'What this agent is for and when to pick it',
                  errorText: state == _InputState.error
                      ? 'Description is too long'
                      : null,
                  enabled: state != _InputState.disabled,
                  statesController: controller,
                ),
              ),
            ),
          ),
        ),
      WidgetbookUseCase(
        name: 'Mono prompt (filled)',
        builder: (context) =>
            UseCaseFrame(child: _inputWidth(context, const _PromptArea())),
      ),
    ],
  );
}

class _PromptArea extends StatefulWidget {
  const new();

  @override
  State<_PromptArea> createState() => _PromptAreaState();
}

class _PromptAreaState extends State<_PromptArea> {
  final TextEditingController _controller = TextEditingController(
    text: _prompt,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HiveTextArea(
      label: 'Prompt',
      mono: true,
      minLines: 8,
      maxLines: 12,
      controller: _controller,
    );
  }
}

/// `HiveChip`: removable and filter variants in every state.
WidgetbookComponent chipComponent() {
  return WidgetbookComponent(
    name: 'HiveChip',
    useCases: <WidgetbookUseCase>[
      for (final state in PreviewState.values)
        WidgetbookUseCase(
          name: 'Removable · ${state.label}',
          builder: (context) => UseCaseFrame(
            child: StatesPreview(
              states: state.states,
              builder: (controller) => HiveChip.removable(
                label: 'flutter-validation',
                removeSemanticLabel: 'Remove skill flutter-validation',
                removeStatesController: controller,
                onRemoved: state.isDisabled ? null : _noop,
              ),
            ),
          ),
        ),
      for (final selected in <bool>[false, true])
        for (final state in PreviewState.values)
          WidgetbookUseCase(
            name:
                'Filter · ${selected ? 'Selected' : 'Unselected'} · '
                '${state.label}',
            builder: (context) => UseCaseFrame(
              child: StatesPreview(
                states: state.states,
                builder: (controller) => HiveChip.filter(
                  label: 'backend',
                  selected: selected,
                  statesController: controller,
                  onSelected: state.isDisabled ? null : (_) {},
                ),
              ),
            ),
          ),
      WidgetbookUseCase(
        name: 'Tag editor',
        builder: (context) => const UseCaseFrame(child: _TagEditor()),
      ),
      WidgetbookUseCase(
        name: 'Tag filter row',
        builder: (context) => const UseCaseFrame(child: _TagFilters()),
      ),
      WidgetbookUseCase(
        name: 'Read-only · Default',
        builder: (context) => const UseCaseFrame(
          child: HiveChip.readOnly(label: 'login-mockup.png · 248 KB'),
        ),
      ),
      WidgetbookUseCase(
        name: 'Read-only · Removed',
        builder: (context) => const UseCaseFrame(
          child: HiveChip.readOnly(
            label: 'login-mockup.png · 248 KB',
            removed: true,
            semanticLabel: 'login-mockup.png, 248 KB, removed',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Read-only · Long label',
        builder: (context) => UseCaseFrame(
          child: SizedBox(
            width: context.hiveSpacing.space8 * 3,
            child: const HiveChip.readOnly(
              label:
                  'Pasted image 1 - '
                  'checkout-flow-error-state-dark-theme.png · 1.2 MB',
              removed: true,
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Attachment list',
        builder: (context) => UseCaseFrame(
          child: Wrap(
            spacing: context.hiveSpacing.space1,
            runSpacing: context.hiveSpacing.space1,
            children: const <Widget>[
              HiveChip.readOnly(
                label: 'login-mockup.png · 248 KB',
                removed: true,
                semanticLabel: 'login-mockup.png, 248 KB, removed',
              ),
              HiveChip.readOnly(
                label: 'error-state.png · 112 KB',
                removed: true,
                semanticLabel: 'error-state.png, 112 KB, removed',
              ),
              HiveChip.readOnly(
                label: 'trace-log.txt · 18 KB',
                removed: true,
                semanticLabel: 'trace-log.txt, 18 KB, removed',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _TagEditor extends StatefulWidget {
  const new();

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  final List<String> _tags = <String>[
    'review',
    'dart',
    'design-system',
    'release-checklist-for-desktop-builds',
  ];

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    return SizedBox(
      width: spacing.space8 * 6,
      child: Wrap(
        spacing: spacing.space1,
        runSpacing: spacing.space1,
        children: <Widget>[
          for (final tag in _tags)
            HiveChip.removable(
              label: tag,
              removeSemanticLabel: 'Remove tag $tag',
              onRemoved: () => setState(() => _tags.remove(tag)),
            ),
        ],
      ),
    );
  }
}

class _TagFilters extends StatefulWidget {
  const new();

  @override
  State<_TagFilters> createState() => _TagFiltersState();
}

class _TagFiltersState extends State<_TagFilters> {
  static const List<String> _all = <String>[
    'review',
    'backend',
    'frontend',
    'docs',
    'release',
  ];
  final Set<String> _selected = <String>{'backend'};

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    return Wrap(
      spacing: spacing.space1,
      runSpacing: spacing.space1,
      children: <Widget>[
        for (final tag in _all)
          HiveChip.filter(
            label: tag,
            selected: _selected.contains(tag),
            onSelected: (on) =>
                setState(() => on ? _selected.add(tag) : _selected.remove(tag)),
          ),
      ],
    );
  }
}

const List<HiveSegment<String>> _promptViews = <HiveSegment<String>>[
  HiveSegment<String>(value: 'raw', label: 'Raw', icon: HiveIcons.edit),
  HiveSegment<String>(value: 'preview', label: 'Preview', icon: HiveIcons.runs),
];

/// `HiveSegmentedControl`: interactive, every segment state, disabled.
WidgetbookComponent segmentedControlComponent() {
  return WidgetbookComponent(
    name: 'HiveSegmentedControl',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Interactive',
        builder: (context) => const UseCaseFrame(child: _PromptViewToggle()),
      ),
      for (final state in PreviewState.values)
        if (!state.isDisabled)
          WidgetbookUseCase(
            name: 'Unselected segment · ${state.label}',
            builder: (context) => UseCaseFrame(
              child: StatesPreview(
                states: state.states,
                builder: (controller) => HiveSegmentedControl<String>(
                  segments: _promptViews,
                  selected: 'raw',
                  semanticLabel: 'Prompt view',
                  statesControllers: <int, WidgetStatesController>{
                    1: controller,
                  },
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
      WidgetbookUseCase(
        name: 'Text only',
        builder: (context) => UseCaseFrame(
          child: HiveSegmentedControl<String>(
            segments: const <HiveSegment<String>>[
              HiveSegment<String>(value: 'all', label: 'All'),
              HiveSegment<String>(value: 'valid', label: 'Valid'),
              HiveSegment<String>(value: 'errors', label: 'With errors'),
            ],
            selected: 'all',
            semanticLabel: 'Agent filter',
            onChanged: (_) {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Disabled',
        builder: (context) => const UseCaseFrame(
          child: HiveSegmentedControl<String>(
            segments: _promptViews,
            selected: 'raw',
            semanticLabel: 'Prompt view',
            onChanged: null,
          ),
        ),
      ),
    ],
  );
}

class _PromptViewToggle extends StatefulWidget {
  const new();

  @override
  State<_PromptViewToggle> createState() => _PromptViewToggleState();
}

class _PromptViewToggleState extends State<_PromptViewToggle> {
  String _view = 'raw';

  @override
  Widget build(BuildContext context) {
    return HiveSegmentedControl<String>(
      segments: _promptViews,
      selected: _view,
      semanticLabel: 'Prompt view',
      onChanged: (value) => setState(() => _view = value),
    );
  }
}
