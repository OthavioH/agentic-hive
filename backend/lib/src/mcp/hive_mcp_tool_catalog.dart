import 'package:dart_mcp/server.dart';

/// The single place where backend-served MCP tool definitions live.
abstract final class HiveMcpToolCatalog {
  static final _workspace = StringSchema(
    description:
        'Workspace id, root path or "global". Default: the workspace '
        'containing the current directory, else global.',
  );

  /// Tools served by the backend's `/api/v1/internal/mcp/tools` route.
  static final List<Tool> backendTools = <Tool>[
    Tool(
      name: 'list_workspaces',
      description:
          'List workspaces (and the Global scope) with their ids, roots and '
          'workflow counts.',
      inputSchema: ObjectSchema(
        properties: const <String, Schema>{},
        additionalProperties: false,
      ),
    ),
    Tool(
      name: 'list_workflows',
      description: 'List workflows in a scope with their ids and revisions.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{'workspace': _workspace},
        additionalProperties: false,
      ),
    ),
    Tool(
      name: 'get_workflow',
      description: 'Read one workflow: nodes, edges, validation and revision.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{
          'id': StringSchema(description: 'Workflow id from list_workflows.'),
          'detail': UntitledSingleSelectEnumSchema(
            values: const <String>['compact', 'full'],
            defaultValue: 'compact',
            description: 'compact text (default) or full JSON.',
          ),
          'workspace': _workspace,
        },
        required: const <String>['id'],
        additionalProperties: false,
      ),
    ),
    Tool(
      name: 'create_workflow',
      description:
          'Create a workflow from nodes and edges. Returns its id, revision '
          'and validation; graph problems are saved as a draft.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{
          'name': StringSchema(description: 'Workflow name.'),
          'description': StringSchema(description: 'Optional description.'),
          'nodes': ListSchema(
            description: 'Nodes with short unique ids and node types.',
            items: ObjectSchema(
              properties: <String, Schema>{
                'id': StringSchema(),
                'type': StringSchema(),
                'label': StringSchema(),
                'config': ObjectSchema(),
                'position': ObjectSchema(
                  properties: <String, Schema>{
                    'x': NumberSchema(),
                    'y': NumberSchema(),
                  },
                  required: const <String>['x', 'y'],
                ),
              },
              required: const <String>['id', 'type', 'label'],
            ),
          ),
          'edges': ListSchema(
            description: 'Edges with from/to ids and a source output.',
            items: ObjectSchema(
              properties: <String, Schema>{
                'from': StringSchema(),
                'to': StringSchema(),
                'output': StringSchema(),
                'maxRetries': IntegerSchema(),
              },
              required: const <String>['from', 'to', 'output'],
            ),
          ),
          'entryNodeId': StringSchema(),
          'workspace': _workspace,
        },
        required: const <String>['name', 'nodes', 'edges', 'entryNodeId'],
        additionalProperties: false,
      ),
    ),
    Tool(
      name: 'duplicate_workflow',
      description: 'Copy a workflow in the same scope with an optional name.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{
          'id': StringSchema(description: 'Workflow id from list_workflows.'),
          'name': StringSchema(description: 'Optional name of the copy.'),
          'workspace': _workspace,
        },
        required: const <String>['id'],
        additionalProperties: false,
      ),
    ),
    Tool(
      name: 'edit_workflow',
      description:
          'Apply patch operations to a workflow as one transaction. Needs the '
          'revision you read; returns a summary, the new revision and '
          'validation.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{
          'id': StringSchema(description: 'Workflow id from list_workflows.'),
          'revision': StringSchema(
            description:
                'Revision from your last get_workflow or list_workflows.',
          ),
          'operations': ListSchema(
            description:
                'Applied in order; if one fails none is applied. '
                'add_node {id, type, label, config?, position?}; '
                'update_node {id, label?, config?} (config merges, null '
                'removes a key); remove_node {id} (also its edges); '
                'connect {from, to, output, maxRetries?}; '
                'disconnect {from, to, output?}; set_entry {id}; '
                'set_meta {name?, description?}.',
            minItems: 1,
            items: ObjectSchema(
              properties: <String, Schema>{
                'op': UntitledSingleSelectEnumSchema(
                  values: const <String>[
                    'add_node',
                    'update_node',
                    'remove_node',
                    'connect',
                    'disconnect',
                    'set_entry',
                    'set_meta',
                  ],
                ),
                'id': StringSchema(),
                'type': StringSchema(),
                'label': StringSchema(),
                'config': ObjectSchema(),
                'position': ObjectSchema(
                  properties: <String, Schema>{
                    'x': NumberSchema(),
                    'y': NumberSchema(),
                  },
                  required: const <String>['x', 'y'],
                ),
                'from': StringSchema(),
                'to': StringSchema(),
                'output': StringSchema(),
                'maxRetries': IntegerSchema(),
                'name': StringSchema(),
                'description': StringSchema(),
              },
              required: const <String>['op'],
            ),
          ),
          'workspace': _workspace,
        },
        required: const <String>['id', 'revision', 'operations'],
        additionalProperties: false,
      ),
    ),
    Tool(
      name: 'delete_workflow',
      description:
          'Delete a workflow and its runs. Needs the revision you read. '
          'Refuses while runs are active; never stops runs. The answer lists '
          'workflows whose fan-out nodes reference it.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{
          'id': StringSchema(description: 'Workflow id from list_workflows.'),
          'revision': StringSchema(
            description:
                'Revision from your last get_workflow or list_workflows.',
          ),
          'workspace': _workspace,
        },
        required: const <String>['id', 'revision'],
        additionalProperties: false,
      ),
    ),
    Tool(
      name: 'list_building_blocks',
      description:
          'List the node types (config fields, outputs) and agents a workflow '
          'can use in a scope. Call it before create_workflow '
          'or edit_workflow. Includes how fan-out nodes and node overrides '
          'work.',
      inputSchema: ObjectSchema(
        properties: <String, Schema>{'workspace': _workspace},
        additionalProperties: false,
      ),
    ),
  ];
}
