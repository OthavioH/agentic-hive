import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_settings_providers.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/workspace_registry_dialog.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/workspace_settings_dialog.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_workspace_repository.dart';
import 'fake_workspace_settings_repository.dart';

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String? workspaceId) async {}
}

Widget _wrap({
  required Widget child,
  required FakeWorkspaceSettingsRepository settings,
  FakeWorkspaceRepository? workspaces,
}) {
  final container = ProviderContainer.test(
    overrides: [
      workspaceSettingsRepositoryProvider.overrideWithValue(settings),
      workspaceRepositoryProvider.overrideWithValue(
        workspaces ?? FakeWorkspaceRepository(),
      ),
      workspaceSelectionStoreProvider.overrideWithValue(_FakeSelectionStore()),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: HiveTheme.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late FakeWorkspaceSettingsRepository settings;
  final workspace = makeWorkspace(name: 'My project');

  setUp(() {
    settings = FakeWorkspaceSettingsRepository();
  });

  Future<void> pumpDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _wrap(
        settings: settings,
        child: WorkspaceSettingsDialog(workspace: workspace),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the inherited global values', (tester) async {
    await pumpDialog(tester);

    expect(find.text('Settings of My project'), findsOneWidget);
    expect(find.text('Inherited: Worktree'), findsOneWidget);
    expect(find.text('Inherited patterns: build/'), findsOneWidget);
    expect(find.text('Leave empty to inherit: cmd.exe'), findsOneWidget);
    expect(
      find.text(
        'CLI paths and the theme are global only and cannot be overridden '
        'here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('saving with nothing changed stores no overrides', (
    tester,
  ) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(const Key('workspace_settings_save_button')));
    await tester.pumpAndSettle();

    expect(settings.updateCalls.single.workspaceId, workspace.id);
    expect(settings.updateCalls.single.overrides.isEmpty, isTrue);
  });

  testWidgets('choosing a mode and a shell saves them as overrides', (
    tester,
  ) async {
    await pumpDialog(tester);

    await tester.tap(find.text('Direct'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('workspace_settings_shell_field')),
      ' pwsh ',
    );
    await tester.tap(find.byKey(const Key('workspace_settings_save_button')));
    await tester.pumpAndSettle();

    expect(
      settings.updateCalls.single.overrides,
      const ExecutionSettings(
        defaultIsolationMode: WorkspaceIsolationMode.direct,
        defaultShell: 'pwsh',
      ),
    );
  });

  testWidgets('the patterns switch overrides the global list', (tester) async {
    await pumpDialog(tester);

    await tester.tap(
      find.byKey(const Key('workspace_settings_patterns_switch')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('workspace_settings_patterns')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('workspace_settings_save_button')));
    await tester.pumpAndSettle();

    expect(settings.updateCalls.single.overrides.ignorePatterns, ['build/']);
  });

  testWidgets('existing overrides prefill the form', (tester) async {
    settings.overrides = const ExecutionSettings(
      defaultIsolationMode: WorkspaceIsolationMode.direct,
      ignorePatterns: <String>['*.log'],
      defaultShell: 'pwsh',
    );

    await pumpDialog(tester);

    expect(find.text('pwsh'), findsOneWidget);
    expect(
      find.byKey(const Key('workspace_settings_patterns')),
      findsOneWidget,
    );
    expect(find.text('*.log'), findsOneWidget);
  });

  testWidgets('a failed save keeps the dialog open with the message', (
    tester,
  ) async {
    settings.updateFailure = const ValidationFailure('Shell is invalid.');
    await pumpDialog(tester);

    await tester.tap(find.byKey(const Key('workspace_settings_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Shell is invalid.'), findsOneWidget);
    expect(find.byType(WorkspaceSettingsDialog), findsOneWidget);
  });

  testWidgets('a load failure shows an error with retry', (tester) async {
    settings.getFailure = const NetworkFailure('down');
    await pumpDialog(tester);

    expect(find.text('Could not load the workspace settings.'), findsOneWidget);

    settings.getFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Inherited: Worktree'), findsOneWidget);
  });

  testWidgets('the registry dialog opens the settings of a workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final workspaces = FakeWorkspaceRepository(workspaces: [workspace]);
    await tester.pumpWidget(
      _wrap(
        settings: settings,
        workspaces: workspaces,
        child: const WorkspaceRegistryDialog(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(Key('workspace_settings_button_${workspace.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings of My project'), findsOneWidget);
    expect(settings.getCalls, [workspace.id]);
  });
}
