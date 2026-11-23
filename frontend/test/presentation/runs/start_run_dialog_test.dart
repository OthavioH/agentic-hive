import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/settings/file_picker_repository_impl.dart';
import 'package:agentic_hive_frontend/data/settings/settings_repository_impl.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/settings/file_picker_repository.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/runs_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/start_run_dialog.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../workspace/fake_workspace_repository.dart';

final class _FakeRunRepository implements RunRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);
  StartRunRequest? lastStartRequest;
  Result<Run>? startOverride;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

  @override
  Future<Result<Run>> getRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      const Success(<Checkpoint>[]);

  @override
  Future<Result<Run>> startRun(StartRunRequest request) async {
    lastStartRequest = request;
    if (startOverride != null) return startOverride!;
    return Success(
      Run(
        id: 'run-new',
        workflowId: request.workflowId,
        workflowName: 'Release Build',
        workflowDefinition: Workflow(
          id: request.workflowId,
          name: 'Release Build',
          nodes: const <WorkflowNode>[],
          edges: const <WorkflowEdge>[],
          createdAt: now,
          updatedAt: now,
        ),
        workspacePath: request.workspacePath ?? '',
        status: RunStatus.running,
        startedAt: now,
        isolationMode:
            request.workspaceIsolationMode ?? WorkspaceIsolationMode.direct,
      ),
    );
  }

  @override
  Future<Result<Run>> cancelRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<Run>> resumeRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<void>> deleteRun(String id) async => const Success(null);
}

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    String? workspaceId,
  }) async => Success(<WorkflowSummary>[
    WorkflowSummary(
      id: 'wf-1',
      name: 'Release Build',
      nodeCount: 2,
      edgeCount: 1,
      hasValidationErrors: false,
      updatedAt: now,
    ),
  ]);

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<void>> deleteWorkflow(String id, {String? workspaceId}) async =>
      const Success(null);

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

final class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<Result<AppSettings>> getSettings() async => const Success(
    AppSettings(
      effectiveAgentsDir: '/agents',
      defaultAgentsDir: '/agents',
      defaultWorkspaceDir: '/projects/hive',
    ),
  );

  @override
  Future<Result<AppSettings>> updateSettings(
    UpdateSettingsRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Stream<AppSettings> watchSettingsUpdates() =>
      const Stream<AppSettings>.empty();
}

final class _FakeFilePickerRepository implements FilePickerRepository {
  @override
  Future<String?> pickDirectory({String? initialDirectory}) async =>
      '/picked/repo';

  @override
  Future<String?> pickFile({String? initialDirectory}) async => null;
}

void main() {
  testWidgets(
    'StartRunDialog checks capabilities, submits worktree run, and navigates',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runsRepo = _FakeRunRepository();
      final workspaceRepo = FakeWorkspaceRepository(
        capabilities: const Success(
          WorkspaceCapabilities(
            gitAvailable: true,
            isGitRepo: true,
            hasCommits: true,
          ),
        ),
      );

      final router = GoRouter(
        initialLocation: '/runs',
        routes: <RouteBase>[
          GoRoute(
            path: '/runs',
            builder: (_, _) => const Scaffold(body: RunsPage()),
          ),
          GoRoute(
            path: '/runs/:id',
            builder: (_, state) =>
                Scaffold(body: Text('detail:${state.pathParameters['id']}')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(runsRepo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(),
            ),
            filePickerRepositoryProvider.overrideWithValue(
              _FakeFilePickerRepository(),
            ),
            workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
          ],
          child: MaterialApp.router(
            theme: HiveTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('runs_new_button')));
      await tester.pumpAndSettle();

      expect(find.byType(StartRunDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('start_run_isolation_worktree')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      expect(runsRepo.lastStartRequest?.workflowId, 'wf-1');
      expect(runsRepo.lastStartRequest?.workspacePath, '/projects/hive');
      expect(
        runsRepo.lastStartRequest?.workspaceIsolationMode,
        WorkspaceIsolationMode.worktree,
      );
      expect(find.text('detail:run-new'), findsOneWidget);
    },
  );

  testWidgets(
    'StartRunDialog disables worktree for non-git workspace and surfaces 409',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runsRepo = _FakeRunRepository()
        ..startOverride = const FailureResult(
          BackendFailure('Conflict', statusCode: 409),
        );
      final workspaceRepo = FakeWorkspaceRepository(
        capabilities: const Success(
          WorkspaceCapabilities(
            gitAvailable: true,
            isGitRepo: false,
            hasCommits: false,
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(runsRepo),
            workflowRepositoryProvider.overrideWithValue(
              _FakeWorkflowRepository(),
            ),
            settingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(),
            ),
            filePickerRepositoryProvider.overrideWithValue(
              _FakeFilePickerRepository(),
            ),
            workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
          ],
          child: MaterialApp(
            theme: HiveTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: HiveButton(
                  label: 'Open',
                  onPressed: () => StartRunDialog.show(context),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final worktreeChip = tester.widget<HiveFilterChip>(
        find.byKey(const Key('start_run_isolation_worktree')),
      );
      expect(worktreeChip.onSelected, isNull);

      await tester.tap(find.byKey(const Key('start_run_confirm_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('start_run_error_banner')), findsOneWidget);
      expect(
        find.textContaining('A direct run is already active'),
        findsOneWidget,
      );
    },
  );
}
