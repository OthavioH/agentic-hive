import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agents_state.freezed.dart';

/// Notice shown when the currently open agent changed externally on disk.
enum ExternalChangeNotice {
  /// No external conflict or deletion detected.
  none,

  /// The open agent was modified on disk while the user had unsaved edits.
  modifiedExternally,

  /// The open agent was deleted on disk outside the app.
  deletedExternally,
}

/// Outcome of a save attempt from the agents controller.
sealed class SaveAgentOutcome {
  const new();
}

/// The agent was created or updated on disk.
final class SaveAgentSuccess extends SaveAgentOutcome {
  /// Creates a [SaveAgentSuccess].
  const new({required this.created});

  /// `true` when a new agent was created; `false` when an existing agent was
  /// updated.
  final bool created;
}

/// Saving failed with `409 Conflict` because the file changed on disk.
final class SaveAgentConflict extends SaveAgentOutcome {
  /// Creates a [SaveAgentConflict].
  const new(this.message);

  /// Backend conflict description.
  final String message;
}

/// Saving failed due to validation, transport, or backend error.
final class SaveAgentFailure extends SaveAgentOutcome {
  /// Creates a [SaveAgentFailure].
  const new(this.message);

  /// Human-readable error message.
  final String message;
}

/// Editable form state for creating or editing an agent.
@freezed
sealed class AgentDraft with _$AgentDraft {
  /// Creates an [AgentDraft].
  const factory({
    @Default('') String id,
    @Default(false) bool idManuallyEdited,
    @Default('') String name,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    @Default(<String>[]) List<String> requiredSkills,
    @Default(<String>[]) List<String> requiredTools,
    @Default(<String>[]) List<String> allowedTools,
    @Default(<String>[]) List<String> deniedTools,
    @Default('') String prompt,
    String? baseHash,
    String? parseError,
    String? rawContent,
  }) = _AgentDraft;

  /// Creates an [AgentDraft] from a loaded [AgentDetail].
  factory fromDetail(AgentDetail detail) => AgentDraft(
    id: detail.id,
    idManuallyEdited: true,
    name: detail.name,
    description: detail.description,
    tags: List<String>.unmodifiable(detail.tags),
    requiredSkills: List<String>.unmodifiable(detail.requiredSkills),
    requiredTools: List<String>.unmodifiable(detail.requiredTools),
    allowedTools: List<String>.unmodifiable(detail.allowedTools),
    deniedTools: List<String>.unmodifiable(detail.deniedTools),
    prompt: detail.prompt,
    baseHash: detail.contentHash,
    parseError: detail.parseError,
    rawContent: detail.rawContent,
  );
}

/// Full view state for the Agents library screen.
@immutable
final class AgentsState {
  /// Creates an [AgentsState].
  const new({
    this.agents = const AsyncLoading<List<AgentSummary>>(),
    this.searchQuery = '',
    this.selectedTags = const <String>{},
    this.selectedAgentId,
    this.isCreating = false,
    this.detail = const AsyncData<AgentDetail?>(null),
    this.draft,
    this.baselineDraft,
    this.isSaving = false,
    this.isDeleting = false,
    this.isPreviewMode = false,
    this.saveError,
    this.externalNotice = ExternalChangeNotice.none,
  });

  /// Loaded list of agent summaries.
  final AsyncValue<List<AgentSummary>> agents;

  /// Current search query filtering `id`, `name`, `description`, and `tags`.
  final String searchQuery;

  /// Active tag filter chips.
  final Set<String> selectedTags;

  /// ID of the currently selected existing agent, or `null`.
  final String? selectedAgentId;

  /// Whether the detail pane is creating a new agent inline.
  final bool isCreating;

  /// Loaded detail for [selectedAgentId].
  final AsyncValue<AgentDetail?> detail;

  /// Editable draft in the detail pane.
  final AgentDraft? draft;

  /// Baseline draft used to detect unsaved edits.
  final AgentDraft? baselineDraft;

  /// Whether a save request is in flight.
  final bool isSaving;

  /// Whether a delete request is in flight.
  final bool isDeleting;

  /// Whether the prompt editor is in Preview mode (`true`) or Raw (`false`).
  final bool isPreviewMode;

  /// Error message from the most recent failed save or delete.
  final String? saveError;

  /// External modification or deletion notice for the open agent.
  final ExternalChangeNotice externalNotice;

  /// Whether the current [draft] differs from [baselineDraft].
  bool get isDirty => draft != null && draft != baselineDraft;

  /// Whether the detail pane has an active agent or new draft open.
  bool get hasDetailOpen => isCreating || selectedAgentId != null;

  /// Sorted list of distinct tags present across all loaded agents.
  List<String> get availableTags {
    final list = agents.value ?? const <AgentSummary>[];
    final tagSet = <String>{};
    for (final agent in list) {
      tagSet.addAll(agent.tags);
    }
    final sorted = tagSet.toList()..sort();
    return sorted;
  }

  /// Agents matching [searchQuery] and [selectedTags].
  List<AgentSummary> get filteredAgents {
    final list = agents.value ?? const <AgentSummary>[];
    final query = searchQuery.trim().toLowerCase();
    return list.where((agent) {
      if (selectedTags.isNotEmpty && !selectedTags.every(agent.tags.contains)) {
        return false;
      }
      if (query.isEmpty) return true;
      return agent.id.toLowerCase().contains(query) ||
          agent.name.toLowerCase().contains(query) ||
          agent.description.toLowerCase().contains(query) ||
          agent.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  /// Returns a copy of this state with the provided fields updated.
  AgentsState copyWith({
    AsyncValue<List<AgentSummary>>? agents,
    String? searchQuery,
    Set<String>? selectedTags,
    String? Function()? selectedAgentId,
    bool? isCreating,
    AsyncValue<AgentDetail?>? detail,
    AgentDraft? Function()? draft,
    AgentDraft? Function()? baselineDraft,
    bool? isSaving,
    bool? isDeleting,
    bool? isPreviewMode,
    String? Function()? saveError,
    ExternalChangeNotice? externalNotice,
  }) => AgentsState(
    agents: agents ?? this.agents,
    searchQuery: searchQuery ?? this.searchQuery,
    selectedTags: selectedTags ?? this.selectedTags,
    selectedAgentId: selectedAgentId != null
        ? selectedAgentId()
        : this.selectedAgentId,
    isCreating: isCreating ?? this.isCreating,
    detail: detail ?? this.detail,
    draft: draft != null ? draft() : this.draft,
    baselineDraft: baselineDraft != null ? baselineDraft() : this.baselineDraft,
    isSaving: isSaving ?? this.isSaving,
    isDeleting: isDeleting ?? this.isDeleting,
    isPreviewMode: isPreviewMode ?? this.isPreviewMode,
    saveError: saveError != null ? saveError() : this.saveError,
    externalNotice: externalNotice ?? this.externalNotice,
  );
}
