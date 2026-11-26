---
name: agentic-hive
description: Use when the user wants to create, read, edit, duplicate or delete Agentic Hive workflows, or asks an agent to build or change a workflow through the hive MCP tools.
---

# Agentic Hive workflows

Manage workflows only through the `hive` MCP tools. Never edit workspace workflow files by hand. Tool schemas and field details come from the tools themselves; this skill only gives the flow.

## Flow

1. **Find the scope.** Call `list_workspaces` to see the workspaces and the Global scope. Pass `workspace` (id, root path or `global`) on the other tools when the current directory is not the workspace you mean.
2. **See what exists.** Call `list_workflows` for ids and revisions.
3. **Know the building blocks.** Call `list_building_blocks` before you create or edit a workflow. Use only the node types and agents it lists.
4. **Read compact first.** Call `get_workflow` with the default compact detail. Ask for full detail only when the compact text lacks what you need.
5. **Create in one call.** Call `create_workflow` with every node and edge, short unique node ids and the entry node. Problems in the graph are saved as a draft and returned as validation; fix them with an edit.
6. **Edit with patch operations.** Call `edit_workflow` with only the operations that change something, not the whole workflow. The operations apply together or not at all.
   - **Change a harness in place.** To switch a node between the headless harnesses (Claude Code, Codex, Gemini CLI, Antigravity), send `update_node` with the new `type`. The node keeps its id, label, position, edges and the config the new harness supports; the answer names the config fields it dropped. A change to or from any other node type is refused: use `remove_node` and `add_node`.
   - **Fall back on rate limit.** Set `fallback` in a headless harness node's config to an ordered list of `{harness, model?, effort?}`. When the node's harness reports a rate limit, the run switches to the next entry in the same folder. Effort only on harnesses that support it. A type change keeps the list; node overrides never change it.
7. **Copy instead of rebuilding.** Call `duplicate_workflow` to start from an existing workflow.

## Revision

- Every `get_workflow` and `list_workflows` result carries a `revision`. Send the revision you last read to `edit_workflow` and `delete_workflow`.
- Every successful edit returns a new revision. Use it for the next edit; do not reuse the old one.
- If an edit is refused as stale, someone changed the workflow. Call `get_workflow` again, check that your change still makes sense, then repeat the edit with the new revision. Never retry with the old revision.

## Deleting

- `delete_workflow` also removes the workflow's runs. Delete only what the user asked to delete.
- If it is refused because runs are active, do not try to stop them yourself. Tell the user to stop those runs in Agentic Hive, then try again.

## Token habits

- Read compact, edit by patch, and do not re-read a workflow after an edit: the result already has the summary, the new revision and the validation.
- Call `list_building_blocks` once per task, not before every edit.
- Do not paste whole workflows into the chat; refer to nodes by id.
