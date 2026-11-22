import 'package:agentic_hive_frontend/data/settings/file_picker_repository_impl.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/settings/file_picker_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/workspace_registry_dialog.dart';
import 'package:agentic_hive_frontend/presentation/workspace/widgets/workspace_switcher_bar.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_workspace_repository.dart';

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  String? savedId;

  @override
  Future<String?> load() async => savedId;

  @override
  Future<void> save(String? workspaceId) async {
    savedId = workspaceId;
  }
}

final class _FakeFilePickerRepository implements FilePickerRepository {
  String? pickedDirectory;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async =>
      pickedDirectory;

  @override
  Future<String?> pickFile({String? initialDirectory}) async => null;
}

Widget _wrap({
  required Widget child,
  required FakeWorkspaceRepository repo,
  required _FakeSelectionStore selectionStore,
  required _FakeFilePickerRepository filePicker,
}) {
  final container = ProviderContainer.test(
    overrides: [
      workspaceRepositoryProvider.overrideWithValue(repo),
      workspaceSelectionStoreProvider.overrideWithValue(selectionStore),
      filePickerRepositoryProvider.overrideWithValue(filePicker),
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
  late FakeWorkspaceRepository repo;
  late _FakeSelectionStore selectionStore;
  late _FakeFilePickerRepository filePicker;

  setUp(() {
    repo = FakeWorkspaceRepository();
    selectionStore = _FakeSelectionStore();
    filePicker = _FakeFilePickerRepository();
  });

  testWidgets('WorkspaceSwitcherBar shows empty state and opens dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        child: const WorkspaceSwitcherBar(),
        repo: repo,
        selectionStore: selectionStore,
        filePicker: filePicker,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No workspace registered'), findsOneWidget);
    await tester.tap(find.byKey(const Key('workspace_manage_button')));
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceRegistryDialog), findsOneWidget);
  });

  testWidgets(
    'WorkspaceSwitcherBar switches current workspace via HiveSelect',
    (tester) async {
      final ws1 = makeWorkspace(name: 'Alpha');
      final ws2 = makeWorkspace(id: 'ws-2', name: 'Beta');
      repo.workspaces = [ws1, ws2];
      selectionStore.savedId = 'ws-1';

      await tester.pumpWidget(
        _wrap(
          child: const WorkspaceSwitcherBar(),
          repo: repo,
          selectionStore: selectionStore,
          filePicker: filePicker,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);

      await tester.tap(find.byKey(const Key('workspace_switcher_select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta').last);
      await tester.pumpAndSettle();

      expect(selectionStore.savedId, 'ws-2');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkspaceSwitcherBar)),
      );
      expect(
        container
            .read(workspaceRegistryControllerProvider)
            .value
            ?.currentWorkspaceId,
        'ws-2',
      );
    },
  );

  testWidgets(
    'WorkspaceRegistryDialog adds workspace with default editable name',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      filePicker.pickedDirectory = '/tmp/projects/my-repo';

      await tester.pumpWidget(
        _wrap(
          child: const WorkspaceRegistryDialog(),
          repo: repo,
          selectionStore: selectionStore,
          filePicker: filePicker,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('workspace_add_browse_button')));
      await tester.pumpAndSettle();

      final nameField = tester.widget<HiveTextField>(
        find.byKey(const Key('workspace_add_name_field')),
      );
      expect(nameField.controller?.text, 'my-repo');

      await tester.enterText(
        find.byKey(const Key('workspace_add_name_field')),
        'My Custom Repo',
      );
      await tester.ensureVisible(
        find.byKey(const Key('workspace_add_submit_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace_add_submit_button')));
      await tester.pumpAndSettle();

      expect(repo.createCalls.single.rootPath, '/tmp/projects/my-repo');
      expect(repo.createCalls.single.name, 'My Custom Repo');
      expect(find.text('My Custom Repo'), findsOneWidget);
    },
  );

  testWidgets('WorkspaceRegistryDialog renames a workspace', (tester) async {
    repo.workspaces = [makeWorkspace(name: 'Original')];

    await tester.pumpWidget(
      _wrap(
        child: const WorkspaceRegistryDialog(),
        repo: repo,
        selectionStore: selectionStore,
        filePicker: filePicker,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('workspace_rename_button_ws-1')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('workspace_rename_name_field')),
      'Updated Name',
    );
    await tester.tap(find.byKey(const Key('workspace_rename_save_button')));
    await tester.pumpAndSettle();

    expect(repo.renameCalls.single, (id: 'ws-1', name: 'Updated Name'));
    expect(find.text('Updated Name'), findsOneWidget);
  });

  testWidgets(
    'WorkspaceRegistryDialog warns on active runs when removing a workspace',
    (tester) async {
      repo.workspaces = [makeWorkspace(name: 'Busy', activeRunCount: 2)];

      await tester.pumpWidget(
        _wrap(
          child: const WorkspaceRegistryDialog(),
          repo: repo,
          selectionStore: selectionStore,
          filePicker: filePicker,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('workspace_remove_button_ws-1')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('active runs must finish or be cancelled first'),
        findsOneWidget,
      );
      expect(find.textContaining('does not delete'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(repo.unregisterCalls, ['ws-1']);
    },
  );
}
