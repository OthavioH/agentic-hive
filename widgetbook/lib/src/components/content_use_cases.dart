import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

const String _agentPrompt = '''
# Code reviewer

Reviews **pull requests** for the Agentic Hive repository and reports
findings through `report_result`.

## Responsibilities

- Check that `dart analyze --fatal-infos` reports nothing.
- Flag literal colors, spacing and radii outside the design system.
- Link each finding to the [design contract](docs/adrs/0018-design-system-widgetbook-and-lints.md).

## Execution guidance

1. Read the diff and the originating issue.
2. Run the zero-tolerance checks.
3. Summarize blocking findings first.

> Never approve your own changes.

```
dart format --output=none --set-exit-if-changed .
```

| Tool | Allowed |
| --- | --- |
| git | yes |
| gh | read only |

- [x] Read the diff
- [ ] Post the review

---

*Informational metadata only; tools are not enforced in F2.*
''';

/// `HiveInsetPanel`: compact, comfortable, tight, long stacked text, and with
/// a compact banner inside.
WidgetbookComponent insetPanelComponent() {
  Widget sized(BuildContext context, Widget child) =>
      SizedBox(width: context.hiveSpacing.space8 * 7, child: child);

  return WidgetbookComponent(
    name: 'HiveInsetPanel',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Compact · Badge and action',
        builder: (context) => UseCaseFrame(
          child: sized(
            context,
            const HiveInsetPanel(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  HiveBadge(
                    label: 'Skill installed',
                    tone: HiveBadgeTone.success,
                    icon: HiveIcons.check,
                  ),
                  HiveButton(
                    label: 'Remove',
                    size: HiveButtonSize.small,
                    variant: HiveButtonVariant.ghost,
                    onPressed: _noop,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Comfortable · Guidance text',
        builder: (context) => UseCaseFrame(
          child: sized(
            context,
            HiveInsetPanel(
              padding: HiveInsetPadding.comfortable,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  HiveIcon(
                    HiveIcons.alert,
                    size: context.hiveSpacing.space2,
                    color: context.hiveColors.warning,
                  ),
                  SizedBox(width: context.hiveSpacing.space1),
                  Expanded(
                    child: Text(
                      'Claude Code is not signed in. Run claude login in a '
                      'terminal, then re-check.',
                      style: context.hiveTypography.bodySmall.copyWith(
                        color: context.hiveColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Tight · Logo tile',
        builder: (context) => UseCaseFrame(
          child: HiveInsetPanel(
            padding: HiveInsetPadding.tight,
            child: HiveIcon(
              HiveIcons.harnessClaudeCode,
              size: context.hiveSpacing.space3,
              color: context.hiveColors.onSurface,
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Long text · Stacked explanation',
        builder: (context) => UseCaseFrame(
          child: sized(
            context,
            HiveInsetPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: context.hiveSpacing.space1,
                    runSpacing: context.hiveSpacing.space1,
                    children: const <Widget>[
                      HiveBadge(
                        label: 'Skill status unknown',
                        icon: HiveIcons.info,
                      ),
                      HiveButton(
                        label: 'Retry',
                        size: HiveButtonSize.small,
                        variant: HiveButtonVariant.secondary,
                        onPressed: _noop,
                      ),
                    ],
                  ),
                  SizedBox(height: context.hiveSpacing.space1),
                  Text(
                    'Could not read ~/.claude/skills/agentic-hive/SKILL.md: '
                    'permission denied while inspecting existing installation.',
                    style: context.hiveTypography.bodySmall.copyWith(
                      color: context.hiveColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'With compact banner inside',
        builder: (context) => UseCaseFrame(
          child: sized(
            context,
            HiveInsetPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      HiveBadge(
                        label: 'Skill installed',
                        tone: HiveBadgeTone.success,
                        icon: HiveIcons.check,
                      ),
                      HiveButton(
                        label: 'Remove',
                        size: HiveButtonSize.small,
                        variant: HiveButtonVariant.ghost,
                        onPressed: _noop,
                      ),
                    ],
                  ),
                  SizedBox(height: context.hiveSpacing.space1),
                  const HiveBanner(
                    tone: HiveFeedbackTone.warning,
                    density: HiveBannerDensity.compact,
                    title: 'Hive MCP server is not installed',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// `HiveMarkdownView`: a full agent prompt and a short note.
WidgetbookComponent markdownViewComponent() {
  return WidgetbookComponent(
    name: 'HiveMarkdownView',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Agent prompt',
        builder: (context) => SingleChildScrollView(
          padding: EdgeInsets.all(context.hiveSpacing.space4),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: context.hiveSpacing.space8 * 10,
              child: const HiveMarkdownView(data: _agentPrompt),
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) => SingleChildScrollView(
          padding: EdgeInsets.all(context.hiveSpacing.space4),
          child: HiveMarkdownView(
            data: context.knobs.string(
              label: 'Markdown',
              initialValue: '## Outputs\n\nA **review** with `findings`.',
              maxLines: 8,
            ),
          ),
        ),
      ),
    ],
  );
}

/// `HiveCollapsibleSection`: collapsed, expanded and header states.
WidgetbookComponent collapsibleSectionComponent() {
  Widget body(BuildContext context) => Wrap(
    spacing: context.hiveSpacing.space1,
    runSpacing: context.hiveSpacing.space1,
    children: const <Widget>[
      HiveChip.removable(
        label: 'flutter-validation',
        removeSemanticLabel: 'Remove skill flutter-validation',
        onRemoved: _noop,
      ),
      HiveChip.removable(
        label: 'context7',
        removeSemanticLabel: 'Remove tool context7',
        onRemoved: _noop,
      ),
    ],
  );
  Widget sized(BuildContext context, Widget child) =>
      SizedBox(width: context.hiveSpacing.space8 * 8, child: child);

  return WidgetbookComponent(
    name: 'HiveCollapsibleSection',
    useCases: <WidgetbookUseCase>[
      for (final expanded in <bool>[false, true])
        WidgetbookUseCase(
          name: expanded ? 'Expanded' : 'Collapsed',
          builder: (context) => UseCaseFrame(
            child: sized(
              context,
              HiveCollapsibleSection(
                title: 'Capabilities & tools',
                subtitle: 'Informational; not enforced',
                initiallyExpanded: expanded,
                trailing: const HiveBadge(label: '2'),
                child: body(context),
              ),
            ),
          ),
        ),
      for (final state in PreviewState.values)
        if (!state.isDisabled && state != PreviewState.resting)
          WidgetbookUseCase(
            name: 'Header · ${state.label}',
            builder: (context) => UseCaseFrame(
              child: sized(
                context,
                StatesPreview(
                  states: state.states,
                  builder: (controller) => HiveCollapsibleSection(
                    title: 'Capabilities & tools',
                    statesController: controller,
                    child: body(context),
                  ),
                ),
              ),
            ),
          ),
    ],
  );
}

/// `HiveMasterDetail`: empty detail, the agent editor, and the narrow
/// fallbacks.
WidgetbookComponent masterDetailComponent() {
  return WidgetbookComponent(
    name: 'HiveMasterDetail',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Nothing selected',
        builder: (context) => const _Page(
          child: HiveMasterDetail(
            master: _AgentList(selected: null),
            detail: HiveEmptyState(
              icon: HiveIcons.agents,
              title: 'No agent selected',
              message: 'Pick an agent from the list or create a new one.',
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Agent editor composition',
        builder: (context) => const _Page(
          child: HiveMasterDetail(
            master: _AgentList(selected: 'code-reviewer'),
            detail: _AgentEditor(),
          ),
        ),
      ),
      for (final detailVisible in <bool>[false, true])
        WidgetbookUseCase(
          name: 'Narrow · ${detailVisible ? 'Detail' : 'Master'}',
          builder: (context) => _Page(
            child: Center(
              child: SizedBox(
                width: context.hiveSpacing.space8 * 7,
                child: HiveMasterDetail(
                  detailVisible: detailVisible,
                  master: const _AgentList(selected: 'code-reviewer'),
                  detail: const _AgentEditor(),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// `HiveSplitter`: horizontal and vertical orientations across interaction
/// states, plus near-minimum clamping.
WidgetbookComponent splitterComponent() {
  Widget pane(BuildContext context, String label) => HiveInsetPanel(
    child: Align(
      alignment: Alignment.topLeft,
      child: Text(
        label,
        style: context.hiveTypography.titleSmall.copyWith(
          color: context.hiveColors.onSurface,
        ),
      ),
    ),
  );

  const orientations = <(String, Axis)>[
    ('Side by side', Axis.horizontal),
    ('Stacked', Axis.vertical),
  ];

  return WidgetbookComponent(
    name: 'HiveSplitter',
    useCases: <WidgetbookUseCase>[
      for (final orientation in orientations)
        for (final state in PreviewState.values)
          if (!state.isDisabled)
            WidgetbookUseCase(
              name: '${orientation.$1} · ${state.label}',
              builder: (context) => _Page(
                child: StatesPreview(
                  states: state.states,
                  builder: (controller) => HiveSplitter(
                    statesController: controller,
                    axis: orientation.$2,
                    initialPosition: 0.6,
                    semanticLabel: 'Resize graph and inspector',
                    first: pane(context, 'Graph'),
                    second: pane(context, 'Inspector'),
                  ),
                ),
              ),
            ),
      WidgetbookUseCase(
        name: 'Near minimums',
        builder: (context) => _Page(
          child: Center(
            child: SizedBox(
              width: context.hiveSpacing.space8 * 9,
              child: HiveSplitter(
                initialPosition: 0.95,
                semanticLabel: 'Resize graph and inspector',
                first: pane(context, 'Graph'),
                second: pane(context, 'Inspector'),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _Page extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    return Padding(
      padding: EdgeInsets.all(spacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const HivePageHeader(
            title: 'Agents',
            subtitle: 'Reusable roles stored as Markdown files',
            actions: <Widget>[
              HiveButton(
                label: 'New agent',
                icon: HiveIcons.add,
                onPressed: _noop,
              ),
            ],
          ),
          SizedBox(height: spacing.space3),
          Expanded(child: child),
        ],
      ),
    );
  }
}

const List<(String, String, String)> _agents = <(String, String, String)>[
  ('code-reviewer', 'Code reviewer', 'Reviews pull requests for style'),
  ('release-manager', 'Release manager', 'Prepares release notes and tags'),
  ('docs-writer', 'Docs writer', 'Keeps README and ADRs current'),
  ('broken-agent', 'broken-agent.md', 'Invalid YAML frontmatter'),
];

class _AgentList extends StatelessWidget {
  const new({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    return ListView(
      padding: EdgeInsets.all(spacing.space2),
      children: <Widget>[
        const HiveTextField(
          semanticLabel: 'Search agents',
          hintText: 'Search agents',
          leadingIcon: HiveIcons.search,
        ),
        SizedBox(height: spacing.space2),
        Wrap(
          spacing: spacing.space1,
          runSpacing: spacing.space1,
          children: <Widget>[
            for (final tag in <String>['review', 'release', 'docs'])
              HiveChip.filter(
                label: tag,
                selected: tag == 'review',
                onSelected: (_) {},
              ),
          ],
        ),
        SizedBox(height: spacing.space2),
        for (final (id, name, description) in _agents) ...<Widget>[
          HiveCard(
            surface: id == selected
                ? HiveCardSurface.surface2
                : HiveCardSurface.surface1,
            semanticLabel: name,
            onPressed: _noop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.labelLarge.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (id == 'broken-agent')
                      const HiveBadge(
                        label: 'Parse error',
                        tone: HiveBadgeTone.danger,
                        icon: HiveIcons.alert,
                      ),
                  ],
                ),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodySmall.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing.space1),
        ],
      ],
    );
  }
}

class _AgentEditor extends StatefulWidget {
  const new();

  @override
  State<_AgentEditor> createState() => _AgentEditorState();
}

class _AgentEditorState extends State<_AgentEditor> {
  String _view = 'raw';
  final TextEditingController _name = TextEditingController(
    text: 'Code reviewer',
  );
  final TextEditingController _prompt = TextEditingController(
    text: _agentPrompt,
  );

  @override
  void dispose() {
    _name.dispose();
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    return ListView(
      padding: EdgeInsets.all(spacing.space3),
      children: <Widget>[
        HiveTextField(label: 'Name', controller: _name),
        SizedBox(height: spacing.space2),
        const HiveTextField(
          label: 'Id',
          hintText: 'code-reviewer',
          helperText: 'The file name; it cannot change after the first save.',
          enabled: false,
        ),
        SizedBox(height: spacing.space2),
        const HiveTextArea(
          label: 'Description',
          minLines: 2,
          hintText: 'What this agent is for and when to pick it',
        ),
        SizedBox(height: spacing.space2),
        Wrap(
          spacing: spacing.space1,
          runSpacing: spacing.space1,
          children: const <Widget>[
            HiveChip.removable(
              label: 'review',
              removeSemanticLabel: 'Remove tag review',
              onRemoved: _noop,
            ),
            HiveChip.removable(
              label: 'dart',
              removeSemanticLabel: 'Remove tag dart',
              onRemoved: _noop,
            ),
          ],
        ),
        SizedBox(height: spacing.space3),
        const HiveCollapsibleSection(
          title: 'Capabilities & tools',
          subtitle: 'Informational; not enforced',
          child: HiveTextField(label: 'Required skills'),
        ),
        SizedBox(height: spacing.space3),
        Align(
          alignment: Alignment.centerLeft,
          child: HiveSegmentedControl<String>(
            segments: const <HiveSegment<String>>[
              HiveSegment<String>(value: 'raw', label: 'Raw'),
              HiveSegment<String>(value: 'preview', label: 'Preview'),
            ],
            selected: _view,
            semanticLabel: 'Prompt view',
            onChanged: (value) => setState(() => _view = value),
          ),
        ),
        SizedBox(height: spacing.space2),
        if (_view == 'raw')
          HiveTextArea(
            semanticLabel: 'Prompt',
            mono: true,
            minLines: 12,
            controller: _prompt,
          )
        else
          HiveMarkdownView(data: _prompt.text),
      ],
    );
  }
}
