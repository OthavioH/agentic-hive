import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

const String _stopTitle = 'Stop backend and quit?';
const String _stopMessage =
    '2 runs are in progress. Stopping the backend cancels them and closes '
    'Agentic Hive.';

List<Widget> _stopActions({VoidCallback? onCancel, VoidCallback? onConfirm}) {
  return <Widget>[
    HiveButton(
      label: 'Cancel',
      variant: HiveButtonVariant.ghost,
      autofocus: true,
      onPressed: onCancel ?? _noop,
    ),
    HiveButton(
      label: 'Stop backend',
      icon: HiveIcons.stop,
      onPressed: onConfirm ?? _noop,
    ),
  ];
}

/// `HiveDialog`: the Stop Backend & Quit confirmation, variants without icon
/// or message, custom content, long text and a live modal route.
WidgetbookComponent dialogComponent() {
  return WidgetbookComponent(
    name: 'HiveDialog',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Stop backend confirmation',
        builder: (context) => HiveDialog(
          title: _stopTitle,
          message: _stopMessage,
          icon: HiveIcons.alert,
          actions: _stopActions(),
        ),
      ),
      WidgetbookUseCase(
        name: 'Without icon',
        builder: (context) => const HiveDialog(
          title: 'Discard workflow changes?',
          message: 'Your edits to "Release checklist" have not been saved.',
          actions: <Widget>[
            HiveButton(
              label: 'Keep editing',
              variant: HiveButtonVariant.ghost,
              autofocus: true,
              onPressed: _noop,
            ),
            HiveButton(label: 'Discard', onPressed: _noop),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'Title only',
        builder: (context) => const HiveDialog(
          title: 'Quit Agentic Hive?',
          actions: <Widget>[
            HiveButton(
              label: 'Cancel',
              variant: HiveButtonVariant.ghost,
              autofocus: true,
              onPressed: _noop,
            ),
            HiveButton(label: 'Quit', onPressed: _noop),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'Custom content',
        builder: (context) => HiveDialog(
          title: _stopTitle,
          message: 'These runs are cancelled:',
          icon: HiveIcons.alert,
          content: Wrap(
            spacing: context.hiveSpacing.space1,
            runSpacing: context.hiveSpacing.space1,
            children: const <Widget>[
              HiveBadge(label: 'Review pull request'),
              HiveBadge(label: 'Nightly dependency update'),
            ],
          ),
          actions: _stopActions(),
        ),
      ),
      WidgetbookUseCase(
        name: 'Long message',
        builder: (context) => HiveDialog(
          title: 'Stop the backend while runs are still in progress?',
          message:
              '5 runs are in progress across 3 workflows, and 2 of them are '
              'waiting for your approval. Stopping the backend cancels every '
              'run, terminates the harness processes it started and closes '
              'Agentic Hive. Workspaces keep their files, but partial results '
              'are not reported. Choose Quit instead to close only the window '
              'and let the runs finish in the background.',
          icon: HiveIcons.alert,
          actions: _stopActions(),
        ),
      ),
      WidgetbookUseCase(
        name: 'Interactive (modal route)',
        builder: (context) => const UseCaseFrame(child: _DialogLauncher()),
      ),
      WidgetbookUseCase(
        name: 'Drop target · Idle',
        builder: (context) => const HiveDialog(
          title: 'Start run',
          content: HiveTextArea(
            label: 'Prompt',
            helperText: 'Paste or drop images to attach them.',
          ),
          dropCaption: 'Drop images to attach',
          actions: <Widget>[
            HiveButton(
              label: 'Cancel',
              variant: HiveButtonVariant.ghost,
              onPressed: _noop,
            ),
            HiveButton(label: 'Start', onPressed: _noop),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'Drop target · Drag over',
        builder: (context) => const HiveDialog(
          title: 'Start run',
          content: HiveTextArea(
            label: 'Prompt',
            helperText: 'Paste or drop images to attach them.',
          ),
          dropCaption: 'Drop images to attach',
          dropActive: true,
          actions: <Widget>[
            HiveButton(
              label: 'Cancel',
              variant: HiveButtonVariant.ghost,
              onPressed: _noop,
            ),
            HiveButton(label: 'Start', onPressed: _noop),
          ],
        ),
      ),
    ],
  );
}

/// `HiveDropZone`: idle and drag-over highlight states.
WidgetbookComponent dropZoneComponent() {
  return WidgetbookComponent(
    name: 'HiveDropZone',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Idle',
        builder: (context) => UseCaseFrame(
          child: SizedBox(
            width: context.hiveSpacing.space8 * 7,
            child: const HiveDropZone(
              active: false,
              caption: 'Drop images to attach',
              child: HiveInsetPanel(
                child: HiveTextArea(
                  label: 'Prompt',
                  helperText: 'Paste or drop images to attach them.',
                ),
              ),
            ),
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Drag over',
        builder: (context) => UseCaseFrame(
          child: SizedBox(
            width: context.hiveSpacing.space8 * 7,
            child: const HiveDropZone(
              active: true,
              caption: 'Drop images to attach',
              child: HiveInsetPanel(
                child: HiveTextArea(
                  label: 'Prompt',
                  helperText: 'Paste or drop images to attach them.',
                ),
              ),
            ),
          ),
        ),
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
  String _result = 'No choice yet';

  Future<void> _open() async {
    final confirmed = await showHiveDialog<bool>(
      context: context,
      barrierLabel: 'Dismiss',
      builder: (dialogContext) => HiveDialog(
        title: _stopTitle,
        message: _stopMessage,
        icon: HiveIcons.alert,
        actions: _stopActions(
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onConfirm: () => Navigator.of(dialogContext).pop(true),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _result = switch (confirmed) {
        true => 'Confirmed: stop backend',
        false => 'Cancelled',
        null => 'Dismissed',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HiveButton(
          label: 'Stop Backend & Quit',
          variant: HiveButtonVariant.secondary,
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
