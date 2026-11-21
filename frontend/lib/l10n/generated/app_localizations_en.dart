// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Agentic Hive';

  @override
  String get navOverview => 'Overview';

  @override
  String get navWorkflows => 'Workflows';

  @override
  String get navRuns => 'Runs';

  @override
  String get navPauses => 'Pauses';

  @override
  String get navAgents => 'Agents';

  @override
  String get navHarnesses => 'Harnesses';

  @override
  String get navSettings => 'Settings';

  @override
  String get railExpandTooltip => 'Expand navigation rail';

  @override
  String get railCollapseTooltip => 'Collapse navigation rail';

  @override
  String get overviewEmptyTitle => 'No activity yet';

  @override
  String get overviewEmptyDescription =>
      'Workflow runs, active agents, and pending pauses will appear here once you start running workflows.';

  @override
  String get workflowsEmptyTitle => 'No workflows yet';

  @override
  String get workflowsEmptyDescription =>
      'Create a workflow graph to orchestrate agents, validators, and approvals.';

  @override
  String get runsEmptyTitle => 'No runs yet';

  @override
  String get runsEmptyDescription =>
      'Start a workflow to monitor live execution, logs, and node checkpoints here.';

  @override
  String get pausesEmptyTitle => 'No pending pauses';

  @override
  String get pausesEmptyDescription =>
      'Human approval gates and review checkpoints waiting for your decision will appear here.';

  @override
  String get agentsEmptyTitle => 'No agents configured';

  @override
  String get agentsEmptyDescription =>
      'Define specialized agent roles and prompts to reuse across your workflows.';

  @override
  String get harnessesEmptyTitle => 'No harnesses detected';

  @override
  String get harnessesEmptyDescription =>
      'Connected CLI harnesses and their availability status will appear here.';

  @override
  String get settingsEmptyTitle => 'Settings';

  @override
  String get settingsEmptyDescription =>
      'Theme, workspace defaults, and backend connection preferences will be configured here.';

  @override
  String get connectingTitle => 'Connecting to backend';

  @override
  String get connectingSubtitle =>
      'Waiting for the local Agentic Hive backend service over the Unix domain socket.';

  @override
  String get connectingStatusConnecting => 'Connecting to backend...';

  @override
  String get connectingStatusDisconnected => 'Backend is not responding.';

  @override
  String get connectingRetryAction => 'Retry connection';

  @override
  String get connectingReasonNotRunningTitle => 'Backend is not running';

  @override
  String get connectingReasonNotRunningMessage =>
      'No active backend was found (server.json is missing). Start the Agentic Hive backend service and it will connect automatically.';

  @override
  String get connectingReasonRefusedTitle => 'Backend socket unreachable';

  @override
  String get connectingReasonRefusedMessage =>
      'The backend socket refused the connection or is stale. Waiting for the backend service to accept connections.';

  @override
  String get connectingReasonDegradedTitle => 'Backend is degraded';

  @override
  String get connectingReasonDegradedMessage =>
      'The backend is running, but a required dependency such as the database is unavailable. Retrying automatically.';

  @override
  String get connectingReasonProtocolMismatchTitle =>
      'Protocol version mismatch';

  @override
  String get connectingReasonProtocolMismatchMessage =>
      'This desktop app and the running backend use incompatible WebSocket protocol versions. Update the app or backend, then retry.';

  @override
  String get connectingReasonTimeoutTitle => 'Connection timed out';

  @override
  String get connectingReasonTimeoutMessage =>
      'The backend did not respond in time. Retrying automatically.';

  @override
  String get connectingReasonUnexpectedTitle => 'Unexpected connection error';

  @override
  String get connectingReasonUnexpectedMessage =>
      'An unexpected error occurred while connecting to the local backend.';

  @override
  String connectingNextRetryIn(int seconds) {
    return 'Retrying in ${seconds}s';
  }

  @override
  String get connectingAutoRetryHalted => 'Automatic retry paused';

  @override
  String connectingAttemptCount(int count) {
    return 'Attempt $count';
  }

  @override
  String get routeErrorTitle => 'Page not found';

  @override
  String get routeErrorDescription =>
      'The requested page does not exist or could not be opened.';

  @override
  String get routeErrorAction => 'Back to Overview';

  @override
  String get agentsNewAction => 'New agent';

  @override
  String get agentsSaveAction => 'Save';

  @override
  String get agentsDeleteAction => 'Delete';

  @override
  String get agentsInsertTemplateAction => 'Insert template';

  @override
  String get agentsRetryAction => 'Retry';

  @override
  String get agentsReloadAction => 'Reload from disk';

  @override
  String get agentsOverwriteAction => 'Overwrite';

  @override
  String get agentsCancelAction => 'Cancel';

  @override
  String get agentsBackToListAction => 'Back to list';

  @override
  String get agentsSearchHint =>
      'Search agents by ID, name, description, or tag';

  @override
  String get agentsSearchClearTooltip => 'Clear search';

  @override
  String get agentsNoMatchesTitle => 'No matching agents';

  @override
  String get agentsNoMatchesDescription =>
      'Try a different search query or clear your tag filters.';

  @override
  String get agentsSelectPromptTitle => 'Select an agent';

  @override
  String get agentsSelectPromptDescription =>
      'Choose an agent from the list to inspect or edit it, or create a new one.';

  @override
  String get agentsParseErrorBadge => 'Parse error';

  @override
  String get agentsParseErrorTitle => 'Unable to parse agent file';

  @override
  String get agentsLoadErrorTitle => 'Failed to load agents';

  @override
  String get agentsDetailErrorTitle => 'Failed to load agent';

  @override
  String get agentsFieldName => 'Name';

  @override
  String get agentsFieldNameHint => 'e.g. Code Reviewer';

  @override
  String get agentsFieldSlug => 'Slug ID';

  @override
  String get agentsFieldSlugHint => 'e.g. code-reviewer';

  @override
  String get agentsFieldSlugHelper =>
      'Filename (<id>.md). Editable only before first save.';

  @override
  String get agentsFieldSlugInvalid =>
      'Use lowercase letters, numbers, hyphens, or underscores (no reserved OS names).';

  @override
  String get agentsFieldNameRequired => 'Name is required.';

  @override
  String get agentsFieldDescription => 'Description';

  @override
  String get agentsFieldDescriptionHint =>
      'Short summary of what this agent does';

  @override
  String get agentsFieldTags => 'Tags';

  @override
  String get agentsFieldTagsHint => 'Add a tag and press Enter';

  @override
  String get agentsAddChipTooltip => 'Add';

  @override
  String agentsRemoveChipTooltip(String item) {
    return 'Remove $item';
  }

  @override
  String get agentsCapabilitiesTitle => 'Capabilities & tools';

  @override
  String get agentsCapabilitiesSubtitle =>
      'Informational metadata declared in frontmatter (not enforced at runtime).';

  @override
  String get agentsFieldRequiredSkills => 'Required skills';

  @override
  String get agentsFieldRequiredSkillsHint => 'Add skill name';

  @override
  String get agentsFieldRequiredTools => 'Required tools';

  @override
  String get agentsFieldRequiredToolsHint => 'Add tool name';

  @override
  String get agentsFieldAllowedTools => 'Allowed tools';

  @override
  String get agentsFieldAllowedToolsHint => 'Add tool name';

  @override
  String get agentsFieldDeniedTools => 'Denied tools';

  @override
  String get agentsFieldDeniedToolsHint => 'Add tool name';

  @override
  String get agentsFieldPrompt => 'Prompt';

  @override
  String get agentsFieldPromptHint =>
      'Write the agent\'s role instructions in Markdown...';

  @override
  String get agentsPromptModeLabel => 'Prompt editor mode';

  @override
  String get agentsPromptModeRaw => 'Raw';

  @override
  String get agentsPromptModePreview => 'Preview';

  @override
  String get agentsPromptPreviewEmpty => 'Nothing to preview yet.';

  @override
  String get agentsStarterTemplate =>
      '## Responsibilities\n\nDescribe the core role and responsibilities of this agent.\n\n## Required inputs\n\n- List any context or artifacts this agent expects.\n\n## Execution guidance\n\n- Outline key constraints, style rules, or steps to follow.\n\n## Outputs and completion\n\n- Describe the expected deliverable and completion criteria.';

  @override
  String get agentsSaveSuccess => 'Agent saved.';

  @override
  String get agentsCreateSuccess => 'Agent created.';

  @override
  String get agentsDeleteSuccess => 'Agent deleted.';

  @override
  String get agentsDeleteDialogTitle => 'Delete agent?';

  @override
  String agentsDeleteDialogMessage(String name, String id) {
    return 'This will permanently delete $name ($id.md) from disk.';
  }

  @override
  String get agentsConflictDialogTitle => 'External modification detected';

  @override
  String agentsConflictDialogMessage(String id) {
    return '$id.md was modified on disk since you opened it. Reload from disk or overwrite with your changes?';
  }

  @override
  String get agentsExternalModifiedTitle => 'Modified on disk';

  @override
  String get agentsExternalModifiedMessage =>
      'This agent changed outside the app while you have unsaved edits.';

  @override
  String get agentsExternalDeletedTitle => 'Deleted on disk';

  @override
  String get agentsExternalDeletedMessage =>
      'This agent was removed from disk outside the app. Save to recreate it or select another agent.';

  @override
  String get agentsDismissTooltip => 'Dismiss';
}
