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
