import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) => jsonDecode(jsonEncode(json)) as JsonMap;

void main() {
  final timestamp = DateTime.utc(2026, 11, 23, 9);

  group('DefinitionScope', () {
    test('round-trips global and workspace scopes', () {
      const global = GlobalScope();
      const workspace = WorkspaceScope('ws-1');

      expect(DefinitionScope.fromJson(_overTheWire(global.toJson())), global);
      expect(
        DefinitionScope.fromJson(_overTheWire(workspace.toJson())),
        workspace,
      );
      expect(global.wireName, 'global');
      expect(workspace.wireName, 'workspace');
      expect(global.toJson(), {'scope': 'global'});
      expect(workspace.toJson(), {'scope': 'workspace', 'workspaceId': 'ws-1'});
    });

    test('decodes missing scope as GlobalScope', () {
      expect(DefinitionScope.fromJson(const {}), const GlobalScope());
      expect(
        DefinitionScope.fromJson(const {'scope': null}),
        const GlobalScope(),
      );
    });

    test('throws FormatException for workspace without non-blank id', () {
      expect(
        () => DefinitionScope.fromJson(const {'scope': 'workspace'}),
        throwsFormatException,
      );
      expect(
        () => DefinitionScope.fromJson(const {
          'scope': 'workspace',
          'workspaceId': '',
        }),
        throwsFormatException,
      );
      expect(
        () => DefinitionScope.fromJson(const {
          'scope': 'workspace',
          'workspaceId': '   ',
        }),
        throwsFormatException,
      );
    });

    test('throws FormatException for unknown scope', () {
      expect(
        () => DefinitionScope.fromJson(const {'scope': 'bogus'}),
        throwsFormatException,
      );
    });

    test('equality and hashCode', () {
      expect(const GlobalScope(), equals(const GlobalScope()));
      expect(const GlobalScope().hashCode, const GlobalScope().hashCode);
      expect(
        const WorkspaceScope('ws-1'),
        equals(const WorkspaceScope('ws-1')),
      );
      expect(
        const WorkspaceScope('ws-1').hashCode,
        const WorkspaceScope('ws-1').hashCode,
      );
      expect(
        const WorkspaceScope('ws-1'),
        isNot(equals(const WorkspaceScope('ws-2'))),
      );
      expect(const GlobalScope(), isNot(equals(const WorkspaceScope('ws-1'))));
    });

    test('ofWorkspaceId and workspaceIdOrNull convert at wire boundaries', () {
      expect(DefinitionScope.ofWorkspaceId(null), const GlobalScope());
      expect(DefinitionScope.ofWorkspaceId(''), const GlobalScope());
      expect(DefinitionScope.ofWorkspaceId('  '), const GlobalScope());
      expect(
        DefinitionScope.ofWorkspaceId('ws-1'),
        const WorkspaceScope('ws-1'),
      );
      expect(const GlobalScope().workspaceIdOrNull, isNull);
      expect(const WorkspaceScope('ws-1').workspaceIdOrNull, 'ws-1');
    });
  });

  group('Wire golden tests', () {
    test('WorkflowSummary global and workspace wire JSON', () {
      final globalLiteral = <String, Object?>{
        'id': 'wf-1',
        'name': 'WF',
        'nodeCount': 1,
        'edgeCount': 0,
        'hasValidationErrors': false,
        'updatedAt': '2026-11-23T09:00:00.000Z',
        'scope': 'global',
        'deleting': false,
      };
      final workspaceLiteral = <String, Object?>{
        'id': 'wf-1',
        'name': 'WF',
        'nodeCount': 1,
        'edgeCount': 0,
        'hasValidationErrors': false,
        'updatedAt': '2026-11-23T09:00:00.000Z',
        'scope': 'workspace',
        'workspaceId': 'ws-1',
        'deleting': false,
      };

      final globalSummary = WorkflowSummary(
        id: 'wf-1',
        name: 'WF',
        nodeCount: 1,
        edgeCount: 0,
        hasValidationErrors: false,
        updatedAt: timestamp,
      );
      final workspaceSummary = globalSummary.copyWith(
        scope: const WorkspaceScope('ws-1'),
      );

      expect(_overTheWire(globalSummary.toJson()), globalLiteral);
      expect(WorkflowSummary.fromJson(globalLiteral), globalSummary);
      expect(_overTheWire(workspaceSummary.toJson()), workspaceLiteral);
      expect(WorkflowSummary.fromJson(workspaceLiteral), workspaceSummary);
    });

    test('WorkflowResponse global and workspace wire JSON', () {
      final workflow = Workflow(
        id: 'wf-1',
        name: 'WF',
        nodes: const [],
        edges: const [],
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      const validation = WorkflowValidationResult(isValid: true);
      final globalLiteral = <String, Object?>{
        'workflow': _overTheWire(workflow.toJson()),
        'validation': _overTheWire(validation.toJson()),
        'scope': 'global',
      };
      final workspaceLiteral = <String, Object?>{
        'workflow': _overTheWire(workflow.toJson()),
        'validation': _overTheWire(validation.toJson()),
        'scope': 'workspace',
        'workspaceId': 'ws-1',
      };

      final globalResponse = WorkflowResponse(
        workflow: workflow,
        validation: validation,
      );
      final workspaceResponse = globalResponse.copyWith(
        scope: const WorkspaceScope('ws-1'),
      );

      expect(_overTheWire(globalResponse.toJson()), globalLiteral);
      expect(WorkflowResponse.fromJson(globalLiteral), globalResponse);
      expect(_overTheWire(workspaceResponse.toJson()), workspaceLiteral);
      expect(WorkflowResponse.fromJson(workspaceLiteral), workspaceResponse);
    });

    test('WorkflowReference global and workspace wire JSON', () {
      const globalLiteral = <String, Object?>{
        'workflowId': 'wf-parent',
        'workflowName': 'Parent',
        'scope': 'global',
        'nodeIds': ['n1'],
      };
      const workspaceLiteral = <String, Object?>{
        'workflowId': 'wf-parent',
        'workflowName': 'Parent',
        'scope': 'workspace',
        'workspaceId': 'ws-1',
        'nodeIds': ['n1'],
      };

      const globalRef = WorkflowReference(
        workflowId: 'wf-parent',
        workflowName: 'Parent',
        nodeIds: ['n1'],
      );
      const workspaceRef = WorkflowReference(
        workflowId: 'wf-parent',
        workflowName: 'Parent',
        scope: WorkspaceScope('ws-1'),
        nodeIds: ['n1'],
      );

      expect(_overTheWire(globalRef.toJson()), globalLiteral);
      expect(WorkflowReference.fromJson(globalLiteral), globalRef);
      expect(_overTheWire(workspaceRef.toJson()), workspaceLiteral);
      expect(WorkflowReference.fromJson(workspaceLiteral), workspaceRef);
    });

    test('AgentSummary adds workspaceId only on workspace scope', () {
      final globalSummary = AgentSummary(
        id: 'a',
        name: 'A',
        contentHash: 'h',
        updatedAt: timestamp,
      );
      final workspaceSummary = globalSummary.copyWith(
        scope: const WorkspaceScope('ws-1'),
      );

      final globalJson = _overTheWire(globalSummary.toJson());
      final workspaceJson = _overTheWire(workspaceSummary.toJson());

      expect(globalJson['scope'], 'global');
      expect(globalJson.containsKey('workspaceId'), isFalse);
      expect(workspaceJson['scope'], 'workspace');
      expect(workspaceJson['workspaceId'], 'ws-1');
      expect(AgentSummary.fromJson(globalJson), globalSummary);
      expect(AgentSummary.fromJson(workspaceJson), workspaceSummary);
    });

    test('AgentDetail adds workspaceId only on workspace scope', () {
      final globalDetail = AgentDetail(
        id: 'a',
        name: 'A',
        contentHash: 'h',
        updatedAt: timestamp,
      );
      final workspaceDetail = globalDetail.copyWith(
        scope: const WorkspaceScope('ws-1'),
      );

      final globalJson = _overTheWire(globalDetail.toJson());
      final workspaceJson = _overTheWire(workspaceDetail.toJson());

      expect(globalJson['scope'], 'global');
      expect(globalJson.containsKey('workspaceId'), isFalse);
      expect(workspaceJson['scope'], 'workspace');
      expect(workspaceJson['workspaceId'], 'ws-1');
      expect(AgentDetail.fromJson(globalJson), globalDetail);
      expect(AgentDetail.fromJson(workspaceJson), workspaceDetail);
    });
  });
}
