import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflows_list_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Child-workflow picker for `fan_out` node configuration.
class FanOutWorkflowSelectField extends ConsumerWidget {
  /// Creates a [FanOutWorkflowSelectField].
  const new({
    required this.selectKey,
    required this.workflowId,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  /// Key forwarded directly to the underlying [HiveSelect].
  final Key selectKey;

  /// Currently configured child workflow ID, or `null` / blank when unset.
  final String? workflowId;

  /// Called with the selected workflow ID.
  final ValueChanged<String> onChanged;

  /// Optional validation error passed by the parent form.
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workflowsAsync = ref.watch(workflowsListControllerProvider);
    final trimmed = workflowId?.trim();
    final currentId = (trimmed == null || trimmed.isEmpty) ? null : trimmed;

    return switch (workflowsAsync) {
      AsyncLoading<WorkflowsListState>() => HiveSelect<String>(
        key: selectKey,
        label: l10n.nodeConfigFanOutWorkflowLabel,
        hint: l10n.nodeConfigFanOutWorkflowLoadingHint,
        value: null,
        options: const <HiveSelectOption<String>>[],
        onChanged: null,
      ),
      AsyncError<WorkflowsListState>() => HiveSelect<String>(
        key: selectKey,
        label: l10n.nodeConfigFanOutWorkflowLabel,
        hint: l10n.nodeConfigFanOutWorkflowHint,
        errorText: l10n.nodeConfigFanOutWorkflowLoadError,
        value: currentId,
        options: currentId == null
            ? const <HiveSelectOption<String>>[]
            : <HiveSelectOption<String>>[
                HiveSelectOption<String>(value: currentId, label: currentId),
              ],
        onChanged: null,
      ),
      AsyncData<WorkflowsListState>(:final value) => _buildLoaded(
        l10n: l10n,
        workflows: value.workflows,
        currentId: currentId,
      ),
    };
  }

  Widget _buildLoaded({
    required AppLocalizations l10n,
    required List<WorkflowSummary> workflows,
    required String? currentId,
  }) {
    if (workflows.isEmpty && currentId == null) {
      return HiveSelect<String>(
        key: selectKey,
        label: l10n.nodeConfigFanOutWorkflowLabel,
        hint: l10n.nodeConfigFanOutWorkflowEmptyHint,
        value: null,
        options: const <HiveSelectOption<String>>[],
        onChanged: null,
      );
    }

    final hasSaved =
        currentId != null && workflows.any((w) => w.id == currentId);
    final isMissing = currentId != null && !hasSaved;

    final options = <HiveSelectOption<String>>[
      if (isMissing)
        HiveSelectOption<String>(value: currentId, label: currentId),
      for (final workflow in workflows)
        HiveSelectOption<String>(
          value: workflow.id,
          label: workflow.name.trim().isNotEmpty ? workflow.name : workflow.id,
        ),
    ];

    return HiveSelect<String>(
      key: selectKey,
      label: l10n.nodeConfigFanOutWorkflowLabel,
      hint: l10n.nodeConfigFanOutWorkflowHint,
      errorText: isMissing
          ? l10n.nodeConfigFanOutWorkflowMissingError(currentId)
          : errorText,
      value: currentId,
      options: options,
      onChanged: onChanged,
    );
  }
}
