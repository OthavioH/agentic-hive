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

  /// Primary button label in the Agents page header to create a new agent.
  ///
  /// In en, this message translates to:
  /// **'New agent'**
  String get agentsNewAction;

  /// Primary button label to save the current agent draft.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get agentsSaveAction;

  /// Button label to delete the selected agent.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get agentsDeleteAction;

  /// Button label to populate a new agent draft with the starter Markdown template.
  ///
  /// In en, this message translates to:
  /// **'Insert template'**
  String get agentsInsertTemplateAction;

  /// Button label to retry loading agents or agent details.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get agentsRetryAction;

  /// Action label to reload the agent from disk, discarding local edits.
  ///
  /// In en, this message translates to:
  /// **'Reload from disk'**
  String get agentsReloadAction;

  /// Action label to overwrite external disk changes with local edits.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get agentsOverwriteAction;

  /// Cancel button label in confirmation dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get agentsCancelAction;

  /// Button label on narrow layouts to return from the editor to the agent list.
  ///
  /// In en, this message translates to:
  /// **'Back to list'**
  String get agentsBackToListAction;

  /// Placeholder text in the agent library search input.
  ///
  /// In en, this message translates to:
  /// **'Search agents by ID, name, description, or tag'**
  String get agentsSearchHint;

  /// Semantics label for the clear button in the agent search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get agentsSearchClearTooltip;

  /// Empty state title when search or tag filters match no agents.
  ///
  /// In en, this message translates to:
  /// **'No matching agents'**
  String get agentsNoMatchesTitle;

  /// Empty state description when search or tag filters match no agents.
  ///
  /// In en, this message translates to:
  /// **'Try a different search query or clear your tag filters.'**
  String get agentsNoMatchesDescription;

  /// Empty state title in the detail pane when no agent is selected.
  ///
  /// In en, this message translates to:
  /// **'Select an agent'**
  String get agentsSelectPromptTitle;

  /// Empty state description in the detail pane when no agent is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose an agent from the list to inspect or edit it, or create a new one.'**
  String get agentsSelectPromptDescription;

  /// Badge label on agent list items whose .md file failed to parse.
  ///
  /// In en, this message translates to:
  /// **'Parse error'**
  String get agentsParseErrorBadge;

  /// Banner title when inspecting a malformed agent .md file.
  ///
  /// In en, this message translates to:
  /// **'Unable to parse agent file'**
  String get agentsParseErrorTitle;

  /// Banner title when listing agents fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load agents'**
  String get agentsLoadErrorTitle;

  /// Banner title when loading a specific agent fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load agent'**
  String get agentsDetailErrorTitle;

  /// Label for the agent name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get agentsFieldName;

  /// Hint text for the agent name field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Code Reviewer'**
  String get agentsFieldNameHint;

  /// Label for the agent filename slug ID field.
  ///
  /// In en, this message translates to:
  /// **'Slug ID'**
  String get agentsFieldSlug;

  /// Hint text for the agent slug ID field.
  ///
  /// In en, this message translates to:
  /// **'e.g. code-reviewer'**
  String get agentsFieldSlugHint;

  /// Helper text explaining that the slug is the filename and immutable after creation.
  ///
  /// In en, this message translates to:
  /// **'Filename (<id>.md). Editable only before first save.'**
  String get agentsFieldSlugHelper;

  /// Validation error shown when the agent slug ID is invalid.
  ///
  /// In en, this message translates to:
  /// **'Use lowercase letters, numbers, hyphens, or underscores (no reserved OS names).'**
  String get agentsFieldSlugInvalid;

  /// Validation error shown when the agent name is empty.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get agentsFieldNameRequired;

  /// Label for the agent description field.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get agentsFieldDescription;

  /// Hint text for the agent description field.
  ///
  /// In en, this message translates to:
  /// **'Short summary of what this agent does'**
  String get agentsFieldDescriptionHint;

  /// Label for the agent tags chip editor.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get agentsFieldTags;

  /// Hint text for adding a new tag.
  ///
  /// In en, this message translates to:
  /// **'Add a tag and press Enter'**
  String get agentsFieldTagsHint;

  /// Tooltip and semantics label for the add chip button.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get agentsAddChipTooltip;

  /// Semantics label for removing a chip item.
  ///
  /// In en, this message translates to:
  /// **'Remove {item}'**
  String agentsRemoveChipTooltip(String item);

  /// Title of the collapsible informational metadata section in the agent editor.
  ///
  /// In en, this message translates to:
  /// **'Capabilities & tools'**
  String get agentsCapabilitiesTitle;

  /// Subtitle of the collapsible capabilities and tools section.
  ///
  /// In en, this message translates to:
  /// **'Informational metadata declared in frontmatter (not enforced at runtime).'**
  String get agentsCapabilitiesSubtitle;

  /// Label for required_skills chip editor.
  ///
  /// In en, this message translates to:
  /// **'Required skills'**
  String get agentsFieldRequiredSkills;

  /// Hint text for required_skills input.
  ///
  /// In en, this message translates to:
  /// **'Add skill name'**
  String get agentsFieldRequiredSkillsHint;

  /// Label for required_tools chip editor.
  ///
  /// In en, this message translates to:
  /// **'Required tools'**
  String get agentsFieldRequiredTools;

  /// Hint text for required_tools input.
  ///
  /// In en, this message translates to:
  /// **'Add tool name'**
  String get agentsFieldRequiredToolsHint;

  /// Label for allowed_tools chip editor.
  ///
  /// In en, this message translates to:
  /// **'Allowed tools'**
  String get agentsFieldAllowedTools;

  /// Hint text for allowed_tools input.
  ///
  /// In en, this message translates to:
  /// **'Add tool name'**
  String get agentsFieldAllowedToolsHint;

  /// Label for denied_tools chip editor.
  ///
  /// In en, this message translates to:
  /// **'Denied tools'**
  String get agentsFieldDeniedTools;

  /// Hint text for denied_tools input.
  ///
  /// In en, this message translates to:
  /// **'Add tool name'**
  String get agentsFieldDeniedToolsHint;

  /// Label for the Markdown prompt editor.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get agentsFieldPrompt;

  /// Hint text for the Markdown prompt textarea.
  ///
  /// In en, this message translates to:
  /// **'Write the agent\'s role instructions in Markdown...'**
  String get agentsFieldPromptHint;

  /// Semantics label for the Raw / Preview segmented control.
  ///
  /// In en, this message translates to:
  /// **'Prompt editor mode'**
  String get agentsPromptModeLabel;

  /// Segment label for editing raw Markdown prompt text.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get agentsPromptModeRaw;

  /// Segment label for previewing rendered Markdown prompt.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get agentsPromptModePreview;

  /// Placeholder text in Markdown preview mode when the prompt is empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview yet.'**
  String get agentsPromptPreviewEmpty;

  /// Starter Markdown template inserted when creating a new agent.
  ///
  /// In en, this message translates to:
  /// **'## Responsibilities\n\nDescribe the core role and responsibilities of this agent.\n\n## Required inputs\n\n- List any context or artifacts this agent expects.\n\n## Execution guidance\n\n- Outline key constraints, style rules, or steps to follow.\n\n## Outputs and completion\n\n- Describe the expected deliverable and completion criteria.'**
  String get agentsStarterTemplate;

  /// Toast message shown after saving an existing agent.
  ///
  /// In en, this message translates to:
  /// **'Agent saved.'**
  String get agentsSaveSuccess;

  /// Toast message shown after creating a new agent.
  ///
  /// In en, this message translates to:
  /// **'Agent created.'**
  String get agentsCreateSuccess;

  /// Toast message shown after deleting an agent.
  ///
  /// In en, this message translates to:
  /// **'Agent deleted.'**
  String get agentsDeleteSuccess;

  /// Title of the destructive confirmation dialog when deleting an agent.
  ///
  /// In en, this message translates to:
  /// **'Delete agent?'**
  String get agentsDeleteDialogTitle;

  /// Message in the delete agent confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete {name} ({id}.md) from disk.'**
  String agentsDeleteDialogMessage(String name, String id);

  /// Title of the 409 conflict confirmation dialog when saving.
  ///
  /// In en, this message translates to:
  /// **'External modification detected'**
  String get agentsConflictDialogTitle;

  /// Message in the 409 conflict confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'{id}.md was modified on disk since you opened it. Reload from disk or overwrite with your changes?'**
  String agentsConflictDialogMessage(String id);

  /// Banner title when the currently open agent with unsaved edits is modified externally.
  ///
  /// In en, this message translates to:
  /// **'Modified on disk'**
  String get agentsExternalModifiedTitle;

  /// Banner message when the currently open agent with unsaved edits is modified externally.
  ///
  /// In en, this message translates to:
  /// **'This agent changed outside the app while you have unsaved edits.'**
  String get agentsExternalModifiedMessage;

  /// Banner title when the currently open agent is deleted externally.
  ///
  /// In en, this message translates to:
  /// **'Deleted on disk'**
  String get agentsExternalDeletedTitle;

  /// Banner message when the currently open agent is deleted externally.
  ///
  /// In en, this message translates to:
  /// **'This agent was removed from disk outside the app. Save to recreate it or select another agent.'**
  String get agentsExternalDeletedMessage;

  /// Semantics label for dismissing an inline banner or toast.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get agentsDismissTooltip;

  /// Tooltip shown when hovering over the system tray icon.
  ///
  /// In en, this message translates to:
  /// **'Agentic Hive'**
  String get trayTooltip;

  /// Disabled tray menu header when the backend is connected.
  ///
  /// In en, this message translates to:
  /// **'Agentic Hive — Connected'**
  String get trayStatusConnected;

  /// Disabled tray menu header when the app is connecting or starting the backend.
  ///
  /// In en, this message translates to:
  /// **'Agentic Hive — Starting…'**
  String get trayStatusStarting;

  /// Disabled tray menu header when the backend is disconnected.
  ///
  /// In en, this message translates to:
  /// **'Agentic Hive — Disconnected'**
  String get trayStatusDisconnected;

  /// Tray menu item that restores and focuses the main window.
  ///
  /// In en, this message translates to:
  /// **'Open Agentic Hive'**
  String get trayActionOpen;

  /// Tray menu item that quits the UI and stops an idle backend.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayActionQuit;

  /// Tray menu item that stops the backend and exits the app.
  ///
  /// In en, this message translates to:
  /// **'Stop Backend & Quit'**
  String get trayActionStopBackendAndQuit;

  /// Confirmation dialog title when stopping the backend while runs are active.
  ///
  /// In en, this message translates to:
  /// **'Stop backend and quit?'**
  String get stopBackendDialogTitle;

  /// Confirmation dialog body when stopping the backend with active runs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{There is 1 active run in progress. Stopping the backend will abort it.} other{There are {count} active runs in progress. Stopping the backend will abort them.}}'**
  String stopBackendDialogMessage(int count);

  /// Safe cancel button label on the stop backend confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get stopBackendDialogCancel;

  /// Confirming destructive button label on the stop backend confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Stop Backend & Quit'**
  String get stopBackendDialogConfirm;

  /// Accessibility label for modal dialog scrim dismissal.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dialogDismissLabel;

  /// Title on connecting page when launching the local backend process fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to start backend'**
  String get connectingReasonLaunchFailedTitle;

  /// Message on connecting page when launching the local backend process fails.
  ///
  /// In en, this message translates to:
  /// **'The local Agentic Hive backend could not be launched. Check that the backend executable is available, then retry.'**
  String get connectingReasonLaunchFailedMessage;

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
