@Timeout(Duration(seconds: 120))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/backend.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../http/support/harness.dart';
import 'support/slow_hook_repo.dart';

void main() {
  late String dataDir;
  late SlowHookRepo repo;
  late Backend backend;
  late SocketHttpClient http;
  late String workspaceId;
  late String workflowId;
  final started = <String>[];

  Future<String> registerWorkspace(Directory dir) async {
    final res = await http.post(
      '/api/v1/workspaces',
      body: jsonEncode(CreateWorkspaceRequest(rootPath: dir.path).toJson()),
    );
    expect(res.statusCode, 201);
    return Workspace.fromJson(res.json).id;
  }

  Future<String> createQuickWorkflow() async {
    final scriptDir = await createTempDir();
    final script = File(p.join(scriptDir.path, 'quick.dart'));
    await script.writeAsString('void main() {}\n');
    final res = await http.post(
      '/api/v1/workflows',
      body: jsonEncode(
        CreateWorkflowRequest(
          name: 'Quick',
          entryNodeId: 'n1',
          nodes: <WorkflowNode>[
            WorkflowNode(
              id: 'n1',
              type: NodeTypeId.command,
              label: 'Quick',
              position: const WorkflowPosition(x: 0, y: 0),
              config: <String, Object?>{
                'command': Platform.resolvedExecutable,
                'args': <String>[script.path],
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
    dataDir = (await createTempDir()).path;
    repo = await SlowHookRepo.create();
    backend = await startBackend(dataDir);
    http = SocketHttpClient(backend.socketPath);
    // Registered after startBackend so the hook is released and runs are
    // cancelled before the backend stops and temp directories are deleted.
    addTearDown(() async {
      await repo.release();
      for (final id in started) {
        await http.post('/api/v1/runs/$id/cancel');
      }
      http.close();
    });
    workspaceId = await registerWorkspace(repo.dir);
    workflowId = await createQuickWorkflow();
  });

  test(
    'newWorktree Start Run returns 201 preparing before post-checkout finishes',
    skip:
        'Red until #289 (Backend: prepare new worktrees asynchronously) '
        'makes Start Run answer before git worktree add finishes; '
        '#289 removes this skip.',
    () async {
      late SocketResponse res;
      try {
        res = await http
            .post(
              '/api/v1/runs',
              body: jsonEncode(
                StartRunRequest(
                  workflowId: workflowId,
                  workspaceId: workspaceId,
                  target: const RunTarget.newWorktree(),
                ).toJson(),
              ),
            )
            .timeout(const Duration(seconds: 5));
      } on TimeoutException {
        fail(
          'Start Run did not answer while post-checkout was still '
          'blocked (#49)',
        );
      }

      if (res.statusCode == 201) {
        started.add(res.json['id']! as String);
      }
      expect(res.statusCode, 201);
      final id = res.json['id']! as String;
      expect(res.json['status'], 'preparing');
      expect(res.json['worktreePath'], isNotNull);
      expect(
        p.normalize(res.json['worktreePath']! as String),
        p.normalize(p.join(dataDir, 'worktrees', workspaceId, id)),
      );
      expect(res.json['worktreeBranch'], 'hive/$id');

      await repo.release();

      final deadline = DateTime.now().add(ioTimeout);
      String? status;
      while (true) {
        final runRes = await http.get('/api/v1/runs/$id');
        expect(runRes.statusCode, 200);
        status = runRes.json['status'] as String?;
        if (status == 'succeeded') break;
        if (DateTime.now().isAfter(deadline)) {
          fail(
            'Run $id did not succeed within $ioTimeout (last status: $status)',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final eventsRes = await http.get('/api/v1/runs/$id/events');
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
    },
  );
}
