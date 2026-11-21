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
