import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Application title shown in window title bars and root metadata.
  ///
  /// In en, this message translates to:
  /// **'Agentic Hive'**
  String get appTitle;

  /// Navigation rail destination label for Overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// Navigation rail destination label for Workflows.
  ///
  /// In en, this message translates to:
  /// **'Workflows'**
  String get navWorkflows;

  /// Navigation rail destination label for Runs.
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get navRuns;

  /// Navigation rail destination label for Pauses.
  ///
  /// In en, this message translates to:
  /// **'Pauses'**
  String get navPauses;

  /// Navigation rail destination label for Agents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get navAgents;

  /// Navigation rail destination label for Harnesses.
  ///
  /// In en, this message translates to:
  /// **'Harnesses'**
  String get navHarnesses;

  /// Navigation rail destination label for Settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Tooltip for the button that expands the side rail.
  ///
  /// In en, this message translates to:
  /// **'Expand navigation rail'**
  String get railExpandTooltip;

  /// Tooltip for the button that collapses the side rail.
  ///
  /// In en, this message translates to:
  /// **'Collapse navigation rail'**
  String get railCollapseTooltip;

  /// Empty state title on the Overview placeholder page.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get overviewEmptyTitle;

  /// Empty state description on the Overview placeholder page.
  ///
  /// In en, this message translates to:
  /// **'Workflow runs, active agents, and pending pauses will appear here once you start running workflows.'**
  String get overviewEmptyDescription;

  /// Empty state title on the Workflows placeholder page.
  ///
  /// In en, this message translates to:
  /// **'No workflows yet'**
  String get workflowsEmptyTitle;

  /// Empty state description on the Workflows placeholder page.
  ///
  /// In en, this message translates to:
  /// **'Create a workflow graph to orchestrate agents, validators, and approvals.'**
  String get workflowsEmptyDescription;

  /// Empty state title on the Runs placeholder page.
  ///
  /// In en, this message translates to:
  /// **'No runs yet'**
  String get runsEmptyTitle;

  /// Empty state description on the Runs placeholder page.
  ///
  /// In en, this message translates to:
  /// **'Start a workflow to monitor live execution, logs, and node checkpoints here.'**
  String get runsEmptyDescription;

  /// Empty state title on the Pauses placeholder page.
  ///
  /// In en, this message translates to:
  /// **'No pending pauses'**
  String get pausesEmptyTitle;

  /// Empty state description on the Pauses placeholder page.
  ///
  /// In en, this message translates to:
  /// **'Human approval gates and review checkpoints waiting for your decision will appear here.'**
  String get pausesEmptyDescription;

  /// Empty state title on the Agents placeholder page.
  ///
  /// In en, this message translates to:
  /// **'No agents configured'**
  String get agentsEmptyTitle;

  /// Empty state description on the Agents placeholder page.
  ///
  /// In en, this message translates to:
  /// **'Define specialized agent roles and prompts to reuse across your workflows.'**
  String get agentsEmptyDescription;

  /// Empty state title on the Harnesses page.
  ///
  /// In en, this message translates to:
  /// **'No harnesses detected'**
  String get harnessesEmptyTitle;

  /// Empty state description on the Harnesses page.
  ///
  /// In en, this message translates to:
  /// **'Connected CLI harnesses and their availability status will appear here.'**
  String get harnessesEmptyDescription;

  /// Subtitle shown in the Harnesses page header.
  ///
  /// In en, this message translates to:
  /// **'Detected local AI agent CLIs, versions, and sign-in readiness.'**
  String get harnessesPageSubtitle;

  /// Button label in the Harnesses page header to refresh all harnesses.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get harnessesRefreshAll;

  /// Button label to retry loading harnesses after an error.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get harnessesRetry;

  /// Loading indicator label while fetching harness statuses.
  ///
  /// In en, this message translates to:
  /// **'Checking installed harnesses...'**
  String get harnessesLoading;

  /// Error state title when initial harness loading fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load harnesses'**
  String get harnessesLoadErrorTitle;

  /// Localized error message when loading or refreshing harnesses fails due to a network error.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the local backend service.'**
  String get harnessesErrorNetwork;

  /// Localized error message when the backend returns a failure while checking harnesses.
  ///
  /// In en, this message translates to:
  /// **'The backend returned an error while checking harnesses.'**
  String get harnessesErrorBackend;

  /// Localized error message when a harness is not found.
  ///
  /// In en, this message translates to:
  /// **'The requested harness could not be found.'**
  String get harnessesErrorNotFound;

  /// Localized fallback error message when loading or refreshing harnesses fails.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred while checking harnesses.'**
  String get harnessesErrorUnexpected;

  /// Toast error message shown when refreshing harnesses fails.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh harnesses: {message}'**
  String harnessesRefreshError(String message);

  /// Accessibility label for the per-card re-check button.
  ///
  /// In en, this message translates to:
  /// **'Re-check {name}'**
  String harnessesRecheckTooltip(String name);

  /// Accessibility label for copying a harness executable path.
  ///
  /// In en, this message translates to:
  /// **'Copy {name} executable path'**
  String harnessesCopyPathTooltip(String name);

  /// Toast confirmation shown after copying a harness executable path.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get harnessesPathCopiedToast;

  /// Label above or beside the resolved harness executable path.
  ///
  /// In en, this message translates to:
  /// **'Executable'**
  String get harnessesExecutablePathLabel;

  /// Detected version label on a harness card.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String harnessesVersionLabel(String version);

  /// Fallback version label when no version could be detected.
  ///
  /// In en, this message translates to:
  /// **'Version unavailable'**
  String get harnessesVersionUnknown;

  /// Badge label when a harness is ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get harnessStatusReady;

  /// Badge label when a harness CLI is not installed on PATH.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get harnessStatusNotInstalled;

  /// Badge label when a harness CLI reports an authentication error.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get harnessStatusAuthError;

  /// Badge label when a harness CLI requires an update.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get harnessStatusOutdated;

  /// Badge label when probing a harness CLI fails.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get harnessStatusUnavailable;

  /// Actionable guidance shown when a harness is not installed.
  ///
  /// In en, this message translates to:
  /// **'Install this CLI and ensure it is available on your system PATH.'**
  String get harnessGuidanceNotInstalled;

  /// Actionable guidance shown when a harness has an authentication error.
  ///
  /// In en, this message translates to:
  /// **'Sign in directly using the {name} CLI in your terminal. Agentic Hive never stores harness credentials.'**
  String harnessGuidanceAuthError(String name);

  /// Actionable guidance shown when a harness is outdated.
  ///
  /// In en, this message translates to:
  /// **'Update the {name} CLI in your terminal so workflow runs do not block on an interactive update prompt.'**
  String harnessGuidanceOutdated(String name);

  /// Actionable guidance shown when a harness probe fails.
  ///
  /// In en, this message translates to:
  /// **'The CLI was found on PATH, but probing its version or status failed.'**
  String get harnessGuidanceUnavailable;

  /// Empty state title on the Settings placeholder page.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsEmptyTitle;

  /// Empty state description on the Settings placeholder page.
  ///
  /// In en, this message translates to:
  /// **'Theme, workspace defaults, and backend connection preferences will be configured here.'**
  String get settingsEmptyDescription;

  /// Title shown on the connecting page while waiting for the backend.
  ///
  /// In en, this message translates to:
  /// **'Connecting to backend'**
  String get connectingTitle;

  /// Subtitle shown on the connecting page.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the local Agentic Hive backend service over the Unix domain socket.'**
  String get connectingSubtitle;

  /// Status message when connection attempt is in progress.
  ///
  /// In en, this message translates to:
  /// **'Connecting to backend...'**
  String get connectingStatusConnecting;

  /// Status message when backend is unreachable or disconnected.
  ///
  /// In en, this message translates to:
  /// **'Backend is not responding.'**
  String get connectingStatusDisconnected;

  /// Button label to retry connecting to the backend.
  ///
  /// In en, this message translates to:
  /// **'Retry connection'**
  String get connectingRetryAction;

  /// Title on connecting page when server.json is missing.
  ///
  /// In en, this message translates to:
  /// **'Backend is not running'**
  String get connectingReasonNotRunningTitle;

  /// Message on connecting page when server.json is missing.
  ///
  /// In en, this message translates to:
  /// **'No active backend was found (server.json is missing). Start the Agentic Hive backend service and it will connect automatically.'**
  String get connectingReasonNotRunningMessage;

  /// Title on connecting page when the backend socket refuses connections.
  ///
  /// In en, this message translates to:
  /// **'Backend socket unreachable'**
  String get connectingReasonRefusedTitle;

  /// Message on connecting page when the backend socket refuses connections.
  ///
  /// In en, this message translates to:
  /// **'The backend socket refused the connection or is stale. Waiting for the backend service to accept connections.'**
  String get connectingReasonRefusedMessage;

  /// Title on connecting page when /api/v1/status returns 503 degraded.
  ///
  /// In en, this message translates to:
  /// **'Backend is degraded'**
  String get connectingReasonDegradedTitle;

  /// Message on connecting page when backend reports degraded status.
  ///
  /// In en, this message translates to:
  /// **'The backend is running, but a required dependency such as the database is unavailable. Retrying automatically.'**
  String get connectingReasonDegradedMessage;

  /// Title on connecting page when server.hello protocolVersion does not match.
  ///
  /// In en, this message translates to:
  /// **'Protocol version mismatch'**
  String get connectingReasonProtocolMismatchTitle;

  /// Message on connecting page when WebSocket protocol version is incompatible.
  ///
  /// In en, this message translates to:
  /// **'This desktop app and the running backend use incompatible WebSocket protocol versions. Update the app or backend, then retry.'**
  String get connectingReasonProtocolMismatchMessage;

  /// Title on connecting page when socket connect, status check, or server.hello times out.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get connectingReasonTimeoutTitle;

  /// Message on connecting page when connection or handshake times out.
  ///
  /// In en, this message translates to:
  /// **'The backend did not respond in time. Retrying automatically.'**
  String get connectingReasonTimeoutMessage;

  /// Title on connecting page when an unexpected transport or protocol error occurs.
  ///
  /// In en, this message translates to:
  /// **'Unexpected connection error'**
  String get connectingReasonUnexpectedTitle;

  /// Message on connecting page when an unexpected error occurs.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred while connecting to the local backend.'**
  String get connectingReasonUnexpectedMessage;

  /// Countdown badge showing seconds until the next automatic retry.
  ///
  /// In en, this message translates to:
  /// **'Retrying in {seconds}s'**
  String connectingNextRetryIn(int seconds);

  /// Badge shown when automatic retries are halted due to protocol mismatch.
  ///
  /// In en, this message translates to:
  /// **'Automatic retry paused'**
  String get connectingAutoRetryHalted;

  /// Badge showing the number of failed connection attempts.
  ///
  /// In en, this message translates to:
  /// **'Attempt {count}'**
  String connectingAttemptCount(int count);

  /// Title shown on the router error page when a route cannot be resolved.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get routeErrorTitle;

  /// Description shown on the router error page.
  ///
  /// In en, this message translates to:
  /// **'The requested page does not exist or could not be opened.'**
  String get routeErrorDescription;

  /// Button label on the router error page to return to Overview.
  ///
  /// In en, this message translates to:
  /// **'Back to Overview'**
  String get routeErrorAction;

  /// Subtitle on the Workflows list page header.
  ///
  /// In en, this message translates to:
  /// **'Create, inspect, and manage workflow graphs.'**
  String get workflowsPageSubtitle;

  /// Primary button label to create a new workflow.
  ///
  /// In en, this message translates to:
  /// **'New workflow'**
  String get workflowsNewAction;

  /// Label for the workflow search field.
  ///
  /// In en, this message translates to:
  /// **'Search workflows'**
  String get workflowsSearchLabel;

  /// Placeholder hint for the workflow search field.
  ///
  /// In en, this message translates to:
  /// **'Filter by name or description...'**
  String get workflowsSearchHint;

  /// Title shown when the workflow search filter matches no items.
  ///
  /// In en, this message translates to:
  /// **'No matching workflows'**
  String get workflowsSearchEmptyTitle;

  /// Description shown when the workflow search filter matches no items.
  ///
  /// In en, this message translates to:
  /// **'Try a different search query or clear the filter.'**
  String get workflowsSearchEmptyDescription;

  /// Button label to clear the workflow search filter.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get workflowsClearSearchAction;

  /// Title shown when loading the workflows list fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load workflows'**
  String get workflowsLoadErrorTitle;

  /// Button label to retry loading workflows.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get workflowsRetryAction;

  /// Title of the create workflow dialog.
  ///
  /// In en, this message translates to:
  /// **'Create workflow'**
  String get workflowsCreateTitle;

  /// Label for the workflow name input.
  ///
  /// In en, this message translates to:
  /// **'Workflow name'**
  String get workflowsNameLabel;

  /// Placeholder hint for the workflow name input.
  ///
  /// In en, this message translates to:
  /// **'e.g. PR Review Pipeline'**
  String get workflowsNameHint;

  /// Validation error shown when creating a workflow with an empty name.
  ///
  /// In en, this message translates to:
  /// **'Enter a workflow name.'**
  String get workflowsNameRequiredError;

  /// Label for the workflow description input.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get workflowsDescriptionLabel;

  /// Placeholder hint for the workflow description input.
  ///
  /// In en, this message translates to:
  /// **'Describe what this workflow automates...'**
  String get workflowsDescriptionHint;

  /// Confirm button label in the create workflow dialog.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get workflowsCreateConfirm;

  /// Cancel button label in workflow dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get workflowsCancelAction;

  /// Semantic label and tooltip for duplicating a workflow.
  ///
  /// In en, this message translates to:
  /// **'Duplicate workflow'**
  String get workflowsDuplicateAction;

  /// Semantic label and tooltip for deleting a workflow.
  ///
  /// In en, this message translates to:
  /// **'Delete workflow'**
  String get workflowsDeleteAction;

  /// Semantic label for opening a workflow card in the editor.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String workflowsOpenAction(String name);

  /// Title of the delete workflow confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete workflow?'**
  String get workflowsDeleteTitle;

  /// Message in the delete workflow confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This action cannot be undone.'**
  String workflowsDeleteMessage(String name);

  /// Confirm button label in the delete workflow dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get workflowsDeleteConfirm;

  /// Node count label on a workflow summary card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 nodes} =1{1 node} other{{count} nodes}}'**
  String workflowsNodeCount(int count);

  /// Edge count label on a workflow summary card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 edges} =1{1 edge} other{{count} edges}}'**
  String workflowsEdgeCount(int count);

  /// Badge label when a workflow has no validation errors.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get workflowsStatusValid;

  /// Badge label when a workflow has validation errors.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get workflowsStatusInvalid;

  /// Timestamp label on a workflow summary card.
  ///
  /// In en, this message translates to:
  /// **'Updated {timestamp}'**
  String workflowsUpdatedLabel(String timestamp);

  /// Tooltip and semantic label for the back button in the graph editor.
  ///
  /// In en, this message translates to:
  /// **'Back to workflows'**
  String get editorBackAction;

  /// Button label to add a new node to the graph canvas.
  ///
  /// In en, this message translates to:
  /// **'Add node'**
  String get editorAddNodeAction;

  /// Primary button label to save changes in the graph editor.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editorSaveAction;

  /// Label shown while saving a workflow.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get editorSavingAction;

  /// Badge indicating the workflow has unsaved local edits.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get editorUnsavedBadge;

  /// Badge indicating all workflow changes are saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get editorSavedBadge;

  /// Badge indicating the workflow graph passed validation.
  ///
  /// In en, this message translates to:
  /// **'Graph valid'**
  String get editorValidationValid;

  /// Badge showing the number of validation errors in the graph.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 error} other{{count} errors}}'**
  String editorValidationErrorsCount(int count);

  /// Badge showing the number of validation warnings in the graph.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 warning} other{{count} warnings}}'**
  String editorValidationWarningsCount(int count);

  /// Title of the confirmation dialog when leaving the editor with unsaved changes.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get editorUnsavedDialogTitle;

  /// Message of the confirmation dialog when leaving the editor with unsaved changes.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes to this workflow. Leave without saving?'**
  String get editorUnsavedDialogMessage;

  /// Confirm button label to discard unsaved edits and leave the editor.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get editorDiscardAction;

  /// Cancel button label to stay in the graph editor.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get editorKeepEditingAction;

  /// Inspector panel header when no node or edge is selected.
  ///
  /// In en, this message translates to:
  /// **'Workflow'**
  String get editorInspectorWorkflowTitle;

  /// Inspector panel header when a node is selected.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get editorInspectorNodeTitle;

  /// Inspector panel header when an edge is selected.
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get editorInspectorEdgeTitle;

  /// Section header for validation diagnostics in the inspector.
  ///
  /// In en, this message translates to:
  /// **'Validation'**
  String get editorValidationSectionTitle;

  /// Message shown in the inspector when the workflow has no errors or warnings.
  ///
  /// In en, this message translates to:
  /// **'No validation issues found.'**
  String get editorNoValidationIssues;

  /// Text field label for editing a node's display label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get editorNodeLabelField;

  /// Read-only field label for a node's type identifier.
  ///
  /// In en, this message translates to:
  /// **'Node type'**
  String get editorNodeTypeField;

  /// Switch label for toggling whether the selected node is the workflow entry node.
  ///
  /// In en, this message translates to:
  /// **'Entry node'**
  String get editorNodeEntryLabel;

  /// Button label to delete the selected node.
  ///
  /// In en, this message translates to:
  /// **'Delete node'**
  String get editorDeleteNodeAction;

  /// Default label assigned to a newly added placeholder node.
  ///
  /// In en, this message translates to:
  /// **'Step {number}'**
  String editorDefaultNodeLabel(int number);

  /// Badge displayed on the entry node card on the canvas.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get editorEntryBadge;

  /// Display label for generic placeholder nodes before F5 node types.
  ///
  /// In en, this message translates to:
  /// **'Placeholder'**
  String get editorNodeTypePlaceholder;

  /// Select field label for choosing an edge's sourceOutput.
  ///
  /// In en, this message translates to:
  /// **'Source output'**
  String get editorEdgeSourceOutputLabel;

  /// Select option for entering a custom sourceOutput value.
  ///
  /// In en, this message translates to:
  /// **'Custom output...'**
  String get editorEdgeSourceOutputCustomOption;

  /// Text field label for entering a custom edge sourceOutput.
  ///
  /// In en, this message translates to:
  /// **'Custom output label'**
  String get editorEdgeSourceOutputCustomLabel;

  /// Placeholder hint for custom edge sourceOutput.
  ///
  /// In en, this message translates to:
  /// **'e.g. approved, needsReview'**
  String get editorEdgeSourceOutputCustomHint;

  /// Text field label for an edge's maxRetries limit.
  ///
  /// In en, this message translates to:
  /// **'Max retries'**
  String get editorEdgeMaxRetriesLabel;

  /// Placeholder hint for an edge's maxRetries field.
  ///
  /// In en, this message translates to:
  /// **'Optional (required for cycles)'**
  String get editorEdgeMaxRetriesHint;

  /// Helper text under the maxRetries input.
  ///
  /// In en, this message translates to:
  /// **'Positive integer required on at least one edge in a cycle.'**
  String get editorEdgeMaxRetriesHelper;

  /// Button label to delete the selected edge.
  ///
  /// In en, this message translates to:
  /// **'Delete edge'**
  String get editorDeleteEdgeAction;

  /// Tooltip and semantic label for a node's output port handle.
  ///
  /// In en, this message translates to:
  /// **'Drag to another node to connect'**
  String get editorOutputPortTooltip;

  /// Tooltip and semantic label for canvas zoom-in button.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get editorZoomInTooltip;

  /// Tooltip and semantic label for canvas zoom-out button.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get editorZoomOutTooltip;

  /// Tooltip and semantic label for resetting canvas pan and zoom.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get editorZoomResetTooltip;

  /// Title shown when loading a workflow in the editor fails.
  ///
  /// In en, this message translates to:
  /// **'Could not open workflow'**
  String get editorLoadErrorTitle;

  /// Button label to return to the workflows list from an editor error state.
  ///
  /// In en, this message translates to:
  /// **'Back to Workflows'**
  String get editorBackToWorkflowsAction;

  /// Severity label for a validation error item.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get editorIssueErrorLabel;

  /// Severity label for a validation warning item.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get editorIssueWarningLabel;

  /// Localized validation message when the workflow name is blank.
  ///
  /// In en, this message translates to:
  /// **'Workflow name must not be blank.'**
  String get editorIssueBlankName;

  /// Localized validation message when the workflow contains no nodes.
  ///
  /// In en, this message translates to:
  /// **'Workflow must contain at least one node.'**
  String get editorIssueEmptyNodes;

  /// Localized validation message when entryNodeId is missing or invalid.
  ///
  /// In en, this message translates to:
  /// **'Select a valid entry node for this workflow.'**
  String get editorIssueMissingEntryNode;

  /// Localized validation message when an edge has an empty sourceOutput.
  ///
  /// In en, this message translates to:
  /// **'Edge \"{edgeId}\" must specify a non-empty source output.'**
  String editorIssueEmptySourceOutput(String edgeId);

  /// Localized validation message when an edge references a missing node.
  ///
  /// In en, this message translates to:
  /// **'Edge \"{edgeId}\" references a missing source or target node.'**
  String editorIssueOrphanEdge(String edgeId);

  /// Localized validation message when two edges share source, output, and target.
  ///
  /// In en, this message translates to:
  /// **'Duplicate edge from \"{sourceLabel}\" ({sourceOutput}) to \"{targetLabel}\".'**
  String editorIssueDuplicateEdge(
    String sourceLabel,
    String sourceOutput,
    String targetLabel,
  );

  /// Localized validation message when an edge has maxRetries <= 0.
  ///
  /// In en, this message translates to:
  /// **'Edge \"{edgeId}\" max retries must be greater than 0.'**
  String editorIssueInvalidMaxRetries(String edgeId);

  /// Localized validation message when a directed cycle has no positive maxRetries edge.
  ///
  /// In en, this message translates to:
  /// **'Cycle involving \"{sourceLabel}\" -> \"{targetLabel}\" requires at least one edge with max retries greater than 0.'**
  String editorIssueUnboundedCycle(String sourceLabel, String targetLabel);

  /// Localized validation message when a node cannot be reached from entryNodeId.
  ///
  /// In en, this message translates to:
  /// **'Node \"{nodeLabel}\" is not reachable from the entry node.'**
  String editorIssueUnreachableNode(String nodeLabel);

  /// Fallback localized validation message for an unrecognized validation issue code.
  ///
  /// In en, this message translates to:
  /// **'Workflow graph has a validation issue ({code}).'**
  String editorIssueUnknown(String code);

  /// Localized error message when a workflow operation fails with a NetworkFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the local backend. Check the connection and try again.'**
  String get workflowsFailureNetwork;

  /// Localized error message when a workflow operation fails with a NotFoundFailure.
  ///
  /// In en, this message translates to:
  /// **'The requested workflow could not be found.'**
  String get workflowsFailureNotFound;

  /// Localized error message when a workflow operation fails with a ValidationFailure.
  ///
  /// In en, this message translates to:
  /// **'The workflow request was invalid. Check your inputs and try again.'**
  String get workflowsFailureValidation;

  /// Localized error message when a workflow operation fails with a BackendFailure.
  ///
  /// In en, this message translates to:
  /// **'The local backend rejected the workflow request.'**
  String get workflowsFailureBackend;

  /// Localized error message when a workflow operation fails with an UnexpectedFailure.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred while processing the workflow.'**
  String get workflowsFailureUnexpected;

  /// Localized validation message when a node uses an unregistered type.
  ///
  /// In en, this message translates to:
  /// **'Node \"{nodeLabel}\" has an unknown node type.'**
  String editorIssueUnknownNodeType(String nodeLabel);

  /// Localized validation message when a node's configuration fails validation.
  ///
  /// In en, this message translates to:
  /// **'Node \"{nodeLabel}\" has an invalid configuration.'**
  String editorIssueInvalidNodeConfig(String nodeLabel);

  /// Display name for the Claude Code harness node.
  ///
  /// In en, this message translates to:
  /// **'Claude Code'**
  String get nodeTypeClaudeCode;

  /// Display name for the Codex harness node.
  ///
  /// In en, this message translates to:
  /// **'Codex'**
  String get nodeTypeCodex;

  /// Display name for the Gemini CLI harness node.
  ///
  /// In en, this message translates to:
  /// **'Gemini CLI'**
  String get nodeTypeGeminiCli;

  /// Display name for the Antigravity CLI harness node.
  ///
  /// In en, this message translates to:
  /// **'Antigravity'**
  String get nodeTypeAntigravity;

  /// Display name for the generic terminal harness node.
  ///
  /// In en, this message translates to:
  /// **'Terminal Harness'**
  String get nodeTypeTerminalHarness;

  /// Display name for the command execution node.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get nodeTypeCommand;

  /// Display name for the deterministic tests validator node.
  ///
  /// In en, this message translates to:
  /// **'Tests Validator'**
  String get nodeTypeTestsValidator;

  /// Display name for the deterministic checklist validator node.
  ///
  /// In en, this message translates to:
  /// **'Checklist Validator'**
  String get nodeTypeChecklistValidator;

  /// Display name for the harness-backed review validator node.
  ///
  /// In en, this message translates to:
  /// **'Review Validator'**
  String get nodeTypeReviewValidator;

  /// Display name for the human approval pause node.
  ///
  /// In en, this message translates to:
  /// **'Human Approval'**
  String get nodeTypeHumanApproval;

  /// Fallback display name for an unregistered node type.
  ///
  /// In en, this message translates to:
  /// **'Unknown Node'**
  String get nodeTypeUnknown;

  /// Node palette category header for harness nodes.
  ///
  /// In en, this message translates to:
  /// **'Harnesses'**
  String get nodeCategoryHarnesses;

  /// Node palette category header for execution nodes.
  ///
  /// In en, this message translates to:
  /// **'Execution'**
  String get nodeCategoryExecution;

  /// Node palette category header for validator nodes.
  ///
  /// In en, this message translates to:
  /// **'Validators'**
  String get nodeCategoryValidators;

  /// Node palette category header for human-in-the-loop nodes.
  ///
  /// In en, this message translates to:
  /// **'Human'**
  String get nodeCategoryHuman;

  /// Header title for the categorized node palette panel.
  ///
  /// In en, this message translates to:
  /// **'Node Palette'**
  String get editorPaletteTitle;

  /// Helper text under the node palette header.
  ///
  /// In en, this message translates to:
  /// **'Click or drag onto the canvas'**
  String get editorPaletteHint;

  /// Accessibility label for a node palette item.
  ///
  /// In en, this message translates to:
  /// **'Add {nodeType} node'**
  String editorPaletteInsertSemantic(String nodeType);

  /// Section header for per-type node configuration fields in the inspector.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get nodeConfigSectionTitle;

  /// Fallback message in the inspector when a node has an unregistered type.
  ///
  /// In en, this message translates to:
  /// **'No configuration form is registered for this node type.'**
  String get nodeConfigUnknownType;

  /// Text field label for specifying an agent identifier.
  ///
  /// In en, this message translates to:
  /// **'Agent ID'**
  String get nodeConfigAgentIdLabel;

  /// Placeholder hint for the agent ID input.
  ///
  /// In en, this message translates to:
  /// **'e.g. code-reviewer'**
  String get nodeConfigAgentIdHint;

  /// Helper text under the agent ID field.
  ///
  /// In en, this message translates to:
  /// **'Enter an agent ID manually until the Agent Library is connected.'**
  String get nodeConfigAgentIdHelper;

  /// Multiline text field label for additional harness instructions.
  ///
  /// In en, this message translates to:
  /// **'Additional instructions'**
  String get nodeConfigAdditionalInstructionsLabel;

  /// Placeholder hint for additional harness instructions.
  ///
  /// In en, this message translates to:
  /// **'Extra instructions appended to the prompt...'**
  String get nodeConfigAdditionalInstructionsHint;

  /// Text field label for a relative working directory inside the workspace.
  ///
  /// In en, this message translates to:
  /// **'Working directory'**
  String get nodeConfigWorkingDirectoryLabel;

  /// Placeholder hint for working directory.
  ///
  /// In en, this message translates to:
  /// **'Optional relative path (e.g. packages/app)'**
  String get nodeConfigWorkingDirectoryHint;

  /// Text field label for node execution timeout in seconds.
  ///
  /// In en, this message translates to:
  /// **'Timeout (seconds)'**
  String get nodeConfigTimeoutSecondsLabel;

  /// Placeholder hint for timeout in seconds.
  ///
  /// In en, this message translates to:
  /// **'Optional positive integer'**
  String get nodeConfigTimeoutSecondsHint;

  /// Validation error shown when timeout in seconds is not a positive integer.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive integer.'**
  String get nodeConfigTimeoutSecondsError;

  /// List field label for extra CLI arguments passed to a harness.
  ///
  /// In en, this message translates to:
  /// **'Extra CLI arguments'**
  String get nodeConfigExtraArgsLabel;

  /// Accessibility label for each extra CLI argument row.
  ///
  /// In en, this message translates to:
  /// **'Argument'**
  String get nodeConfigExtraArgsItemLabel;

  /// Button label to append an extra CLI argument.
  ///
  /// In en, this message translates to:
  /// **'Add argument'**
  String get nodeConfigExtraArgsAddLabel;

  /// Text field label for the executable or shell command.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get nodeConfigCommandLabel;

  /// Placeholder hint for the command input.
  ///
  /// In en, this message translates to:
  /// **'e.g. dart, flutter, npm'**
  String get nodeConfigCommandHint;

  /// List field label for command arguments.
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get nodeConfigArgsLabel;

  /// Accessibility label for each command argument row.
  ///
  /// In en, this message translates to:
  /// **'Argument'**
  String get nodeConfigArgsItemLabel;

  /// Button label to append a command argument.
  ///
  /// In en, this message translates to:
  /// **'Add argument'**
  String get nodeConfigArgsAddLabel;

  /// Key-value editor label for command environment variables.
  ///
  /// In en, this message translates to:
  /// **'Environment variables'**
  String get nodeConfigEnvLabel;

  /// Key column label in the environment variables editor.
  ///
  /// In en, this message translates to:
  /// **'Variable'**
  String get nodeConfigEnvKeyLabel;

  /// Value column label in the environment variables editor.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get nodeConfigEnvValueLabel;

  /// Button label to add an environment variable row.
  ///
  /// In en, this message translates to:
  /// **'Add variable'**
  String get nodeConfigEnvAddLabel;

  /// Error message when two environment variable rows share the same key.
  ///
  /// In en, this message translates to:
  /// **'Duplicate variable name'**
  String get nodeConfigEnvDuplicateKey;

  /// Error message when an environment variable row has a value without a key.
  ///
  /// In en, this message translates to:
  /// **'Variable name is required'**
  String get nodeConfigEnvEmptyKey;

  /// Accessibility label for removing a list row.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get nodeConfigRemoveButtonLabel;

  /// Section label for the list of checklist validator rules.
  ///
  /// In en, this message translates to:
  /// **'Checklist rules'**
  String get nodeConfigChecklistRulesLabel;

  /// Empty state text when a checklist validator has no rules.
  ///
  /// In en, this message translates to:
  /// **'No checklist rules configured yet.'**
  String get nodeConfigChecklistEmpty;

  /// Button label to add a new checklist rule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get nodeConfigChecklistAddRule;

  /// Accessibility label for removing a checklist rule row.
  ///
  /// In en, this message translates to:
  /// **'Remove rule'**
  String get nodeConfigChecklistRemoveRule;

  /// Text field label for a checklist rule's display label.
  ///
  /// In en, this message translates to:
  /// **'Rule label'**
  String get nodeConfigChecklistRuleLabelField;

  /// Select field label for a checklist rule's kind.
  ///
  /// In en, this message translates to:
  /// **'Check kind'**
  String get nodeConfigChecklistRuleKindField;

  /// Checklist rule kind option for checking file existence.
  ///
  /// In en, this message translates to:
  /// **'File exists'**
  String get nodeConfigChecklistRuleKindFileExists;

  /// Checklist rule kind option for checking command exit code 0.
  ///
  /// In en, this message translates to:
  /// **'Command succeeds'**
  String get nodeConfigChecklistRuleKindCommandSucceeds;

  /// Checklist rule kind option for matching command stdout against a regex.
  ///
  /// In en, this message translates to:
  /// **'Output matches regex'**
  String get nodeConfigChecklistRuleKindOutputMatchesRegex;

  /// Text field label for the fileExists checklist rule path.
  ///
  /// In en, this message translates to:
  /// **'Relative file path'**
  String get nodeConfigChecklistRulePathField;

  /// Placeholder hint for the fileExists checklist rule path.
  ///
  /// In en, this message translates to:
  /// **'e.g. build/app.apk'**
  String get nodeConfigChecklistRulePathHint;

  /// Text field label for the outputMatchesRegex checklist rule pattern.
  ///
  /// In en, this message translates to:
  /// **'Regex pattern'**
  String get nodeConfigChecklistRulePatternField;

  /// Placeholder hint for the outputMatchesRegex checklist rule pattern.
  ///
  /// In en, this message translates to:
  /// **'e.g. All tests passed'**
  String get nodeConfigChecklistRulePatternHint;

  /// Select field label for choosing which headless harness runs a review validator.
  ///
  /// In en, this message translates to:
  /// **'Review harness'**
  String get nodeConfigReviewHarnessLabel;

  /// Multiline text field label for review validator criteria.
  ///
  /// In en, this message translates to:
  /// **'Review criteria'**
  String get nodeConfigReviewCriteriaLabel;

  /// Placeholder hint for review criteria.
  ///
  /// In en, this message translates to:
  /// **'Describe what the reviewer should verify...'**
  String get nodeConfigReviewCriteriaHint;

  /// Text field label for the human approval node title.
  ///
  /// In en, this message translates to:
  /// **'Approval title'**
  String get nodeConfigHumanTitleLabel;

  /// Placeholder hint for the human approval title.
  ///
  /// In en, this message translates to:
  /// **'e.g. Approve production release'**
  String get nodeConfigHumanTitleHint;

  /// Multiline text field label for human approval instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions for reviewer'**
  String get nodeConfigHumanInstructionsLabel;

  /// Placeholder hint for human approval instructions.
  ///
  /// In en, this message translates to:
  /// **'Explain what the human should review before approving or rejecting...'**
  String get nodeConfigHumanInstructionsHint;

  /// Switch label for allowing the human reviewer to enter feedback.
  ///
  /// In en, this message translates to:
  /// **'Allow feedback message'**
  String get nodeConfigHumanAllowFeedbackLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
