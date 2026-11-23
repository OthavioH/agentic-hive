import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/layered_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<void> _write(
  Directory dir,
  String id,
  String name,
  String prompt,
) async {
  await dir.create(recursive: true);
  await File(p.join(dir.path, '$id.md'))
      .writeAsString('---\nname: $name\n---\n$prompt');
}

void main() {
  late Directory root;
  late Directory globalDir;
  late Directory workspaceDir;
  late LayeredAgentRepository layered;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('layered_agents_');
    addTearDown(() => root.delete(recursive: true));
    globalDir = Directory(p.join(root.path, 'global'));
    workspaceDir = Directory(p.join(root.path, 'ws', '.agents', 'agents'));
    layered = LayeredAgentRepository(
      global: LocalAgentRepository(agentsDir: globalDir.path),
      workspace: LocalAgentRepository(
        agentsDir: workspaceDir.path,
        scope: AgentScope.workspace,
      ),
    );
  });

  test('scope is stamped on list and detail results', () async {
    await _write(globalDir, 'a', 'Global A', 'g');
    await _write(workspaceDir, 'b', 'Workspace B', 'w');

    final list = (await layered.list()).valueOrNull!;
    expect(
      {for (final s in list) s.id: s.scope},
      {'a': AgentScope.global, 'b': AgentScope.workspace},
    );
    final detail = (await layered.getById('b')).valueOrNull!;
    expect(detail.scope, AgentScope.workspace);
  });

  test('workspace agent overrides a global agent with the same id', () async {
    await _write(globalDir, 'reviewer', 'Global Reviewer', 'global prompt');
    await _write(workspaceDir, 'reviewer', 'Ws Reviewer', 'workspace prompt');

    final detail = (await layered.getById('reviewer')).valueOrNull!;
    expect(detail.scope, AgentScope.workspace);
    expect(detail.prompt, 'workspace prompt');

    final list = (await layered.list()).valueOrNull!;
    final entries = list.where((s) => s.id == 'reviewer').toList();
    expect(entries, hasLength(2));
    final ws = entries.singleWhere((s) => s.scope == AgentScope.workspace);
    final global = entries.singleWhere((s) => s.scope == AgentScope.global);
    expect(ws.overridden, isFalse);
    expect(global.overridden, isTrue);
  });

  test('falls back to global when the workspace has no such agent', () async {
    await _write(globalDir, 'planner', 'Planner', 'plan');
    final detail = (await layered.getById('planner')).valueOrNull!;
    expect(detail.scope, AgentScope.global);
  });

  test('unknown id is NotFound', () async {
    final result = await layered.getById('missing');
    expect(
      (result as FailureResult<AgentDetail>).failure,
      isA<NotFoundFailure>(),
    );
  });

  test('missing workspace folder lists only global agents', () async {
    await _write(globalDir, 'a', 'A', 'g');
    final list = (await layered.list()).valueOrNull!;
    expect(list.map((s) => s.id), ['a']);
  });
}
