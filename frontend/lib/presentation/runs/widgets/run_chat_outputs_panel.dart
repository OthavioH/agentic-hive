import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/use_cases/build_run_output_messages.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Chat-style list of the plain-text summaries nodes published during a run.
class RunChatOutputsPanel extends ConsumerWidget {
  /// Creates the panel for the run described by [detailState].
  const new({required this.detailState, super.key});

  /// Current run detail state; checkpoints carry the node outcome data.
  final RunDetailState detailState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final messages = ref.watch(buildRunOutputMessagesProvider)(
      checkpoints: detailState.checkpoints,
      nodes: detailState.run.workflowDefinition.nodes,
    );

    return HiveCard(
      key: const Key('run_chat_outputs_panel'),
      surface: HiveCardSurface.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.runDetailOutputsTitle,
            style: typography.titleSmall.copyWith(color: colors.onSurface),
          ),
          SizedBox(height: spacing.space2),
          Expanded(
            child: messages.isEmpty
                ? HiveEmptyState(
                    key: const Key('run_chat_outputs_empty'),
                    icon: HiveIcons.branch,
                    title: l10n.runDetailOutputsTitle,
                    message: l10n.runDetailOutputsEmpty,
                  )
                : ListView.separated(
                    key: const Key('run_chat_outputs_list'),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(height: spacing.space2),
                    itemBuilder: (context, index) =>
                        _OutputMessageBubble(message: messages[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OutputMessageBubble extends StatelessWidget {
  const new({required this.message});

  final RunOutputMessage message;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    return HiveCard(
      key: Key('run_chat_output_${message.checkpointId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message.nodeLabel,
            key: Key('run_chat_output_label_${message.checkpointId}'),
            style: typography.label.copyWith(color: colors.accent),
          ),
          SizedBox(height: spacing.space1),
          SelectableText(
            message.text,
            key: Key('run_chat_output_text_${message.checkpointId}'),
            style: typography.body.copyWith(color: colors.onSurface),
          ),
        ],
      ),
    );
  }
}
