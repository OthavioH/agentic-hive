import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

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
