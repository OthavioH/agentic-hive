import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/agents/controllers/agents_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Shared Agent Library picker for node configuration forms.
///
/// Watches [agentsControllerProvider] so it reflects live WebSocket updates
/// from the Agent Library, and handles loading, error, empty library, and
/// missing saved agent states without silently dropping [agentId].
class AgentLibrarySelectField extends ConsumerWidget {
  /// Creates an [AgentLibrarySelectField].
  const new({
    required this.selectKey,
    required this.agentId,
    required this.onChanged,
    super.key,
  });

  /// Key forwarded directly to the underlying [HiveSelect].
  final Key selectKey;

  /// Currently configured agent ID, or `null` when unassigned.
  final String? agentId;

  /// Called with the selected agent ID, or `null` when cleared.
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final agentsAsync = ref.watch(
      agentsControllerProvider.select((state) => state.agents),
    );
    final trimmed = agentId?.trim();
    final currentId = (trimmed == null || trimmed.isEmpty) ? null : trimmed;

    return switch (agentsAsync) {
      AsyncLoading<List<AgentSummary>>() => HiveSelect<String>(
        key: selectKey,
        label: l10n.nodeConfigAgentIdLabel,
        hint: l10n.nodeConfigAgentLoadingHint,
        value: null,
        options: const <HiveSelectOption<String>>[],
        onChanged: null,
      ),
      AsyncError<List<AgentSummary>>() => HiveSelect<String>(
        key: selectKey,
        label: l10n.nodeConfigAgentIdLabel,
        hint: l10n.nodeConfigAgentSelectHint,
        errorText: l10n.nodeConfigAgentLoadError,
        value: currentId,
        options: currentId == null
            ? const <HiveSelectOption<String>>[]
            : <HiveSelectOption<String>>[
                HiveSelectOption<String>(value: currentId, label: currentId),
              ],
        onChanged: null,
      ),
      AsyncData<List<AgentSummary>>(:final value) => _buildLoaded(
        l10n: l10n,
        agents: value,
        currentId: currentId,
      ),
    };
  }

  Widget _buildLoaded({
    required AppLocalizations l10n,
    required List<AgentSummary> agents,
    required String? currentId,
  }) {
    final validAgents = agents.where((a) => a.parseError == null).toList();
    final hasSavedAgent =
        currentId != null && validAgents.any((a) => a.id == currentId);
    final isMissing = currentId != null && !hasSavedAgent;

    if (validAgents.isEmpty && currentId == null) {
      return HiveSelect<String>(
        key: selectKey,
        label: l10n.nodeConfigAgentIdLabel,
        hint: l10n.nodeConfigAgentEmptyHint,
        value: null,
        options: const <HiveSelectOption<String>>[],
        onChanged: null,
      );
    }

    final options = <HiveSelectOption<String>>[
      if (isMissing)
        HiveSelectOption<String>(value: currentId, label: currentId),
      if (currentId != null)
        HiveSelectOption<String>(
          value: '',
          label: l10n.nodeConfigAgentNoneOption,
        ),
      for (final agent in validAgents)
        HiveSelectOption<String>(
          value: agent.id,
          label: agent.name.trim().isNotEmpty ? agent.name : agent.id,
        ),
    ];

    return HiveSelect<String>(
      key: selectKey,
      label: l10n.nodeConfigAgentIdLabel,
      hint: l10n.nodeConfigAgentSelectHint,
      helperText: validAgents.isEmpty && isMissing
          ? l10n.nodeConfigAgentEmptyHint
          : null,
      errorText: isMissing ? l10n.nodeConfigAgentMissingError(currentId) : null,
      value: currentId,
      options: options,
      onChanged: (picked) => onChanged(picked.isEmpty ? null : picked),
    );
  }
}
