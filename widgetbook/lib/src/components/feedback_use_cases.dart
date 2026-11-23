import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

/// `HiveConfirmDialog`: delete and conflict dialogs inline, plus launchers
/// that open them through `showHiveConfirmDialog`.
WidgetbookComponent confirmDialogComponent() {
  return WidgetbookComponent(
    name: 'HiveConfirmDialog',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Destructive · Delete agent',
        builder: (context) => const UseCaseFrame(
          child: HiveConfirmDialog(
            title: 'Delete agent?',
            message:
                'code-reviewer.md will be removed from the agents folder. '
                'Workflows that use it will need another agent.',
            confirmLabel: 'Delete',
            cancelLabel: 'Cancel',
            tone: HiveConfirmTone.destructive,
            icon: HiveIcons.delete,
            onConfirm: _noop,
            onCancel: _noop,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Conflict · Changed on disk',
        builder: (context) => const UseCaseFrame(
          child: HiveConfirmDialog(
            title: 'Agent changed on disk',
            message:
                'code-reviewer.md was edited outside the app after you '
                'opened it. Overwrite it with your changes or reload the '
                'version on disk?',
            confirmLabel: 'Overwrite',
            cancelLabel: 'Cancel',
            secondaryLabel: 'Reload from disk',
            tone: HiveConfirmTone.destructive,
            icon: HiveIcons.alert,
            onConfirm: _noop,
            onSecondary: _noop,
            onCancel: _noop,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Standard',
        builder: (context) => const UseCaseFrame(
          child: HiveConfirmDialog(
            title: 'Insert the starter template?',
            message:
                'Responsibilities, Required inputs, Execution guidance and '
                'Outputs sections are added to the end of the prompt.',
            confirmLabel: 'Insert template',
            cancelLabel: 'Cancel',
            onConfirm: _noop,
            onCancel: _noop,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Open as modal',
        builder: (context) => const UseCaseFrame(child: _DialogLauncher()),
      ),
    ],
  );
}

class _DialogLauncher extends StatefulWidget {
  const new();

  @override
  State<_DialogLauncher> createState() => _DialogLauncherState();
}

class _DialogLauncherState extends State<_DialogLauncher> {
  HiveConfirmChoice? _last;

  Future<void> _open() async {
    final choice = await showHiveConfirmDialog(
      context,
      title: 'Delete agent?',
      message: 'code-reviewer.md will be removed from the agents folder.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      tone: HiveConfirmTone.destructive,
      icon: HiveIcons.delete,
    );
    if (mounted) setState(() => _last = choice);
  }

  @override
  Widget build(BuildContext context) {
    final last = _last;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HiveButton(
          label: 'Delete agent',
          icon: HiveIcons.delete,
          variant: HiveButtonVariant.secondary,
          onPressed: _open,
        ),
        if (last != null) ...<Widget>[
          SizedBox(height: context.hiveSpacing.space2),
          Text(
            'Last choice: ${last.name}',
            style: context.hiveTypography.mono.copyWith(
              color: context.hiveColors.onSurfaceMuted,
            ),
          ),
        ],
      ],
    );
  }
}

const Map<HiveFeedbackTone, (String, String)> _bannerCopy =
    <HiveFeedbackTone, (String, String)>{
      HiveFeedbackTone.info: (
        'Agent changed on disk',
        'code-reviewer.md was updated by another editor. Reload to see it.',
      ),
      HiveFeedbackTone.success: (
        'Agent saved',
        'code-reviewer.md was written to the agents folder.',
      ),
      HiveFeedbackTone.warning: (
        'Unsaved changes',
        'This agent was edited on disk while you have unsaved changes.',
      ),
      HiveFeedbackTone.danger: (
        'This agent could not be read',
        'Fix the YAML frontmatter in an editor or delete the file.',
      ),
    };

/// `HiveBanner`: every tone, with actions, dismiss and parse error detail.
WidgetbookComponent bannerComponent() {
  Widget sized(BuildContext context, Widget child) =>
      SizedBox(width: context.hiveSpacing.space8 * 8, child: child);
  return WidgetbookComponent(
    name: 'HiveBanner',
    useCases: <WidgetbookUseCase>[
      for (final tone in HiveFeedbackTone.values)
        WidgetbookUseCase(
          name: tone.name,
          builder: (context) => UseCaseFrame(
            child: sized(
              context,
              HiveBanner(
                tone: tone,
                title: _bannerCopy[tone]!.$1,
                message: _bannerCopy[tone]!.$2,
              ),
            ),
          ),
        ),
      WidgetbookUseCase(
        name: 'With actions and dismiss',
        builder: (context) => UseCaseFrame(
          child: sized(
            context,
            const HiveBanner(
              tone: HiveFeedbackTone.warning,
              title: 'Unsaved changes',
              message:
                  'This agent was edited on disk while you have unsaved '
                  'changes.',
              actions: <Widget>[
                HiveButton(
                  label: 'Reload from disk',
                  size: HiveButtonSize.small,
                  variant: HiveButtonVariant.secondary,
                  onPressed: _noop,
                ),
                HiveButton(
                  label: 'Keep editing',
                  size: HiveButtonSize.small,
                  variant: HiveButtonVariant.ghost,
                  onPressed: _noop,
                ),
              ],
              onDismiss: _noop,
              dismissSemanticLabel: 'Dismiss',
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Parse error detail',
        builder: (context) => UseCaseFrame(
          child: sized(
            context,
            HiveBanner(
              tone: HiveFeedbackTone.danger,
              title: 'This agent could not be read',
              message: 'broken-agent.md has invalid YAML frontmatter.',
              detail: Text(
                'Error on line 3, column 7: Mapping values are not '
                'allowed here.\n  tags: [review\n        ^',
                style: context.hiveTypography.mono.copyWith(
                  color: context.hiveColors.onSurface,
                ),
              ),
              actions: const <Widget>[
                HiveButton(
                  label: 'Delete file',
                  icon: HiveIcons.delete,
                  size: HiveButtonSize.small,
                  variant: HiveButtonVariant.secondary,
                  onPressed: _noop,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

const Map<HiveToastTone, String> _toneMessages = <HiveToastTone, String>{
  HiveToastTone.neutral: 'Path copied',
  HiveToastTone.success: 'Claude Code is ready',
  HiveToastTone.warning: 'Codex is outdated',
  HiveToastTone.danger: 'Gemini CLI is not signed in',
  HiveToastTone.info: 'Re-checking every harness',
};

/// `HiveToast`: every tone with its default icon and a custom icon, long
/// text, a live trigger and a playground.
WidgetbookComponent toastComponent() {
  return WidgetbookComponent(
    name: 'HiveToast',
    useCases: <WidgetbookUseCase>[
      for (final tone in HiveToastTone.values) ...<WidgetbookUseCase>[
        WidgetbookUseCase(
          name: '${tone.name} · Default icon',
          builder: (context) => UseCaseFrame(
            child: HiveToast(message: _toneMessages[tone]!, tone: tone),
          ),
        ),
        WidgetbookUseCase(
          name: '${tone.name} · Custom icon',
          builder: (context) => UseCaseFrame(
            child: HiveToast(
              message: _toneMessages[tone]!,
              tone: tone,
              icon: HiveIcons.copy,
            ),
          ),
        ),
      ],
      WidgetbookUseCase(
        name: 'Long message',
        builder: (context) => const UseCaseFrame(
          child: HiveToast(
            message:
                'Copied the workspace path of the release checklist run: '
                '/home/dev/.local/share/agentic-hive/workspaces/release',
            icon: HiveIcons.copy,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Live',
        builder: (context) => UseCaseFrame(
          child: _ToastTrigger(
            message: context.knobs.string(
              label: 'Message',
              initialValue: 'Path copied',
            ),
            tone: context.knobs.object.dropdown<HiveToastTone>(
              label: 'Tone',
              options: HiveToastTone.values,
              labelBuilder: (v) => v.name,
            ),
          ),
        ),
      ),
    ],
  );
}

/// A button that shows a toast, so the entrance, display time, hover pause
/// and exit can be reviewed.
class _ToastTrigger extends StatelessWidget {
  const new({required this.message, required this.tone});

  final String message;
  final HiveToastTone tone;

  @override
  Widget build(BuildContext context) {
    return HiveButton(
      label: 'Copy path',
      icon: HiveIcons.copy,
      variant: HiveButtonVariant.secondary,
      onPressed: () => HiveToast.show(context, message: message, tone: tone),
    );
  }
}
