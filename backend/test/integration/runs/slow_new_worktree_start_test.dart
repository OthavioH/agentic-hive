@Timeout(Duration(seconds: 90))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../http/support/harness.dart';
import 'support/slow_hook_repo.dart';

void main() {
  late String dataDir;
  late SlowHookRepo repo;
  late Backend backend;
  late SocketHttpClient http;
  final started = <String>[];
  Future<SocketResponse>? pendingPost;

  Future<String> registerWorkspace(Directory dir) async {
    final res = await http.post(
      '/api/v1/workspaces',
      body: jsonEncode(CreateWorkspaceRequest(rootPath: dir.path).toJson()),
    );
    expect(res.statusCode, 201);
    return Workspace.fromJson(res.json).id;
  }

  Future<String> createCommandWorkflow() async {
    final res = await http.post(
      '/api/v1/workflows',
      body: jsonEncode(
        const CreateWorkflowRequest(
          name: 'GitVersion',
          entryNodeId: 'n1',
          nodes: <WorkflowNode>[
            WorkflowNode(
              id: 'n1',
              type: NodeTypeId.command,
              label: 'Git version',
              position: WorkflowPosition(x: 0, y: 0),
              config: <String, Object?>{
                'command': 'git',
                'args': <String>['--version'],
              },
            ),
          ],
        ).toJson(),
      ),
    );
    expect(res.statusCode, 201);
    return WorkflowResponse.fromJson(res.json).workflow.id;
  }

  setUp(() async {
    started.clear();
    pendingPost = null;
    dataDir = (await createTempDir()).path;
    repo = await SlowHookRepo.create();
    backend = await startBackend(dataDir);
    http = SocketHttpClient(backend.socketPath);
    // Registered after backend and repo teardowns so LIFO runs this first.
    addTearDown(() async {
      repo.release();
      final pending = pendingPost;
      if (pending != null) {
        try {
          final res = await pending.timeout(ioTimeout);
          if (res.statusCode == 201) {
            final id = res.json['id'] as String?;
            if (id != null && !started.contains(id)) {
              started.add(id);
            }
          }
        } on Object {
          // Ignore errors from the in-flight POST during teardown.
        }
      }
      for (final id in started) {
        await http.post('/api/v1/runs/$id/cancel');
      }
      http.close();
    });
  });

  test(
    'POST /api/v1/runs with newWorktree answers 201 while post-checkout hook '
    'is blocked',
    () async {
      final workspaceId = await registerWorkspace(repo.dir);
      final workflowId = await createCommandWorkflow();

      final pending = http.post(
        '/api/v1/runs',
        body: jsonEncode(
          StartRunRequest(
            workflowId: workflowId,
            workspaceId: workspaceId,
            target: const RunTarget.newWorktree(),
          ).toJson(),
        ),
      );
      pendingPost = pending;

      await repo.waitUntilHookEntered();

      // 5 s timeout < 20 s maxBlock proves the response arrived while blocked.
      final res = await pending.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail(
          'POST /api/v1/runs did not answer while the post-checkout hook '
          'was blocked (#49)',
        ),
      );

      expect(res.statusCode, 201);

      final runJson = res.json;
      final runId = runJson['id']! as String;
      started.add(runId);

      expect(runJson['status'], 'preparing');
      final worktreePath = runJson['worktreePath'] as String?;
      expect(worktreePath, isNotNull);
      expect(runJson['worktreeBranch'], 'hive/$runId');

      repo.release();

      final deadline = DateTime.now().add(ioTimeout);
      String? lastStatus;
      while (DateTime.now().isBefore(deadline)) {
        final pollRes = await http.get('/api/v1/runs/$runId');
        expect(pollRes.statusCode, 200);
        lastStatus = pollRes.json['status'] as String?;
        if (lastStatus != 'preparing' && lastStatus != 'running') {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(
        lastStatus,
        'succeeded',
        reason:
            'Run did not reach succeeded within $ioTimeout (last: $lastStatus)',
      );

      final eventsRes = await http.get('/api/v1/runs/$runId/events');
      expect(eventsRes.statusCode, 200);
      final types = (eventsRes.json['items']! as List<Object?>)
          .map((e) => (e! as Map<String, Object?>)['type'])
          .toList();
      expect(
        types,
        containsAllInOrder(<String>[
          'run.preparing',
          'run.started',
          'run.succeeded',
        ]),
      );
      expect(Directory(worktreePath!).existsSync(), isTrue);
    },
    skip:
        'Red until #289 (backend: prepare new worktrees asynchronously) lands; '
        '#289 removes this skip.',
  );
}
