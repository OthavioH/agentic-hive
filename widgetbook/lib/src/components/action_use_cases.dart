import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

String _variantName(HiveButtonVariant variant) =>
    '${variant.name[0].toUpperCase()}${variant.name.substring(1)}';

/// `HiveButton`: every variant in every state, sizes, icon and playground.
WidgetbookComponent buttonComponent() {
  return WidgetbookComponent(
    name: 'HiveButton',
    useCases: <WidgetbookUseCase>[
      for (final variant in HiveButtonVariant.values) ...<WidgetbookUseCase>[
        for (final state in PreviewState.values)
          WidgetbookUseCase(
            name: '${_variantName(variant)} · ${state.label}',
            builder: (context) => UseCaseFrame(
              child: StatesPreview(
                states: state.states,
                builder: (controller) => HiveButton(
                  label: 'Run workflow',
                  icon: HiveIcons.play,
                  variant: variant,
                  statesController: controller,
                  onPressed: state.isDisabled ? null : _noop,
                ),
              ),
            ),
          ),
        WidgetbookUseCase(
          name: '${_variantName(variant)} · Loading',
          builder: (context) => UseCaseFrame(
            child: HiveButton(
              label: 'Starting run',
              variant: variant,
              loading: true,
              onPressed: _noop,
            ),
          ),
        ),
      ],
      WidgetbookUseCase(
        name: 'Sizes',
        builder: (context) => UseCaseFrame(
          child: ShowcaseSection(
            title: 'Sizes',
            children: <Widget>[
              for (final size in HiveButtonSize.values)
                Labeled(
                  label: size.name,
                  child: HiveButton(
                    label: 'Run workflow',
                    icon: HiveIcons.play,
                    size: size,
                    onPressed: _noop,
                  ),
                ),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Long label',
        builder: (context) => UseCaseFrame(
          child: SizedBox(
            width: context.hiveSpacing.space8 * 3,
            child: const HiveButton(
              label: 'Approve and continue the release checklist workflow',
              variant: HiveButtonVariant.secondary,
              onPressed: _noop,
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) => UseCaseFrame(
          child: HiveButton(
            label: context.knobs.string(
              label: 'Label',
              initialValue: 'Run workflow',
            ),
            variant: context.knobs.object.dropdown<HiveButtonVariant>(
              label: 'Variant',
              options: HiveButtonVariant.values,
              labelBuilder: (v) => v.name,
            ),
            size: context.knobs.object.dropdown<HiveButtonSize>(
              label: 'Size',
              options: HiveButtonSize.values,
              initialOption: HiveButtonSize.medium,
              labelBuilder: (v) => v.name,
            ),
            icon: context.knobs.boolean(label: 'Icon', initialValue: true)
                ? HiveIcons.play
                : null,
            loading: context.knobs.boolean(label: 'Loading'),
            onPressed:
                context.knobs.boolean(label: 'Enabled', initialValue: true)
                ? _noop
                : null,
          ),
        ),
      ),
    ],
  );
}

/// `HiveIconButton`: every variant in every state, loading, sizes and
/// playground.
WidgetbookComponent iconButtonComponent() {
  return WidgetbookComponent(
    name: 'HiveIconButton',
    useCases: <WidgetbookUseCase>[
      for (final variant in HiveButtonVariant.values) ...<WidgetbookUseCase>[
        for (final state in PreviewState.values)
          WidgetbookUseCase(
            name: '${_variantName(variant)} · ${state.label}',
            builder: (context) => UseCaseFrame(
              child: StatesPreview(
                states: state.states,
                builder: (controller) => HiveIconButton(
                  icon: HiveIcons.more,
                  semanticLabel: 'More actions',
                  variant: variant,
                  statesController: controller,
                  onPressed: state.isDisabled ? null : _noop,
                ),
              ),
            ),
          ),
        WidgetbookUseCase(
          name: '${_variantName(variant)} · Loading',
          builder: (context) => UseCaseFrame(
            child: HiveIconButton(
              icon: HiveIcons.refresh,
              semanticLabel: 'Re-checking Claude Code',
              variant: variant,
              loading: true,
              onPressed: _noop,
            ),
          ),
        ),
      ],
      for (final state in PreviewState.values)
        WidgetbookUseCase(
          name: 'Danger hover · ${state.label}',
          builder: (context) => UseCaseFrame(
            child: StatesPreview(
              states: state.states,
              builder: (controller) => HiveIconButton.dangerHover(
                icon: HiveIcons.close,
                semanticLabel: 'Close to tray',
                statesController: controller,
                onPressed: state.isDisabled ? null : _noop,
              ),
            ),
          ),
        ),
      WidgetbookUseCase(
        name: 'Sizes',
        builder: (context) => UseCaseFrame(
          child: ShowcaseSection(
            title: 'Sizes',
            children: <Widget>[
              for (final size in HiveButtonSize.values)
                Labeled(
                  label: size.name,
                  child: HiveIconButton(
                    icon: HiveIcons.add,
                    semanticLabel: 'New workflow',
                    variant: HiveButtonVariant.secondary,
                    size: size,
                    onPressed: _noop,
                  ),
                ),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Loading sizes',
        builder: (context) => UseCaseFrame(
          child: ShowcaseSection(
            title: 'Loading sizes',
            children: <Widget>[
              for (final size in HiveButtonSize.values)
                Labeled(
                  label: size.name,
                  child: HiveIconButton(
                    icon: HiveIcons.refresh,
                    semanticLabel: 'Re-checking Codex',
                    variant: HiveButtonVariant.secondary,
                    size: size,
                    loading: true,
                    onPressed: _noop,
                  ),
                ),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Re-check flow',
        builder: (context) => const UseCaseFrame(child: _RecheckDemo()),
      ),
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) => UseCaseFrame(
          child: HiveIconButton(
            icon: HiveIcons.refresh,
            semanticLabel: context.knobs.string(
              label: 'Semantic label',
              initialValue: 'Re-check Gemini CLI',
            ),
            variant: context.knobs.object.dropdown<HiveButtonVariant>(
              label: 'Variant',
              options: HiveButtonVariant.values,
              initialOption: HiveButtonVariant.secondary,
              labelBuilder: (v) => v.name,
            ),
            size: context.knobs.object.dropdown<HiveButtonSize>(
              label: 'Size',
              options: HiveButtonSize.values,
              initialOption: HiveButtonSize.medium,
              labelBuilder: (v) => v.name,
            ),
            dangerHover: context.knobs.boolean(label: 'Danger hover'),
            loading: context.knobs.boolean(label: 'Loading'),
            onPressed:
                context.knobs.boolean(label: 'Enabled', initialValue: true)
                ? _noop
                : null,
          ),
        ),
      ),
    ],
  );
}

/// A harness card's re-check button: loads for two `long` periods, then
/// confirms with a toast.
class _RecheckDemo extends StatefulWidget {
  const new();

  @override
  State<_RecheckDemo> createState() => _RecheckDemoState();
}

class _RecheckDemoState extends State<_RecheckDemo> {
  bool _loading = false;

  Future<void> _recheck() async {
    setState(() => _loading = true);
    await Future<void>.delayed(context.hiveMotion.long * 2);
    if (!mounted) return;
    setState(() => _loading = false);
    HiveToast.show(
      context,
      message: 'Claude Code is ready',
      tone: HiveToastTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HiveIconButton(
      icon: HiveIcons.refresh,
      semanticLabel: 'Re-check Claude Code',
      variant: HiveButtonVariant.secondary,
      loading: _loading,
      onPressed: _recheck,
    );
  }
}

/// `HiveCard`: surfaces, interactive states and realistic content.
WidgetbookComponent cardComponent() {
  Widget metric(BuildContext context) {
    final colors = context.hiveColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Active runs',
          style: context.hiveTypography.label.copyWith(
            color: colors.onSurfaceMuted,
          ),
        ),
        Text(
          '3',
          style: context.hiveTypography.number.copyWith(
            color: colors.onSurface,
          ),
        ),
        Text(
          '2 waiting for approval',
          style: context.hiveTypography.bodySmall.copyWith(
            color: colors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }

  Widget sized(BuildContext context, Widget child) =>
      SizedBox(width: context.hiveSpacing.space8 * 4, child: child);

  return WidgetbookComponent(
    name: 'HiveCard',
    useCases: <WidgetbookUseCase>[
      for (final surface in HiveCardSurface.values)
        WidgetbookUseCase(
          name: 'Static · ${surface.name}',
          builder: (context) => UseCaseFrame(
            child: sized(
              context,
              HiveCard(surface: surface, child: metric(context)),
            ),
          ),
        ),
      for (final state in PreviewState.values)
        if (!state.isDisabled)
          WidgetbookUseCase(
            name: 'Interactive · ${state.label}',
            builder: (context) => UseCaseFrame(
              child: sized(
                context,
                StatesPreview(
                  states: state.states,
                  builder: (controller) => HiveCard(
                    semanticLabel: 'Active runs: 3',
                    statesController: controller,
                    onPressed: _noop,
                    child: metric(context),
                  ),
                ),
              ),
            ),
          ),
    ],
  );
}

/// `HiveRailItem`: collapsed and expanded, active and inactive, every state.
WidgetbookComponent railItemComponent() {
  return WidgetbookComponent(
    name: 'HiveRailItem',
    useCases: <WidgetbookUseCase>[
      for (final expanded in <bool>[false, true])
        for (final selected in <bool>[false, true])
          for (final state in PreviewState.values)
            WidgetbookUseCase(
              name:
                  '${expanded ? 'Expanded' : 'Collapsed'} · '
                  '${selected ? 'Active' : 'Inactive'} · ${state.label}',
              builder: (context) => UseCaseFrame(
                child: SizedBox(
                  width: expanded ? context.hiveSpacing.space8 * 4 : null,
                  child: StatesPreview(
                    states: state.states,
                    builder: (controller) => HiveRailItem(
                      icon: HiveIcons.workflows,
                      label: 'Workflows',
                      selected: selected,
                      expanded: expanded,
                      statesController: controller,
                      onPressed: state.isDisabled ? null : _noop,
                    ),
                  ),
                ),
              ),
            ),
      for (final expanded in <bool>[false, true])
        for (final selected in <bool>[false, true])
          for (final count in <int>[3, 128])
            WidgetbookUseCase(
              name:
                  '${expanded ? 'Expanded' : 'Collapsed'} · '
                  '${selected ? 'Active' : 'Inactive'} · Badge '
                  '${HiveRailItem.badgeText(count)}',
              builder: (context) => UseCaseFrame(
                child: SizedBox(
                  width: expanded ? context.hiveSpacing.space8 * 4 : null,
                  child: HiveRailItem(
                    icon: HiveIcons.pauses,
                    label: 'Pauses',
                    semanticLabel: 'Pauses, $count pending',
                    badgeCount: count,
                    selected: selected,
                    expanded: expanded,
                    onPressed: _noop,
                  ),
                ),
              ),
            ),
    ],
  );
}

/// The shell destinations used by the rail use cases.
const List<HiveRailDestination> railDestinations = <HiveRailDestination>[
  HiveRailDestination(icon: HiveIcons.overview, label: 'Overview'),
  HiveRailDestination(icon: HiveIcons.workflows, label: 'Workflows'),
  HiveRailDestination(icon: HiveIcons.runs, label: 'Runs'),
  HiveRailDestination(icon: HiveIcons.pauses, label: 'Pauses'),
  HiveRailDestination(icon: HiveIcons.agents, label: 'Agents'),
  HiveRailDestination(icon: HiveIcons.harnesses, label: 'Harnesses'),
  HiveRailDestination(icon: HiveIcons.settings, label: 'Settings'),
];

/// [railDestinations] with three pending pauses on the Pauses destination.
const List<HiveRailDestination> railDestinationsWithBadge =
    <HiveRailDestination>[
      HiveRailDestination(icon: HiveIcons.overview, label: 'Overview'),
      HiveRailDestination(icon: HiveIcons.workflows, label: 'Workflows'),
      HiveRailDestination(icon: HiveIcons.runs, label: 'Runs'),
      HiveRailDestination(
        icon: HiveIcons.pauses,
        label: 'Pauses',
        badgeCount: 3,
        semanticLabel: 'Pauses, 3 pending',
      ),
      HiveRailDestination(icon: HiveIcons.agents, label: 'Agents'),
      HiveRailDestination(icon: HiveIcons.harnesses, label: 'Harnesses'),
      HiveRailDestination(icon: HiveIcons.settings, label: 'Settings'),
    ];

/// `HiveSideRail`: collapsed, expanded and an interactive shell.
WidgetbookComponent sideRailComponent() {
  Widget rail(
    BuildContext context, {
    required bool expanded,
    List<HiveRailDestination> destinations = railDestinations,
  }) {
    return Padding(
      padding: EdgeInsets.all(context.hiveSpacing.space2),
      child: SizedBox(
        height: context.hiveSpacing.space8 * 10,
        child: HiveSideRail(
          destinations: destinations,
          selectedIndex: 1,
          onSelected: (_) {},
          initiallyExpanded: expanded,
          markLabel: 'Agentic Hive',
          expandLabel: 'Expand navigation',
          collapseLabel: 'Collapse navigation',
        ),
      ),
    );
  }

  return WidgetbookComponent(
    name: 'HiveSideRail',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Collapsed (default)',
        builder: (context) => Align(
          alignment: Alignment.centerLeft,
          child: rail(context, expanded: false),
        ),
      ),
      WidgetbookUseCase(
        name: 'Expanded',
        builder: (context) => Align(
          alignment: Alignment.centerLeft,
          child: rail(context, expanded: true),
        ),
      ),
      WidgetbookUseCase(
        name: 'Collapsed · Pauses badge',
        builder: (context) => Align(
          alignment: Alignment.centerLeft,
          child: rail(
            context,
            expanded: false,
            destinations: railDestinationsWithBadge,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Expanded · Pauses badge',
        builder: (context) => Align(
          alignment: Alignment.centerLeft,
          child: rail(
            context,
            expanded: true,
            destinations: railDestinationsWithBadge,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Interactive shell',
        builder: (context) => const _RailShell(),
      ),
    ],
  );
}

class _RailShell extends StatefulWidget {
  const new();

  @override
  State<_RailShell> createState() => _RailShellState();
}

/// `HiveTitleBar`: restored and maximized states.
WidgetbookComponent titleBarComponent() {
  Widget frame({required bool isMaximized}) {
    return UseCaseFrame(
      child: SizedBox(
        width: 720,
        child: HiveTitleBar(
          isMaximized: isMaximized,
          minimizeLabel: 'Minimize',
          maximizeLabel: 'Maximize',
          restoreLabel: 'Restore',
          closeLabel: 'Close to tray',
          onMinimize: _noop,
          onToggleMaximize: _noop,
          onClose: _noop,
        ),
      ),
    );
  }

  return WidgetbookComponent(
    name: 'HiveTitleBar',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Title bar · Restored',
        builder: (context) => frame(isMaximized: false),
      ),
      WidgetbookUseCase(
        name: 'Title bar · Maximized',
        builder: (context) => frame(isMaximized: true),
      ),
    ],
  );
}

class _RailShellState extends State<_RailShell> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    final destination = railDestinations[_selected];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(spacing.space2),
          child: HiveSideRail(
            destinations: railDestinations,
            selectedIndex: _selected,
            onSelected: (i) => setState(() => _selected = i),
            markLabel: 'Agentic Hive',
            expandLabel: 'Expand navigation',
            collapseLabel: 'Collapse navigation',
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(spacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                HivePageHeader(title: destination.label),
                Expanded(
                  child: HiveEmptyState(
                    icon: destination.icon,
                    title: 'Nothing in ${destination.label} yet',
                    message:
                        'This area is a placeholder until its feature '
                        'lands.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
