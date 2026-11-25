import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/runs/file_run_attachment_store.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_backend/src/domain/nodes/child_run_port.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_capabilities_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_preparation_service.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../engine/support/engine_harness.dart';
import '../engine/support/fake_ports.dart';
import '../engine/support/in_memory_repositories.dart';

final class _FakeProcessRunner implements ProcessRunner {
  const new();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeWorkspaceRepository implements WorkspaceRepository {
  new(this.rootPath);
  final String rootPath;

  @override
  Future<Result<Workspace>> getById(String id) async => Success(
    Workspace(
      id: id,
      name: 'Workspace',
      rootPath: rootPath,
      isGit: false,
      createdAt: DateTime.utc(2026, 11, 23, 10),
      updatedAt: DateTime.utc(2026, 11, 23, 10),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SingleWorkflowRepository implements WorkflowRepository {
  new(this.workflow);
  final Workflow workflow;

  @override
  Future<Result<Workflow>> getById(String id) async => Success(workflow);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;
  late Directory workspaceDir;
  late Directory runsDir;
  late InMemoryRunRepository runsRepo;
  late InMemoryRunEventRepository eventsRepo;
  late FileRunAttachmentStore attachmentStore;
  late RunService service;

  final pngBytes = Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
  ]);
  final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

  final workflow = Workflow(
    id: 'wf-1',
    name: 'Test Flow',
    entryNodeId: 'n1',
    edges: const [],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: NodeTypeId.command,
        label: 'Run',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('run_svc_attach_');
    workspaceDir = Directory(p.join(tempDir.path, 'ws'))..createSync();
    runsDir = Directory(p.join(tempDir.path, 'runs'))..createSync();
    final harness = EngineHarness();
    runsRepo = harness.runs;
    eventsRepo = harness.events;
    attachmentStore = FileRunAttachmentStore(runsDir: runsDir.path);
    const git = GitClient(_FakeProcessRunner());
    service = RunService(
      runs: runsRepo,
      checkpoints: harness.checkpoints,
      events: eventsRepo,
      workspacePreparation: const WorkspacePreparationService(git: git),
      workflows: _SingleWorkflowRepository(workflow),
      workspaces: WorkspaceService(
        workspaces: _FakeWorkspaceRepository(workspaceDir.path),
        capabilities: const WorkspaceCapabilitiesService(git),
      ),
      engine: harness.engine,
      attachments: attachmentStore,
    );
  });

  tearDown(() async {
    await service.waitForActiveExecutions();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('valid PNG and JPEG with input stores files and metadata', () async {
    final res = await service.startRun(
      StartRunRequest(
        workflowId: 'wf-1',
        workspaceId: 'ws-1',
        input: 'hello',
        attachments: [
          RunAttachmentPayload(
            fileName: 'shot.png',
            mimeType: 'image/png',
            data: base64Encode(pngBytes),
          ),
          RunAttachmentPayload(
            fileName: 'photo.jpg',
            mimeType: 'image/jpeg',
            data: base64Encode(jpegBytes),
          ),
        ],
      ),
    );

    expect(res, isA<Success<Run>>());
    final run = res.valueOrNull!;
    expect(run.attachments, hasLength(2));
    expect(run.attachments![0].fileName, 'shot.png');
    expect(run.attachments![0].mimeType, 'image/png');
    expect(run.attachments![0].sizeBytes, pngBytes.length);
    expect(run.attachments![1].fileName, 'photo.jpg');
    expect(run.attachments![1].mimeType, 'image/jpeg');
    expect(run.attachments![1].sizeBytes, jpegBytes.length);

    expect(
      File(p.join(runsDir.path, run.id, 'attachments', '1.png'))
          .readAsBytesSync(),
      pngBytes,
    );
    expect(
      File(p.join(runsDir.path, run.id, 'attachments', '2.jpg'))
          .readAsBytesSync(),
      jpegBytes,
    );
    expect(runsRepo.runs[run.id]?.attachments, run.attachments);
  });

  test('images with null input succeed', () async {
    final res = await service.startRun(
      StartRunRequest(
        workflowId: 'wf-1',
        workspaceId: 'ws-1',
        attachments: [
          RunAttachmentPayload(
            fileName: 'only.png',
            mimeType: 'image/png',
            data: base64Encode(pngBytes),
          ),
        ],
      ),
    );

    expect(res, isA<Success<Run>>());
    expect(res.valueOrNull!.input, isNull);
    expect(res.valueOrNull!.attachments, hasLength(1));
  });

  test(
    'invalid attachments fail with ValidationFailure and create nothing',
    () async {
      final res = await service.startRun(
        StartRunRequest(
          workflowId: 'wf-1',
          workspaceId: 'ws-1',
          attachments: [
            RunAttachmentPayload(
              fileName: 'bad.jpg',
              mimeType: 'image/jpeg',
              data: base64Encode(pngBytes),
            ),
          ],
        ),
      );

      expect(res, isA<FailureResult<Run>>());
      expect((res as FailureResult).failure, isA<ValidationFailure>());
      expect(runsRepo.runs, isEmpty);
      expect(runsDir.listSync(), isEmpty);
    },
  );

  test('base64 bytes never leak into logs, events, or run JSON', () async {
    final b64 = base64Encode(pngBytes);
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    try {
      final res = await service.startRun(
        StartRunRequest(
          workflowId: 'wf-1',
          workspaceId: 'ws-1',
          attachments: [
            RunAttachmentPayload(
              fileName: 'secret.png',
              mimeType: 'image/png',
              data: b64,
            ),
          ],
        ),
      );
      expect(res, isA<Success<Run>>());
      await service.waitForActiveExecutions();

      final run = res.valueOrNull!;
      expect(jsonEncode(run.toJson()), isNot(contains(b64)));
      for (final r in records) {
        expect(r.message, isNot(contains(b64)));
      }
      for (final e in eventsRepo.events) {
        expect(jsonEncode(e.payload), isNot(contains(b64)));
      }
    } finally {
      await sub.cancel();
    }
  });

  test('child run has null attachments', () async {
    final res = await service.startChildRun(
      ChildRunRequest(
        parentRunId: 'parent-1',
        parentNodeId: 'fan-1',
        index: 0,
        name: 'Child 1',
        workflow: workflow,
        workspaceId: 'ws-1',
        placement: ChildRunPlacement.values.last,
      ),
    );

    expect(res, isA<Success<Run>>());
    expect(res.valueOrNull!.attachments, isNull);
  });

  test('deleteRun deletes attachments folder on disk', () async {
    final res = await service.startRun(
      StartRunRequest(
        workflowId: 'wf-1',
        workspaceId: 'ws-1',
        attachments: [
          RunAttachmentPayload(
            fileName: 'shot.png',
            mimeType: 'image/png',
            data: base64Encode(pngBytes),
          ),
        ],
      ),
    );
    final run = res.valueOrNull!;
    await service.waitForActiveExecutions();
    await runsRepo.updateStatus(run.id, status: RunStatus.succeeded);
    expect(
      Directory(attachmentStore.attachmentsDir(run.id)).existsSync(),
      isTrue,
    );

    final del = await service.deleteRun(run.id);

    expect(del, isA<Success<void>>());
    expect(
      Directory(attachmentStore.attachmentsDir(run.id)).existsSync(),
      isFalse,
    );
  });

  test('deleteRunsOfWorkflow deletes attachments folders on disk', () async {
    final res = await service.startRun(
      StartRunRequest(
        workflowId: 'wf-1',
        workspaceId: 'ws-1',
        attachments: [
          RunAttachmentPayload(
            fileName: 'shot.png',
            mimeType: 'image/png',
            data: base64Encode(pngBytes),
          ),
        ],
      ),
    );
    final run = res.valueOrNull!;
    await service.waitForActiveExecutions();
    await runsRepo.updateStatus(run.id, status: RunStatus.succeeded);
    expect(
      Directory(attachmentStore.attachmentsDir(run.id)).existsSync(),
      isTrue,
    );

    final del = await service.deleteRunsOfWorkflow('wf-1');

    expect(del.isSuccess, isTrue);
    expect(
      Directory(attachmentStore.attachmentsDir(run.id)).existsSync(),
      isFalse,
    );
  });

  test('deleteRun succeeds even when attachment deletion fails', () async {
    final harness = EngineHarness();
    const git = GitClient(_FakeProcessRunner());
    final failingService = RunService(
      runs: runsRepo,
      checkpoints: harness.checkpoints,
      events: eventsRepo,
      workspacePreparation: const WorkspacePreparationService(git: git),
      workflows: _SingleWorkflowRepository(workflow),
      workspaces: WorkspaceService(
        workspaces: _FakeWorkspaceRepository(workspaceDir.path),
        capabilities: const WorkspaceCapabilitiesService(git),
      ),
      engine: harness.engine,
      attachments: FakeRunAttachmentStore()..failDeletes = true,
    );
    await runsRepo.create(
      Run(
        id: 'run-fail-del',
        workflowId: 'wf-1',
        workflowName: workflow.name,
        workflowDefinition: workflow,
        workspaceId: 'ws-1',
        workspacePath: workspaceDir.path,
        status: RunStatus.succeeded,
        startedAt: DateTime.utc(2026),
      ),
    );

    final del = await failingService.deleteRun('run-fail-del');

    expect(del, isA<Success<void>>());
    expect(await runsRepo.getById('run-fail-del'), isA<FailureResult<Run>>());
  });
}
