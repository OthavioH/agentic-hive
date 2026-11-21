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
  String get harnessesPageSubtitle =>
      'Detected local AI agent CLIs, versions, and sign-in readiness.';

  @override
  String get harnessesRefreshAll => 'Refresh';

  @override
  String get harnessesRetry => 'Retry';

  @override
  String get harnessesLoading => 'Checking installed harnesses...';

  @override
  String get harnessesLoadErrorTitle => 'Failed to load harnesses';

  @override
  String get harnessesErrorNetwork =>
      'Could not reach the local backend service.';

  @override
  String get harnessesErrorBackend =>
      'The backend returned an error while checking harnesses.';

  @override
  String get harnessesErrorNotFound =>
      'The requested harness could not be found.';

  @override
  String get harnessesErrorUnexpected =>
      'An unexpected error occurred while checking harnesses.';

  @override
  String harnessesRefreshError(String message) {
    return 'Could not refresh harnesses: $message';
  }

  @override
  String harnessesRecheckTooltip(String name) {
    return 'Re-check $name';
  }

  @override
  String harnessesCopyPathTooltip(String name) {
    return 'Copy $name executable path';
  }

  @override
  String get harnessesPathCopiedToast => 'Path copied';

  @override
  String get harnessesExecutablePathLabel => 'Executable';

  @override
  String harnessesVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get harnessesVersionUnknown => 'Version unavailable';

  @override
  String get harnessStatusReady => 'Ready';

  @override
  String get harnessStatusNotInstalled => 'Not installed';

  @override
  String get harnessStatusAuthError => 'Sign-in required';

  @override
  String get harnessStatusOutdated => 'Update required';

  @override
  String get harnessStatusUnavailable => 'Unavailable';

  @override
  String get harnessGuidanceNotInstalled =>
      'Install this CLI and ensure it is available on your system PATH.';

  @override
  String harnessGuidanceAuthError(String name) {
    return 'Sign in directly using the $name CLI in your terminal. Agentic Hive never stores harness credentials.';
  }

  @override
  String harnessGuidanceOutdated(String name) {
    return 'Update the $name CLI in your terminal so workflow runs do not block on an interactive update prompt.';
  }

  @override
  String get harnessGuidanceUnavailable =>
      'The CLI was found on PATH, but probing its version or status failed.';

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

  @override
  String get trayTooltip => 'Agentic Hive';

  @override
  String get trayStatusConnected => 'Agentic Hive — Connected';

  @override
  String get trayStatusStarting => 'Agentic Hive — Starting…';

  @override
  String get trayStatusDisconnected => 'Agentic Hive — Disconnected';

  @override
  String get trayActionOpen => 'Open Agentic Hive';

  @override
  String get trayActionQuit => 'Quit';

  @override
  String get trayActionStopBackendAndQuit => 'Stop Backend & Quit';

  @override
  String get stopBackendDialogTitle => 'Stop backend and quit?';

  @override
  String stopBackendDialogMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'There are $count active runs in progress. Stopping the backend will abort them.',
      one: 'There is 1 active run in progress. Stopping the backend will abort it.',
    );
    return '$_temp0';
  }

  @override
  String get stopBackendDialogCancel => 'Cancel';

  @override
  String get stopBackendDialogConfirm => 'Stop Backend & Quit';

  @override
  String get dialogDismissLabel => 'Dismiss';

  @override
  String get connectingReasonLaunchFailedTitle => 'Failed to start backend';

  @override
  String get connectingReasonLaunchFailedMessage =>
      'The local Agentic Hive backend could not be launched. Check that the backend executable is available, then retry.';

  @override
  String get workflowsPageSubtitle =>
      'Create, inspect, and manage workflow graphs.';

  @override
  String get workflowsNewAction => 'New workflow';

  @override
  String get workflowsSearchLabel => 'Search workflows';

  @override
  String get workflowsSearchHint => 'Filter by name or description...';

  @override
  String get workflowsSearchEmptyTitle => 'No matching workflows';

  @override
  String get workflowsSearchEmptyDescription =>
      'Try a different search query or clear the filter.';

  @override
  String get workflowsClearSearchAction => 'Clear search';

  @override
  String get workflowsLoadErrorTitle => 'Failed to load workflows';

  @override
  String get workflowsRetryAction => 'Retry';

  @override
  String get workflowsCreateTitle => 'Create workflow';

  @override
  String get workflowsNameLabel => 'Workflow name';

  @override
  String get workflowsNameHint => 'e.g. PR Review Pipeline';

  @override
  String get workflowsNameRequiredError => 'Enter a workflow name.';

  @override
  String get workflowsDescriptionLabel => 'Description (optional)';

  @override
  String get workflowsDescriptionHint =>
      'Describe what this workflow automates...';

  @override
  String get workflowsCreateConfirm => 'Create';

  @override
  String get workflowsCancelAction => 'Cancel';

  @override
  String get workflowsDuplicateAction => 'Duplicate workflow';

  @override
  String get workflowsDeleteAction => 'Delete workflow';

  @override
  String workflowsOpenAction(String name) {
    return 'Open $name';
  }

  @override
  String get workflowsDeleteTitle => 'Delete workflow?';

  @override
  String workflowsDeleteMessage(String name) {
    return 'Delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get workflowsDeleteConfirm => 'Delete';

  @override
  String workflowsNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes',
      one: '1 node',
      zero: '0 nodes',
    );
    return '$_temp0';
  }

  @override
  String workflowsEdgeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count edges',
      one: '1 edge',
      zero: '0 edges',
    );
    return '$_temp0';
  }

  @override
  String get workflowsStatusValid => 'Valid';

  @override
  String get workflowsStatusInvalid => 'Needs attention';

  @override
  String workflowsUpdatedLabel(String timestamp) {
    return 'Updated $timestamp';
  }

  @override
  String get editorBackAction => 'Back to workflows';

  @override
  String get editorAddNodeAction => 'Add node';

  @override
  String get editorSaveAction => 'Save';

  @override
  String get editorSavingAction => 'Saving...';

  @override
  String get editorUnsavedBadge => 'Unsaved changes';

  @override
  String get editorSavedBadge => 'Saved';

  @override
  String get editorValidationValid => 'Graph valid';

  @override
  String editorValidationErrorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errors',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String editorValidationWarningsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings',
      one: '1 warning',
    );
    return '$_temp0';
  }

  @override
  String get editorUnsavedDialogTitle => 'Discard unsaved changes?';

  @override
  String get editorUnsavedDialogMessage =>
      'You have unsaved changes to this workflow. Leave without saving?';

  @override
  String get editorDiscardAction => 'Discard changes';

  @override
  String get editorKeepEditingAction => 'Keep editing';

  @override
  String get editorInspectorWorkflowTitle => 'Workflow';

  @override
  String get editorInspectorNodeTitle => 'Node';

  @override
  String get editorInspectorEdgeTitle => 'Edge';

  @override
  String get editorValidationSectionTitle => 'Validation';

  @override
  String get editorNoValidationIssues => 'No validation issues found.';

  @override
  String get editorNodeLabelField => 'Label';

  @override
  String get editorNodeTypeField => 'Node type';

  @override
  String get editorNodeEntryLabel => 'Entry node';

  @override
  String get editorDeleteNodeAction => 'Delete node';

  @override
  String editorDefaultNodeLabel(int number) {
    return 'Step $number';
  }

  @override
  String get editorEntryBadge => 'Entry';

  @override
  String get editorNodeTypePlaceholder => 'Placeholder';

  @override
  String get editorEdgeSourceOutputLabel => 'Source output';

  @override
  String get editorEdgeSourceOutputCustomOption => 'Custom output...';

  @override
  String get editorEdgeSourceOutputCustomLabel => 'Custom output label';

  @override
  String get editorEdgeSourceOutputCustomHint => 'e.g. approved, needsReview';

  @override
  String get editorEdgeMaxRetriesLabel => 'Max retries';

  @override
  String get editorEdgeMaxRetriesHint => 'Optional (required for cycles)';

  @override
  String get editorEdgeMaxRetriesHelper =>
      'Positive integer required on at least one edge in a cycle.';

  @override
  String get editorDeleteEdgeAction => 'Delete edge';

  @override
  String get editorOutputPortTooltip => 'Drag to another node to connect';

  @override
  String get editorZoomInTooltip => 'Zoom in';

  @override
  String get editorZoomOutTooltip => 'Zoom out';

  @override
  String get editorZoomResetTooltip => 'Reset view';

  @override
  String get editorLoadErrorTitle => 'Could not open workflow';

  @override
  String get editorBackToWorkflowsAction => 'Back to Workflows';

  @override
  String get editorIssueErrorLabel => 'Error';

  @override
  String get editorIssueWarningLabel => 'Warning';

  @override
  String get editorIssueBlankName => 'Workflow name must not be blank.';

  @override
  String get editorIssueEmptyNodes =>
      'Workflow must contain at least one node.';

  @override
  String get editorIssueMissingEntryNode =>
      'Select a valid entry node for this workflow.';

  @override
  String editorIssueEmptySourceOutput(String edgeId) {
    return 'Edge \"$edgeId\" must specify a non-empty source output.';
  }

  @override
  String editorIssueOrphanEdge(String edgeId) {
    return 'Edge \"$edgeId\" references a missing source or target node.';
  }

  @override
  String editorIssueDuplicateEdge(
    String sourceLabel,
    String sourceOutput,
    String targetLabel,
  ) {
    return 'Duplicate edge from \"$sourceLabel\" ($sourceOutput) to \"$targetLabel\".';
  }

  @override
  String editorIssueInvalidMaxRetries(String edgeId) {
    return 'Edge \"$edgeId\" max retries must be greater than 0.';
  }

  @override
  String editorIssueUnboundedCycle(String sourceLabel, String targetLabel) {
    return 'Cycle involving \"$sourceLabel\" -> \"$targetLabel\" requires at least one edge with max retries greater than 0.';
  }

  @override
  String editorIssueUnreachableNode(String nodeLabel) {
    return 'Node \"$nodeLabel\" is not reachable from the entry node.';
  }

  @override
  String editorIssueUnknown(String code) {
    return 'Workflow graph has a validation issue ($code).';
  }

  @override
  String get workflowsFailureNetwork =>
      'Could not reach the local backend. Check the connection and try again.';

  @override
  String get workflowsFailureNotFound =>
      'The requested workflow could not be found.';

  @override
  String get workflowsFailureValidation =>
      'The workflow request was invalid. Check your inputs and try again.';

  @override
  String get workflowsFailureBackend =>
      'The local backend rejected the workflow request.';

  @override
  String get workflowsFailureUnexpected =>
      'An unexpected error occurred while processing the workflow.';
}
