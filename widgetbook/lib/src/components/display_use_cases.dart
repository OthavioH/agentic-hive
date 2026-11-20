import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

const Map<HiveNodeStatus, String> _statusLabels = <HiveNodeStatus, String>{
  HiveNodeStatus.idle: 'Idle',
  HiveNodeStatus.running: 'Running',
  HiveNodeStatus.paused: 'Paused',
  HiveNodeStatus.failed: 'Failed',
  HiveNodeStatus.succeeded: 'Succeeded',
};

const Map<String, NodeVisual> _harnessVisuals = <String, NodeVisual>{
  'Claude Code': NodeVisual(
    icon: HiveIcons.harnessClaudeCode,
    labelKey: 'nodeTypeClaudeCode',
  ),
  'Codex': NodeVisual(icon: HiveIcons.harnessCodex, labelKey: 'nodeTypeCodex'),
  'Gemini CLI': NodeVisual(
    icon: HiveIcons.harnessGeminiCli,
    labelKey: 'nodeTypeGeminiCli',
  ),
  'Antigravity': NodeVisual(
    icon: HiveIcons.harnessAntigravity,
    labelKey: 'nodeTypeAntigravity',
  ),
  'Terminal': NodeVisual(
    icon: HiveIcons.harnessTerminal,
    labelKey: 'nodeTypeTerminal',
  ),
};

/// `HiveBadge`: every tone, with and without icon, long label.
WidgetbookComponent badgeComponent() {
  const toneLabels = <HiveBadgeTone, String>{
    HiveBadgeTone.neutral: 'Draft',
    HiveBadgeTone.accentMuted: 'Running',
    HiveBadgeTone.success: 'Passed',
    HiveBadgeTone.warning: 'Waiting for approval',
    HiveBadgeTone.danger: 'Auth error',
    HiveBadgeTone.info: 'Resumed',
  };
  const toneIcons = <HiveBadgeTone, HiveIconData>{
    HiveBadgeTone.neutral: HiveIcons.edit,
    HiveBadgeTone.accentMuted: HiveIcons.play,
    HiveBadgeTone.success: HiveIcons.check,
    HiveBadgeTone.warning: HiveIcons.pause,
    HiveBadgeTone.danger: HiveIcons.alert,
    HiveBadgeTone.info: HiveIcons.refresh,
  };
  return WidgetbookComponent(
    name: 'HiveBadge',
    useCases: <WidgetbookUseCase>[
      for (final tone in HiveBadgeTone.values) ...<WidgetbookUseCase>[
        WidgetbookUseCase(
          name: '${tone.name} · Text',
          builder: (context) => UseCaseFrame(
            child: HiveBadge(label: toneLabels[tone]!, tone: tone),
          ),
        ),
        WidgetbookUseCase(
          name: '${tone.name} · Icon',
          builder: (context) => UseCaseFrame(
            child: HiveBadge(
              label: toneLabels[tone]!,
              tone: tone,
              icon: toneIcons[tone],
            ),
          ),
        ),
      ],
      WidgetbookUseCase(
        name: 'Long label',
        builder: (context) => UseCaseFrame(
          child: SizedBox(
            width: context.hiveSpacing.space8 * 2,
            child: const HiveBadge(
              label: 'Claude Code is not signed in on this machine',
              tone: HiveBadgeTone.danger,
              icon: HiveIcons.alert,
            ),
          ),
        ),
      ),
    ],
  );
}

/// `HiveStatusDot`: every status and the full legend.
WidgetbookComponent statusDotComponent() {
  return WidgetbookComponent(
    name: 'HiveStatusDot',
    useCases: <WidgetbookUseCase>[
      for (final status in HiveNodeStatus.values)
        WidgetbookUseCase(
          name: _statusLabels[status]!,
          builder: (context) => UseCaseFrame(
            child: HiveStatusDot(
              status: status,
              semanticLabel: _statusLabels[status]!,
              size: context.hiveSpacing.space4,
            ),
          ),
        ),
      WidgetbookUseCase(
        name: 'Legend',
        builder: (context) => UseCaseFrame(
          child: ShowcaseSection(
            title: 'Shape plus color per status',
            children: <Widget>[
              for (final status in HiveNodeStatus.values)
                Labeled(
                  label: _statusLabels[status]!,
                  child: HiveStatusDot(
                    status: status,
                    semanticLabel: _statusLabels[status]!,
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// `HiveAgentAvatar`: every harness face, every status and size.
WidgetbookComponent agentAvatarComponent() {
  return WidgetbookComponent(
    name: 'HiveAgentAvatar',
    useCases: <WidgetbookUseCase>[
      for (final e in _harnessVisuals.entries)
        WidgetbookUseCase(
          name: '${e.key} · No status',
          builder: (context) => UseCaseFrame(
            child: HiveAgentAvatar(visual: e.value, semanticLabel: e.key),
          ),
        ),
      for (final status in HiveNodeStatus.values)
        WidgetbookUseCase(
          name: 'Claude Code · ${_statusLabels[status]}',
          builder: (context) => UseCaseFrame(
            child: HiveAgentAvatar(
              visual: _harnessVisuals['Claude Code']!,
              semanticLabel: 'Claude Code',
              status: status,
              statusLabel: _statusLabels[status],
            ),
          ),
        ),
      WidgetbookUseCase(
        name: 'Sizes',
        builder: (context) => UseCaseFrame(
          child: ShowcaseSection(
            title: 'Sizes',
            children: <Widget>[
              for (final size in HiveAvatarSize.values)
                Labeled(
                  label: size.name,
                  child: HiveAgentAvatar(
                    visual: _harnessVisuals['Codex']!,
                    semanticLabel: 'Codex',
                    status: HiveNodeStatus.running,
                    statusLabel: 'Running',
                    size: size,
                  ),
                ),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Agent card composition',
        builder: (context) => UseCaseFrame(
          child: SizedBox(
            width: context.hiveSpacing.space8 * 5,
            child: HiveCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  HiveAgentAvatar(
                    visual: _harnessVisuals['Gemini CLI']!,
                    semanticLabel: 'Gemini CLI',
                    status: HiveNodeStatus.paused,
                    statusLabel: 'Paused',
                  ),
                  SizedBox(width: context.hiveSpacing.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Review pull request',
                          style: context.hiveTypography.labelLarge,
                        ),
                        Text(
                          'Gemini CLI · asking a question',
                          style: context.hiveTypography.bodySmall.copyWith(
                            color: context.hiveColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.hiveSpacing.space1),
                  const HiveBadge(label: 'Paused', tone: HiveBadgeTone.warning),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// `HiveConnectionIndicator`: every state.
WidgetbookComponent connectionIndicatorComponent() {
  const labels = <HiveConnectionState, String>{
    HiveConnectionState.connected: 'Connected to backend',
    HiveConnectionState.connecting: 'Connecting to backend',
    HiveConnectionState.disconnected: 'Backend not responding',
  };
  return WidgetbookComponent(
    name: 'HiveConnectionIndicator',
    useCases: <WidgetbookUseCase>[
      for (final state in HiveConnectionState.values)
        WidgetbookUseCase(
          name: state.name,
          builder: (context) => UseCaseFrame(
            child: HiveConnectionIndicator(state: state, label: labels[state]!),
          ),
        ),
    ],
  );
}

/// `HiveHexMark`: sizes.
WidgetbookComponent hexMarkComponent() {
  return WidgetbookComponent(
    name: 'HiveHexMark',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => const UseCaseFrame(
          child: HiveHexMark(semanticLabel: 'Agentic Hive'),
        ),
      ),
      WidgetbookUseCase(
        name: 'Sizes',
        builder: (context) {
          final spacing = context.hiveSpacing;
          return UseCaseFrame(
            child: ShowcaseSection(
              title: 'Sizes',
              children: <Widget>[
                for (final e in <String, double>{
                  'space3': spacing.space3,
                  'space5': spacing.space5,
                  'space8': spacing.space8,
                }.entries)
                  Labeled(
                    label: e.key,
                    child: HiveHexMark(
                      semanticLabel: 'Agentic Hive',
                      size: e.value,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

/// `HivePageHeader`: title, subtitle, actions, long title.
WidgetbookComponent pageHeaderComponent() {
  Widget frame(BuildContext context, Widget child) => Padding(
    padding: EdgeInsets.all(context.hiveSpacing.space4),
    child: Align(alignment: Alignment.topLeft, child: child),
  );
  return WidgetbookComponent(
    name: 'HivePageHeader',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Title only',
        builder: (context) =>
            frame(context, const HivePageHeader(title: 'Workflows')),
      ),
      WidgetbookUseCase(
        name: 'With subtitle',
        builder: (context) => frame(
          context,
          const HivePageHeader(
            title: 'Runs',
            subtitle: 'Runs keep going when the window is closed.',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'With actions',
        builder: (context) => frame(
          context,
          const HivePageHeader(
            title: 'Workflows',
            subtitle: '4 workflows',
            actions: <Widget>[
              HiveIconButton(
                icon: HiveIcons.search,
                semanticLabel: 'Search workflows',
                onPressed: _noop,
              ),
              HiveButton(
                label: 'New workflow',
                icon: HiveIcons.add,
                onPressed: _noop,
              ),
            ],
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Long title',
        builder: (context) => frame(
          context,
          SizedBox(
            width: context.hiveSpacing.space8 * 6,
            child: const HivePageHeader(
              title:
                  'Release checklist for the desktop app with signed '
                  'installers on Windows, Linux and macOS',
              subtitle:
                  'Created from the release template; edits apply to new '
                  'runs only.',
            ),
          ),
        ),
      ),
    ],
  );
}

/// `HiveEmptyState`: with and without action, long message.
WidgetbookComponent emptyStateComponent() {
  return WidgetbookComponent(
    name: 'HiveEmptyState',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'With action',
        builder: (context) => const HiveEmptyState(
          icon: HiveIcons.workflows,
          title: 'No workflows yet',
          message: 'Create a workflow to chain agents, commands and checks.',
          action: HiveButton(
            label: 'New workflow',
            icon: HiveIcons.add,
            onPressed: _noop,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Without action',
        builder: (context) => const HiveEmptyState(
          icon: HiveIcons.inbox,
          title: 'No pauses',
          message: 'Approvals and agent questions show up here.',
        ),
      ),
      WidgetbookUseCase(
        name: 'Title only',
        builder: (context) =>
            const HiveEmptyState(icon: HiveIcons.runs, title: 'No active runs'),
      ),
      WidgetbookUseCase(
        name: 'Long message',
        builder: (context) => const HiveEmptyState(
          icon: HiveIcons.harnesses,
          title: 'No harnesses detected',
          message:
              'Install Claude Code, Codex, Gemini CLI or Antigravity and sign '
              'in from your terminal. Agentic Hive never stores harness '
              'credentials; it only checks whether each CLI is on your PATH '
              'and signed in.',
          action: HiveButton(
            label: 'Check again',
            icon: HiveIcons.refresh,
            variant: HiveButtonVariant.secondary,
            onPressed: _noop,
          ),
        ),
      ),
    ],
  );
}
