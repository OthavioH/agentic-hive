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

  /// Empty state title on the Harnesses placeholder page.
  ///
  /// In en, this message translates to:
  /// **'No harnesses detected'**
  String get harnessesEmptyTitle;

  /// Empty state description on the Harnesses placeholder page.
  ///
  /// In en, this message translates to:
  /// **'Connected CLI harnesses and their availability status will appear here.'**
  String get harnessesEmptyDescription;

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
