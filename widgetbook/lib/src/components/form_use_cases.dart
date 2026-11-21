import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

/// The field states a form control is shown in (no pressed state).
const List<PreviewState> _fieldStates = <PreviewState>[
  PreviewState.resting,
  PreviewState.hovered,
  PreviewState.focused,
  PreviewState.disabled,
];

/// Gives a form control the width of an inspector column.
class _FieldWidth extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return UseCaseFrame(
      child: SizedBox(width: context.hiveSpacing.space8 * 5, child: child),
    );
  }
}

const List<HiveSelectOption<String>> _sourceOutputs =
    <HiveSelectOption<String>>[
      HiveSelectOption<String>(
        value: 'onSuccess',
        label: 'onSuccess',
        icon: HiveIcons.check,
      ),
      HiveSelectOption<String>(
        value: 'onFailure',
        label: 'onFailure',
        icon: HiveIcons.alert,
      ),
      HiveSelectOption<String>(
        value: 'needsChanges',
        label: 'needsChanges',
        icon: HiveIcons.validatorReview,
      ),
    ];

/// `HiveTextField`: single-line and multi-line in every state, helper,
/// error, long text and a playground.
WidgetbookComponent textFieldComponent() {
  return WidgetbookComponent(
    name: 'HiveTextField',
    useCases: <WidgetbookUseCase>[
      for (final multiline in <bool>[false, true])
        for (final state in _fieldStates)
          WidgetbookUseCase(
            name:
                '${multiline ? 'Multi-line' : 'Single-line'} · '
                '${state.label}',
            builder: (context) => _FieldWidth(
              child: StatesPreview(
                states: state.states,
                builder: (controller) => HiveTextField(
                  label: multiline ? 'Description' : 'Workflow name',
                  hint: multiline
                      ? 'What this workflow automates'
                      : 'Release checklist',
                  multiline: multiline,
                  enabled: !state.isDisabled,
                  statesController: controller,
                ),
              ),
            ),
          ),
      WidgetbookUseCase(
        name: 'Single-line · Helper',
        builder: (context) => const _FieldWidth(
          child: HiveTextField(
            label: 'Workflow name',
            hint: 'Release checklist',
            helperText: 'Shown in the workflow list and run history.',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Single-line · Error',
        builder: (context) => const _FieldWidth(
          child: HiveTextField(
            label: 'Workflow name',
            hint: 'Release checklist',
            errorText: 'Name is required.',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Multi-line · Error',
        builder: (context) => const _FieldWidth(
          child: HiveTextField(
            label: 'Description',
            hint: 'What this workflow automates',
            errorText: 'Describe what this workflow automates.',
            multiline: true,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Long text',
        builder: (context) => _FieldWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HiveTextField(
                label: 'Workflow name',
                controller: TextEditingController(
                  text:
                      'Nightly dependency upgrade with review, tests and '
                      'release notes for every package in the monorepo',
                ),
              ),
              SizedBox(height: context.hiveSpacing.space3),
              HiveTextField(
                label: 'Description',
                multiline: true,
                controller: TextEditingController(
                  text:
                      'Runs Claude Code to upgrade dependencies, then a test '
                      'validator. On failure it retries the upgrade up to '
                      'three times before pausing for human approval. On '
                      'success it drafts release notes with Codex and opens '
                      'a pull request for review.',
                ),
              ),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final error = context.knobs.boolean(label: 'Error');
          return _FieldWidth(
            child: HiveTextField(
              label: context.knobs.string(
                label: 'Label',
                initialValue: 'Workflow name',
              ),
              hint: context.knobs.string(
                label: 'Hint',
                initialValue: 'Release checklist',
              ),
              helperText: context.knobs.stringOrNull(
                label: 'Helper',
                initialValue: 'Shown in the workflow list.',
              ),
              errorText: error ? 'Name is required.' : null,
              multiline: context.knobs.boolean(label: 'Multi-line'),
              enabled: context.knobs.boolean(
                label: 'Enabled',
                initialValue: true,
              ),
            ),
          );
        },
      ),
    ],
  );
}

/// `HiveSelect`: every state, placeholder, error, icons and a live select.
WidgetbookComponent selectComponent() {
  return WidgetbookComponent(
    name: 'HiveSelect',
    useCases: <WidgetbookUseCase>[
      for (final state in _fieldStates)
        WidgetbookUseCase(
          name: 'Select · ${state.label}',
          builder: (context) => _FieldWidth(
            child: StatesPreview(
              states: state.states,
              builder: (controller) => HiveSelect<String>(
                label: 'Source output',
                options: _sourceOutputs,
                value: 'onSuccess',
                statesController: controller,
                onChanged: state.isDisabled ? null : (_) {},
              ),
            ),
          ),
        ),
      WidgetbookUseCase(
        name: 'Placeholder',
        builder: (context) => _FieldWidth(
          child: HiveSelect<String>(
            label: 'Source output',
            hint: 'Choose an output',
            options: _sourceOutputs,
            value: null,
            onChanged: (_) {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Select · Error',
        builder: (context) => _FieldWidth(
          child: HiveSelect<String>(
            label: 'Source output',
            hint: 'Choose an output',
            options: _sourceOutputs,
            value: null,
            errorText: 'An edge needs a source output.',
            onChanged: (_) {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Interactive',
        builder: (context) => const _FieldWidth(child: _LiveSelect()),
      ),
    ],
  );
}

class _LiveSelect extends StatefulWidget {
  const new();

  @override
  State<_LiveSelect> createState() => _LiveSelectState();
}

class _LiveSelectState extends State<_LiveSelect> {
  String? _value = 'onSuccess';

  @override
  Widget build(BuildContext context) {
    return HiveSelect<String>(
      label: 'Source output',
      hint: 'Choose an output',
      helperText: 'Edges from the same output run in parallel.',
      options: _sourceOutputs,
      value: _value,
      onChanged: (value) => setState(() => _value = value),
    );
  }
}

/// `HiveSwitch`: on and off in every state, with a label, and live.
WidgetbookComponent switchComponent() {
  return WidgetbookComponent(
    name: 'HiveSwitch',
    useCases: <WidgetbookUseCase>[
      for (final on in <bool>[true, false])
        for (final state in PreviewState.values)
          WidgetbookUseCase(
            name: '${on ? 'On' : 'Off'} · ${state.label}',
            builder: (context) => UseCaseFrame(
              child: StatesPreview(
                states: state.states,
                builder: (controller) => HiveSwitch(
                  semanticLabel: 'Entry node',
                  value: on,
                  statesController: controller,
                  onChanged: state.isDisabled ? null : (_) {},
                ),
              ),
            ),
          ),
      WidgetbookUseCase(
        name: 'With label',
        builder: (context) => UseCaseFrame(
          child: ShowcaseSection(
            title: 'With label',
            children: <Widget>[
              HiveSwitch(label: 'Entry node', value: true, onChanged: (_) {}),
              HiveSwitch(label: 'Entry node', value: false, onChanged: (_) {}),
              const HiveSwitch(
                label: 'Entry node',
                value: true,
                onChanged: null,
              ),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Interactive switch',
        builder: (context) => const UseCaseFrame(child: _LiveSwitch()),
      ),
    ],
  );
}

class _LiveSwitch extends StatefulWidget {
  const new();

  @override
  State<_LiveSwitch> createState() => _LiveSwitchState();
}

class _LiveSwitchState extends State<_LiveSwitch> {
  bool _value = false;

  @override
  Widget build(BuildContext context) {
    return HiveSwitch(
      label: 'Entry node',
      value: _value,
      onChanged: (value) => setState(() => _value = value),
    );
  }
}

/// `HiveDialog`: the destructive and primary confirmations, a form dialog,
/// and a live launcher for the open/close transition.
WidgetbookComponent dialogComponent() {
  return WidgetbookComponent(
    name: 'HiveDialog',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Delete confirmation',
        builder: (context) => const HiveDialog(
          title: 'Delete "Release checklist"?',
          message:
              'The workflow, its nodes and its layout are removed. Past runs '
              'keep their history.',
          actions: <Widget>[
            HiveButton(
              label: 'Cancel',
              variant: HiveButtonVariant.secondary,
              onPressed: _noop,
            ),
            HiveButton(
              label: 'Delete workflow',
              variant: HiveButtonVariant.danger,
              icon: HiveIcons.delete,
              onPressed: _noop,
            ),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'Unsaved changes',
        builder: (context) => const HiveDialog(
          title: 'Discard unsaved changes?',
          message:
              'You moved 3 nodes and added an edge since the last save. '
              'Leaving now discards them.',
          actions: <Widget>[
            HiveButton(
              label: 'Discard',
              variant: HiveButtonVariant.ghost,
              onPressed: _noop,
            ),
            HiveButton(
              label: 'Keep editing',
              variant: HiveButtonVariant.secondary,
              onPressed: _noop,
            ),
            HiveButton(label: 'Save and leave', onPressed: _noop),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'With content',
        builder: (context) => HiveDialog(
          title: 'Duplicate workflow',
          message: 'The copy starts as a draft with the same graph.',
          content: HiveTextField(
            label: 'Workflow name',
            controller: TextEditingController(text: 'Release checklist (copy)'),
          ),
          actions: const <Widget>[
            HiveButton(
              label: 'Cancel',
              variant: HiveButtonVariant.secondary,
              onPressed: _noop,
            ),
            HiveButton(label: 'Duplicate', onPressed: _noop),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'Live',
        builder: (context) => const UseCaseFrame(child: _LiveDialog()),
      ),
    ],
  );
}

class _LiveDialog extends StatefulWidget {
  const new();

  @override
  State<_LiveDialog> createState() => _LiveDialogState();
}

class _LiveDialogState extends State<_LiveDialog> {
  String _result = 'No answer yet';

  Future<void> _open() async {
    final confirmed = await HiveDialog.confirm(
      context: context,
      title: 'Delete "Release checklist"?',
      message: 'The workflow, its nodes and its layout are removed.',
      confirmLabel: 'Delete workflow',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (!mounted) return;
    setState(() => _result = confirmed ? 'Deleted' : 'Kept');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HiveButton(
          label: 'Delete workflow',
          variant: HiveButtonVariant.danger,
          icon: HiveIcons.delete,
          onPressed: _open,
        ),
        SizedBox(height: context.hiveSpacing.space2),
        Text(
          _result,
          style: context.hiveTypography.mono.copyWith(
            color: colors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}

const List<MapEntry<String, String>> _environment = <MapEntry<String, String>>[
  MapEntry<String, String>('ANTHROPIC_MODEL', 'claude-opus-5-5'),
  MapEntry<String, String>('LOG_LEVEL', 'debug'),
  MapEntry<String, String>('HTTPS_PROXY', 'http://proxy.internal:3128'),
];

/// `HiveKeyValueEditor`: filled, empty, key problems, error, disabled and a
/// live editor.
WidgetbookComponent keyValueEditorComponent() {
  HiveKeyValueEditor editor({
    required List<MapEntry<String, String>> entries,
    String? errorText,
    bool enabled = true,
  }) {
    return HiveKeyValueEditor(
      label: 'Environment variables',
      helperText: 'Passed to the harness process.',
      errorText: errorText,
      keyPlaceholder: 'NAME',
      valuePlaceholder: 'Value',
      addButtonLabel: 'Add variable',
      emptyText: 'No environment variables.',
      entries: entries,
      enabled: enabled,
      onChanged: (_) {},
    );
  }

  return WidgetbookComponent(
    name: 'HiveKeyValueEditor',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Variables · Filled',
        builder: (context) => _FieldWidth(child: editor(entries: _environment)),
      ),
      WidgetbookUseCase(
        name: 'Variables · Empty',
        builder: (context) => _FieldWidth(
          child: editor(entries: const <MapEntry<String, String>>[]),
        ),
      ),
      WidgetbookUseCase(
        name: 'Variables · Duplicate and empty keys',
        builder: (context) => _FieldWidth(
          child: editor(
            entries: const <MapEntry<String, String>>[
              MapEntry<String, String>('LOG_LEVEL', 'debug'),
              MapEntry<String, String>('LOG_LEVEL', 'info'),
              MapEntry<String, String>('', 'claude-opus-5-5'),
            ],
            errorText: 'Fix the highlighted keys before saving.',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Variables · Disabled',
        builder: (context) =>
            _FieldWidth(child: editor(entries: _environment, enabled: false)),
      ),
      WidgetbookUseCase(
        name: 'Variables · Interactive',
        builder: (context) => const _FieldWidth(child: _LiveKeyValueEditor()),
      ),
    ],
  );
}

class _LiveKeyValueEditor extends StatefulWidget {
  const new();

  @override
  State<_LiveKeyValueEditor> createState() => _LiveKeyValueEditorState();
}

class _LiveKeyValueEditorState extends State<_LiveKeyValueEditor> {
  List<MapEntry<String, String>> _entries = _environment;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HiveKeyValueEditor(
          label: 'Environment variables',
          helperText: 'Passed to the harness process.',
          keyPlaceholder: 'NAME',
          valuePlaceholder: 'Value',
          addButtonLabel: 'Add variable',
          emptyText: 'No environment variables.',
          entries: _entries,
          onChanged: (entries) => setState(() => _entries = entries),
        ),
        SizedBox(height: context.hiveSpacing.space2),
        Text(
          _entries.map((e) => '${e.key}=${e.value}').join('\n'),
          style: context.hiveTypography.mono.copyWith(
            color: context.hiveColors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}

const List<String> _extraArgs = <String>[
  '--verbose',
  '--output-format=stream-json',
];

/// `HiveStringListField`: filled, empty, error, disabled and a live field.
WidgetbookComponent stringListFieldComponent() {
  HiveStringListField field({
    required List<String> items,
    String? errorText,
    bool enabled = true,
  }) {
    return HiveStringListField(
      label: 'Extra arguments',
      helperText: 'Appended to the harness command, one per item.',
      errorText: errorText,
      itemLabel: 'Argument',
      itemPlaceholder: '--flag',
      addButtonLabel: 'Add argument',
      emptyText: 'No extra arguments.',
      items: items,
      enabled: enabled,
      onChanged: (_) {},
    );
  }

  return WidgetbookComponent(
    name: 'HiveStringListField',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Arguments · Filled',
        builder: (context) => _FieldWidth(child: field(items: _extraArgs)),
      ),
      WidgetbookUseCase(
        name: 'Arguments · Empty',
        builder: (context) =>
            _FieldWidth(child: field(items: const <String>[])),
      ),
      WidgetbookUseCase(
        name: 'Arguments · Error',
        builder: (context) => _FieldWidth(
          child: field(
            items: const <String>['--verbose', ''],
            errorText: 'Remove empty arguments.',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Arguments · Disabled',
        builder: (context) =>
            _FieldWidth(child: field(items: _extraArgs, enabled: false)),
      ),
      WidgetbookUseCase(
        name: 'Arguments · Interactive',
        builder: (context) => const _FieldWidth(child: _LiveStringListField()),
      ),
    ],
  );
}

class _LiveStringListField extends StatefulWidget {
  const new();

  @override
  State<_LiveStringListField> createState() => _LiveStringListFieldState();
}

class _LiveStringListFieldState extends State<_LiveStringListField> {
  List<String> _items = _extraArgs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HiveStringListField(
          label: 'Extra arguments',
          helperText: 'Press Enter to add the next argument.',
          itemLabel: 'Argument',
          itemPlaceholder: '--flag',
          addButtonLabel: 'Add argument',
          emptyText: 'No extra arguments.',
          items: _items,
          onChanged: (items) => setState(() => _items = items),
        ),
        SizedBox(height: context.hiveSpacing.space2),
        Text(
          'claude ${_items.join(' ')}',
          style: context.hiveTypography.mono.copyWith(
            color: context.hiveColors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}
