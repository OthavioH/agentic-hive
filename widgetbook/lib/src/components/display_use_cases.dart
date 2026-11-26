import 'dart:async';

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
  HiveNodeStatus.interrupted: 'Interrupted',
  HiveNodeStatus.cancelled: 'Cancelled',
  HiveNodeStatus.cancelling: 'Cancelling',
  HiveNodeStatus.cancellationUncertain: 'Cancellation uncertain',
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

/// `HiveMetricTile`: both sizes, every tone, both surfaces, long text and an
/// Overview-style row with one focal number.
WidgetbookComponent metricTileComponent() {
  WidgetbookUseCase useCase(String name, HiveMetricTile tile) {
    return WidgetbookUseCase(
      name: name,
      builder: (context) => UseCaseFrame(child: tile),
    );
  }

  return WidgetbookComponent(
    name: 'HiveMetricTile',
    useCases: <WidgetbookUseCase>[
      useCase(
        'Focal',
        const HiveMetricTile(
          value: '12',
          label: 'Active runs',
          size: HiveMetricTileSize.focal,
        ),
      ),
      useCase(
        'Compact',
        const HiveMetricTile(value: '48', label: 'Runs this week'),
      ),
      for (final tone in HiveFeedbackTone.values) ...<WidgetbookUseCase>[
        useCase(
          'Focal, ${tone.name} tone',
          HiveMetricTile(
            value: '3',
            label: 'Pending pauses',
            size: HiveMetricTileSize.focal,
            tone: tone,
          ),
        ),
        useCase(
          'Compact, ${tone.name} tone',
          HiveMetricTile(value: '3', label: 'Pending pauses', tone: tone),
        ),
      ],
      WidgetbookUseCase(
        name: 'On surface2',
        builder: (context) => const UseCaseFrame(
          child: HiveCard(
            child: HiveMetricTile(
              value: '7',
              label: 'Failed runs',
              tone: HiveFeedbackTone.danger,
              surface: HiveCardSurface.surface2,
              semanticLabel: 'Failed runs: 7, needs attention',
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Long value and label',
        builder: (context) => UseCaseFrame(
          child: SizedBox(
            width: context.hiveSpacing.space8 * 3,
            child: const HiveMetricTile(
              value: '1,284,356',
              label: 'Harness output lines streamed in the last seven days',
              size: HiveMetricTileSize.focal,
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Overview row',
        builder: (context) {
          final spacing = context.hiveSpacing;
          return UseCaseFrame(
            child: IntrinsicHeight(
              child: Row(
                spacing: spacing.space2,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const <Widget>[
                  Expanded(
                    flex: 2,
                    child: HiveMetricTile(
                      value: '12',
                      label: 'Active runs',
                      size: HiveMetricTileSize.focal,
                    ),
                  ),
                  Expanded(
                    child: HiveMetricTile(
                      value: '3',
                      label: 'Pending pauses',
                      tone: HiveFeedbackTone.warning,
                    ),
                  ),
                  Expanded(
                    child: HiveMetricTile(
                      value: '1',
                      label: 'Failed today',
                      tone: HiveFeedbackTone.danger,
                    ),
                  ),
                  Expanded(
                    child: HiveMetricTile(
                      value: '41',
                      label: 'Succeeded today',
                      tone: HiveFeedbackTone.success,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}

/// `HiveDiffStat`: typical, zero counts, only one kind, large counts.
WidgetbookComponent diffStatComponent() {
  WidgetbookUseCase useCase(String name, HiveDiffStat stat) {
    return WidgetbookUseCase(
      name: name,
      builder: (context) => UseCaseFrame(child: stat),
    );
  }

  return WidgetbookComponent(
    name: 'HiveDiffStat',
    useCases: <WidgetbookUseCase>[
      useCase(
        'Mixed changes',
        const HiveDiffStat(added: 12, modified: 3, deleted: 1),
      ),
      useCase(
        'No changes',
        const HiveDiffStat(added: 0, modified: 0, deleted: 0),
      ),
      useCase(
        'Only added',
        const HiveDiffStat(added: 7, modified: 0, deleted: 0),
      ),
      useCase(
        'Only modified',
        const HiveDiffStat(added: 0, modified: 4, deleted: 0),
      ),
      useCase(
        'Only deleted',
        const HiveDiffStat(added: 0, modified: 0, deleted: 9),
      ),
      useCase(
        'Large counts',
        const HiveDiffStat(added: 1284, modified: 356, deleted: 1027),
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
      WidgetbookUseCase(
        name: 'Compact',
        builder: (context) => const HiveEmptyState(
          icon: HiveIcons.harnesses,
          title: 'Fallback harnesses',
          message: 'No fallback. The node fails on a rate limit.',
          compact: true,
          action: HiveButton(
            label: 'Add fallback',
            icon: HiveIcons.add,
            variant: HiveButtonVariant.secondary,
            onPressed: _noop,
          ),
        ),
      ),
    ],
  );
}

const String _checkpointPayload = '''
{
  "runId": "run_01JD7Q8M4K",
  "nodeId": "review_pull_request",
  "sequence": 42,
  "status": "interrupted",
  "reason": "The backend restarted while Claude Code was running.",
  "outputs": {
    "summary": "Reviewed 12 of 14 changed files before the restart; resume continues from src/engine/scheduler.dart.",
    "filesReviewed": ["src/engine/run.dart", "src/engine/scheduler.dart"]
  }
}''';

/// `HiveCodeBlock`: titled with copy, plain, capped height, empty payload.
WidgetbookComponent codeBlockComponent() {
  String entry(int i) =>
      '  {"sequence": $i, "type": "node.output", "nodeId": "run_tests", '
      '"line": "test/engine/scheduler_test.dart: resumes from checkpoint '
      '$i of 40 without re-running completed nodes"},';
  final longPayload = <String>[
    '[',
    for (var i = 1; i <= 40; i++) entry(i),
    ']',
  ].join('\n');
  Widget frame(BuildContext context, Widget child) => UseCaseFrame(
    child: SizedBox(width: context.hiveSpacing.space8 * 8, child: child),
  );
  return WidgetbookComponent(
    name: 'HiveCodeBlock',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Title and copy',
        builder: (context) => frame(
          context,
          const HiveCodeBlock(
            code: _checkpointPayload,
            title: 'Checkpoint 42 · state',
            copyLabel: 'Copy checkpoint state',
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Plain',
        builder: (context) =>
            frame(context, const HiveCodeBlock(code: _checkpointPayload)),
      ),
      WidgetbookUseCase(
        name: 'Max height · Scrolls both ways',
        builder: (context) => frame(
          context,
          HiveCodeBlock(
            code: longPayload,
            title: 'Event log · run_tests',
            copyLabel: 'Copy event log',
            maxHeight: context.hiveSpacing.space8 * 4,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Empty payload',
        builder: (context) => frame(
          context,
          const HiveCodeBlock(
            code: '',
            title: 'Event payload',
            emptyLabel: 'This event has no payload.',
          ),
        ),
      ),
    ],
  );
}

const List<HiveLogLine> _harnessOutput = <HiveLogLine>[
  HiveLogLine(r'$ claude --print --output-format stream-json < prompt.md'),
  HiveLogLine('Reading workspace: 214 files, 3 ignored by .gitignore'),
  HiveLogLine('Planning: review src/engine/scheduler.dart and its tests'),
  HiveLogLine(
    'warning: CLAUDE.md not found in workspace root',
    stream: HiveLogStream.stderr,
  ),
  HiveLogLine('Running: dart test test/engine/scheduler_test.dart'),
  HiveLogLine('00:03 +41: All tests passed!'),
  HiveLogLine(
    'Error: tool call "Bash" timed out after 120000 ms '
    '(dart analyze --fatal-infos lib/src/engine/scheduler.dart)',
    stream: HiveLogStream.stderr,
  ),
  HiveLogLine('Retrying with a 600000 ms timeout'),
  HiveLogLine('Analyzing lib/src/engine... No issues found!'),
  HiveLogLine('report_result: succeeded (12 files reviewed, 2 comments)'),
];

const List<(String, HiveLogStream)> _liveChunks = <(String, HiveLogStream)>[
  ('Resolving dependencies', HiveLogStream.stdout),
  ('...\nDownloading packages: 37 of 112\n', HiveLogStream.stdout),
  ('Downloading packages: 112 of 112\n', HiveLogStream.stdout),
  ('Compiling test/engine/', HiveLogStream.stdout),
  ('scheduler_test.dart\n', HiveLogStream.stdout),
  ('00:01 +12: resumes from checkpoint\n', HiveLogStream.stdout),
  (
    'Deprecated: --reporter=compact, use --reporter=expanded\n',
    HiveLogStream.stderr,
  ),
  ('00:02 +27: cancels the process tree\n', HiveLogStream.stdout),
  ('00:03 +41: All tests passed!\n', HiveLogStream.stdout),
];

/// `HiveLogStreamViewer`: mixed streams, live output with auto-scroll and
/// Jump to bottom, stderr only, long lines, and empty.
WidgetbookComponent logStreamViewerComponent() {
  Widget frame(BuildContext context, Widget child) => UseCaseFrame(
    child: SizedBox(
      width: context.hiveSpacing.space8 * 8,
      height: context.hiveSpacing.space8 * 5,
      child: child,
    ),
  );
  Widget viewer(HiveLogStreamController controller) => HiveLogStreamViewer(
    controller: controller,
    semanticLabel: 'Harness output',
    jumpToBottomLabel: 'Jump to bottom',
    stderrSemanticLabel: 'Error',
    emptyLabel: 'No output yet. The harness has not written anything.',
  );
  return WidgetbookComponent(
    name: 'HiveLogStreamViewer',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Mixed stdout and stderr',
        builder: (context) => frame(
          context,
          _ControllerHost(
            seed: (c) => c.appendLines(_harnessOutput),
            builder: viewer,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Live · Scroll up to pause',
        builder: (context) => frame(
          context,
          _ControllerHost(
            seed: (c) => c.appendLines(<HiveLogLine>[
              for (var i = 0; i < 4; i++) ..._harnessOutput,
            ]),
            live: true,
            builder: viewer,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Only stderr',
        builder: (context) => frame(
          context,
          _ControllerHost(
            seed: (c) => c
              ..append(
                'Error: Claude Code is not signed in on this machine.\n',
                stream: HiveLogStream.stderr,
              )
              ..append(
                'Run `claude login` in a terminal, then retry the run.\n',
                stream: HiveLogStream.stderr,
              ),
            builder: viewer,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Long lines wrap',
        builder: (context) => frame(
          context,
          _ControllerHost(
            seed: (c) => c
              ..append(
                'test/engine/scheduler_test.dart: resumes from checkpoint 42 '
                'of 40 without re-running completed nodes, then cancels the '
                'process tree and waits for every child process to exit\n',
              )
              ..append(
                'Unhandled exception: ProcessException: The system cannot '
                'find the file specified. Command: '
                r'C:\Users\dev\AppData\Local\Programs\claude\claude.exe '
                '--print --output-format stream-json\n',
                stream: HiveLogStream.stderr,
              ),
            builder: viewer,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Empty',
        builder: (context) =>
            frame(context, _ControllerHost(seed: (_) {}, builder: viewer)),
      ),
    ],
  );
}

/// Owns a [HiveLogStreamController] for a use case; with [live] it appends
/// [_liveChunks] (split mid-line) on a timer, forever.
class _ControllerHost extends StatefulWidget {
  const new({required this.seed, required this.builder, this.live = false});

  final void Function(HiveLogStreamController controller) seed;
  final Widget Function(HiveLogStreamController controller) builder;
  final bool live;

  @override
  State<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState extends State<_ControllerHost> {
  late final HiveLogStreamController _controller = HiveLogStreamController(
    maxLines: 2000,
  );
  Timer? _timer;
  var _next = 0;

  @override
  void initState() {
    super.initState();
    widget.seed(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.live) {
      _timer ??= Timer.periodic(context.hiveMotion.long * 2, (_) {
        final (chunk, stream) = _liveChunks[_next % _liveChunks.length];
        _next++;
        _controller.append(chunk, stream: stream);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}
