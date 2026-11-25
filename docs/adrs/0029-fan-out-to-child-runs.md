---
status: proposed
---

# Fan-out runs each item as a child run of a saved workflow

A workflow often produces a list whose length is only known at run time (for example, the issues a planner created), and each item needs its own agent, model and effort, its own isolated folder, and its own visible progress. The engine only runs the branches drawn in the graph, all branches of a run share one target folder, and at most one run is active per target folder (ADR 0025). We add a **fan-out node** that starts one **child run** per item instead of creating branches inside the parent run, because a child run already has its own checkpoints, pauses, cancellation, snapshots and monitor entry.

## Decisions

- **What a child runs.** The fan-out node references a saved workflow by id, resolved in the parent run's workspace: workspace scope first, then global. Workflow validation (app and MCP tools) reports a reference that does not resolve; at run time an unresolved reference fails the node before any child starts. The child workflow can also be run on its own. A child workflow may not contain a fan-out node (no nesting in v1); workflow validation refuses it.
- **Pinned workflow.** Each execution of the fan-out node pins the child workflow once, when it starts, and every child of that execution runs that same pinned workflow. A re-run (below) pins again, so a fixed child workflow applies to the retried items.
- **Items.** The node reads a list from an earlier node's output (`itemsPath`). Optional `inputField`, `overridesField` and `nameField` select the parts of each item. Without `inputField`, the whole item is the child's run input: a string as is, anything else as formatted JSON. The parent's run input is not passed on.
- **Node overrides.** An item may override `agentId`, `model` and `effort` of nodes of the child workflow, by node id. The harness type stays fixed by the node. Overrides are validated when the child is created; an invalid override fails only that child, before it starts. The same overrides can be given when starting any run.
- **Run target.** In a git workspace each child gets a new worktree, branched from the HEAD commit of the parent's target folder when the fan-out starts; uncommitted changes there are not included and the event log records a warning. The worktree is named from `nameField` or `<fan-out label>-<n>` and is never removed automatically. In a workspace without git, children run one at a time in the parent's target folder, which the parent lends to them; this is the only exception to one active run per target folder.
- **Concurrency.** A per-node limit of simultaneous children, default 2.
- **Limits and bad input.** An empty list ends with `onSuccess`, an empty result and a warning event. A missing path or a value that is not a list fails the node. More items than the per-node cap (default 20) fails the node before any child starts.
- **Completion.** The parent waits for every child; one failure does not stop the others. The node ends with `onSuccess` only if every child succeeded, otherwise `onFailure`. Its output lists each child's status, run id and final output.
- **Re-running.** When an edge leads back to the fan-out node, only items whose last child did not succeed start a new child; succeeded items reuse their previous result. Items are matched by index, or by name when `nameField` is set.
- **Pauses.** A pause inside a child appears in the pause list linked to its parent. The parent stays `running` while it waits, and other children keep running.
- **Cancellation.** Cancelling the parent cancels every child and is reported only after every child confirms its process tree exited. Cancelling one child counts as that child's failure.
- **Deleting the child workflow.** Allowed, and ADR 0027 applies unchanged: its runs are deleted, including children of finished parents, and active children refuse the delete unless it is forced, which cancels them and counts each as a failure for its parent. The confirmation and the MCP answer list the workflows whose fan-out nodes reference it. A parent's output keeps the ids of deleted children, shown as deleted.
- **Deleting the parent.** Deleting a parent run, or the workflow it belongs to, deletes its child runs with it; their worktrees are kept (ADR 0025). The active-run check of a delete includes the children.
- **Restart.** Each child follows the normal recovery of an interrupted run. The parent waits until every child reaches a final state; an interrupted child is not final.
- **Rollback.** The parent's snapshot before the fan-out node covers only the parent's target folder. Child worktrees keep their own snapshots. On interrupted resume, the parent skips its pre-node rollback for a fan-out node whose children used the lent folder (non-git workspace), so succeeded children's work stays and their reuse stays valid.

## Considered options

- **Parallel branches inside the parent run.** Rejected: every branch shares the run's single target folder and shadow repository, snapshots are serialized for that reason (ADR 0004), and per-item progress would need a second monitor model.
- **The subgraph after the fan-out node, inside the same workflow.** Rejected: the editor would need a way to delimit a region of the canvas; a saved workflow is reusable and testable on its own.
- **Refusing fan-out in workspaces without git.** Rejected: the product is generic (root `AGENTS.md`). Lending the folder sequentially keeps it usable.
- **Templates in node configs (`{{item.model}}`).** Rejected for v1: overrides by node id cover agent, model and effort without a template language.
- **Each child pins the child workflow when it starts.** Rejected: an edit in the middle of a fan-out would leave children of one execution on different versions.
- **Refusing to delete a workflow that a fan-out node references.** Rejected: a block whose cause lives in another workflow is hard to understand; listing the references is enough.
- **Keeping child runs when their parent is deleted.** Rejected: children only exist as part of their parent and would become noise in the run list.

## Consequences

- Runs gain an optional link to a parent run and a fan-out node; the run list and the canvas show children under their parent.
- Permissions follow ADR 0021 unchanged: a child in its own worktree runs in worktree isolation, a child in a lent folder runs in direct mode.
- The workflow MCP tools (ADR 0026) and the workflow schema in `shared/` must describe the fan-out node, through its `NodeDescriptor.configFields`, and node overrides.
- Workflow deletion (ADR 0027) must find references from fan-out nodes and include child runs in its cascade and active-run check.
- Depends on model and effort being first-class harness node settings, and is most useful after approval proposals, which let a human edit the item list before the fan-out starts.
