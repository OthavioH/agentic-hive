import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/layered_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/agents/local_workspace_agent_repositories.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_service.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/building_blocks_text_formatter.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/tools/list_building_blocks_tool.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  late Directory tempDir;
  late Directory globalDir;
  late Directory repoDir;
  late MemoryWorkspaces workspaces;
  late NodeRegistry registry;
  late ListBuildingBlocksTool tool;

  final ws1 = Workspace(
    id: 'ws-1',
    name: 'App',
    rootPath: '',
    isGit: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  void writeAgent(
    String dir,
    String id,
    String name, {
    String description = '',
  }) {
    final descriptionLine = description.isEmpty
        ? ''
        : 'description: $description\n';
    File(p.join(dir, '$id.md'))
        .writeAsStringSync('---\nname: $name\n$descriptionLine---\nprompt');
  }

  Future<Result<String>> call({String? workspace}) =>
      tool.call(McpToolInput(arguments: {'workspace': ?workspace}));

  Future<String> body({String? workspace}) async {
    final result = await call(workspace: workspace);
    return switch (result) {
      Success(:final value) => value,
      FailureResult(:final failure) => fail(failure.message),
    };
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('building_blocks_');
    addTearDown(() => tempDir.delete(recursive: true));
    globalDir = Directory(p.join(tempDir.path, 'global'))..createSync();
    repoDir = Directory(p.join(tempDir.path, 'repo'))..createSync();
    Directory(p.join(repoDir.path, '.agents', 'agents'))
        .createSync(recursive: true);

    final ws = Workspace(
      id: ws1.id,
      name: ws1.name,
      rootPath: repoDir.path,
      isGit: false,
      createdAt: ws1.createdAt,
      updatedAt: ws1.updatedAt,
    );
    workspaces = MemoryWorkspaces([ws]);
    final agents = AgentService(
      LocalAgentRepository(agentsDir: globalDir.path),
      layer: LayeredAgentRepository.new,
      workspaces: LocalWorkspaceAgentRepositories(
        findWorkspace: (id) async => id == 'ws-1'
            ? Success(ws)
            : const FailureResult(NotFoundFailure('Workspace not found.')),
      ),
    );

    registry = NodeRegistry();
    for (final descriptor in NodeDescriptors.all) {
      registry.register(descriptor, () => throw UnimplementedError());
    }

    tool = ListBuildingBlocksTool(
      scopes: McpScopeResolver(
        workspaces: workspaces,
        worktreesDir: p.join(tempDir.path, 'worktrees'),
        path: p.context,
      ),
      nodeTypes: () => registry.descriptors,
      agents: agents,
      formatter: const BuildingBlocksTextFormatter(),
    );
  });

  group('list_building_blocks', () {
    test('T-T1 first line is the scope header', () async {
      final workspaceText = await body(workspace: 'ws-1');
      expect(
        workspaceText.split('\n').first,
        startsWith('Scope: workspace "App"'),
      );

      final globalText = await body(workspace: 'global');
      expect(
        globalText.split('\n').first,
        'Scope: Global (from the workspace argument)',
      );
    });

    test('T-T2 lists every node type with fields and outputs', () async {
      final text = await body(workspace: 'global');

      expect(text, contains('Node types (10).'));
      expect(
        text,
        contains(
          [
            '- validator.review -> approved|changesRequested\n',
            '  config: harnessType*=harness.claude_code|harness.codex|',
            'harness.gemini_cli|harness.antigravity, agentId, reviewCriteria, ',
            'timeoutSeconds:int; set at least one of agentId|reviewCriteria',
          ].join(),
        ),
      );
      expect(
        text,
        contains(
          [
            '- validator.checklist -> onSuccess|onFailure\n',
            '  config: rules*:[{label*, kind*=fileExists|commandSucceeds|',
            'outputMatchesRegex, path, command, workingDirectory, pattern}]',
          ].join(),
        ),
      );
    });

    test('T-T6 list_building_blocks describes model and effort', () async {
      final text = await body(workspace: 'global');
      expect(text, contains('model, effort=low|medium|high|max'));
    });

    test('T-T3 a node type registered after the tool was built appears '
        'without changing the tool', () async {
      final before = await body(workspace: 'global');
      expect(before, contains('Node types (10).'));
      expect(before, isNot(contains('- test.echo ->')));

      registry.register(
        NodeDescriptor(
          typeId: 'test.echo',
          category: NodeCategory.execution,
          availableOutputs: ['onSuccess'],
          defaultConfig: () => <String, Object?>{},
          validateConfig: _noIssues,
          configFields: [
            const NodeConfigField(name: 'message', required: true),
            const NodeConfigField(name: 'mode', values: {'loud', 'quiet'}),
          ],
        ),
        () => throw UnimplementedError(),
      );

      final after = await body(workspace: 'global');
      expect(after, contains('Node types (11).'));
      expect(
        after,
        contains(
          '- test.echo -> onSuccess\n  config: message*, mode=loud|quiet',
        ),
      );
    });

    test('T-T4 workspace agents override global ones by name', () async {
      writeAgent(globalDir.path, 'reviewer', 'Reviewer');
      writeAgent(globalDir.path, 'planner', 'Planner');
      writeAgent(
        p.join(repoDir.path, '.agents', 'agents'),
        'team-reviewer',
        'Reviewer',
      );

      final text = await body(workspace: 'ws-1');

      expect(text, contains('- team-reviewer "Reviewer" (workspace)'));
      expect(text, contains('- planner "Planner" (global)'));
      expect(text, isNot(contains('- reviewer "Reviewer"')));
      expect(text, contains('Agents (2;'));
    });

    test(
      'T-T5 a workspace file with the same id hides the global one',
      () async {
        writeAgent(globalDir.path, 'reviewer', 'Global Reviewer');
        writeAgent(
          p.join(repoDir.path, '.agents', 'agents'),
          'reviewer',
          'Ws Reviewer',
        );

        final text = await body(workspace: 'ws-1');

        expect(text, contains('- reviewer "Ws Reviewer" (workspace)'));
        expect(text, isNot(contains('"Global Reviewer"')));
      },
    );

    test('T-T6 Global scope lists only global agents', () async {
      writeAgent(globalDir.path, 'reviewer', 'Reviewer');
      writeAgent(globalDir.path, 'planner', 'Planner');
      writeAgent(
        p.join(repoDir.path, '.agents', 'agents'),
        'team-reviewer',
        'Reviewer',
      );

      final text = await body(workspace: 'global');

      expect(text, contains('- reviewer "Reviewer" (global)'));
      expect(text, contains('- planner "Planner" (global)'));
      expect(text, isNot(contains('team-reviewer')));
    });

    test('T-T7 broken agent files are counted, not listed', () async {
      File(p.join(globalDir.path, 'broken.md'))
          .writeAsStringSync('no frontmatter');
      writeAgent(globalDir.path, 'planner', 'Planner');

      final text = await body(workspace: 'global');

      expect(text, isNot(contains('broken')));
      expect(text, endsWith('1 agent with file errors omitted.'));
    });

    test(
      'T-T8 unknown workspace fails with the list_workspaces hint',
      () async {
        final result = await call(workspace: 'nope');

        expect(result, isA<FailureResult<String>>());
        final failure = (result as FailureResult<String>).failure;
        expect(failure, isA<NotFoundFailure>());
        expect(failure.message, contains('see list_workspaces'));
      },
    );

    test('T-T9 the tool name is list_building_blocks', () {
      expect(tool.name, 'list_building_blocks');
    });
  });
}

List<NodeConfigIssue> _noIssues(JsonMap config) => const [];
