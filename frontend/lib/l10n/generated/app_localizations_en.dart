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
}
