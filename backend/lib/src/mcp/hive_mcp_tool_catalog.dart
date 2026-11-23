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
  ];
}
