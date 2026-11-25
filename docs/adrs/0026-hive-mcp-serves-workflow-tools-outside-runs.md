---
status: accepted
---

# hive-mcp serves workflow tools outside runs

ADR 0015 made `hive-mcp` a proxy bound to one node attempt, and ADR 0020 installs it at user level in every harness, where outside a run it only answers that it is not inside a run. We now let any agent manage workflows through MCP, so the same `hive-mcp` also serves workflow tools (`list_workspaces`, `list_workflows`, `get_workflow`, `create_workflow`, `edit_workflow`, `delete_workflow`, `duplicate_workflow`, `list_building_blocks`) inside and outside runs. `report_result` and `ask_human` still require the run context. Outside a run the proxy finds the backend socket in the default user data folder, and it resolves the scope from an explicit `workspace` argument (id or root path), else from the workspace whose root contains the agent's current directory, else the Global scope. Because ADR 0020 already registers `hive` in each harness, external agents get these tools with no extra setup.

## Considered options

- **A second MCP executable for workflow management:** another binary to build, ship, install and keep version-compatible, for the same socket client.
- **Workflow tools only inside runs:** blocks the main use case, a user asking their own agent to build or change a workflow.

## Consequences

- Any local process that can start `hive-mcp` can edit workflows. This is the same trust boundary as the socket itself (ADR 0011): file permissions are the authentication.
- Edits use an optimistic `revision` (a hash of the workflow definition) so an agent never overwrites a change made in the app or by hand in a workspace workflow file.
- Through MCP, `delete_workflow` never forces: while the workflow has active runs it refuses and tells the user to stop them first. Editing a workflow never changes the pinned workflow of an existing run.
