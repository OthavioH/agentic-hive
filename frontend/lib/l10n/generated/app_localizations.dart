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
