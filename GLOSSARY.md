# Agentic Hive

A visual orchestrator that chains terminal AI agents (harnesses) into a graph and runs the result locally.

## Definitions

**Agent**:
A `.md` file with frontmatter and a prompt that describes a role (for example, "reviewer"). It does not know which harness it will run on.
_Avoid_: bot, persona, assistant

**Skill**:
A folder with a `SKILL.md` that teaches a harness how to do something. Agentic Hive ships one skill that teaches a harness how to manage workflows through the `hive` MCP tools. It is not an Agent: an agent describes a role, a skill teaches a capability.
_Avoid_: plugin, extension

**Harness**:
An agent CLI installed by the user that does an agent's work, such as Claude Code or Antigravity CLI.
_Avoid_: provider, model, engine

**Model**:
The AI model a harness node asks its harness to use, named in that harness's own terms. Without one, the harness uses its own default.
_Avoid_: harness, provider, LLM (when naming the setting)

**Effort**:
How hard a harness node asks its harness to reason, on one scale shared by all harnesses: `low`, `medium`, `high` or `max`.
_Avoid_: reasoning, thinking budget, reasoning level

**Workflow**:
A graph of nodes and edges saved by the user. It is the recipe, not the execution.
_Avoid_: pipeline, flow, graph (when referring to the saved artifact)

**Node**:
One step of a workflow. It has a type (harness, command, validator, human approval) and one or more outputs.
_Avoid_: step, stage, task

**Edge**:
A link between nodes, labeled by the output that activates it (`onSuccess`, `onFailure` or a validator label).
_Avoid_: link, transition

**App**:
The desktop program the user opens, named Agentic Hive everywhere the user can see it (window, taskbar, process list, tray). It draws, edits and sends commands; it does not run work.
_Avoid_: frontend, client, UI (in anything user-facing)

**Backend**:
The local process that runs workflows and keeps state. It keeps running after the app closes.
_Avoid_: server, daemon (in anything user-facing)

**Revision**:
A token that identifies the exact content of a workflow at the moment it was read. A change based on an outdated revision is refused instead of overwriting newer content.
_Avoid_: version, etag

## Execution

**Run**:
One execution of a workflow, with its own state and history, belonging to one workspace and working in one of its worktrees or its primary checkout.
_Avoid_: job, instance, execution

**Pinned workflow**:
The copy of a workflow that a run takes when it starts and executes until it ends. Editing the workflow never changes the pinned workflow of a run that is active or already finished; only runs started after the edit use the new version. Unrelated to a pinned side-rail panel, which is only a display preference.
_Avoid_: snapshot (which is about files), version, run workflow

**Run input**:
Optional free-text task input provided when starting a run and passed to every node of the run. It may come with run attachments.

**Run attachment**:
An image provided with the run input when starting a run, available to the run's nodes until the run ends.
_Avoid_: upload, file input, asset

**Orphaned run**:
A run kept after its workflow was deleted because a forced delete could not confirm that its processes stopped. Its workflow id is cleared and its workflow name is kept; the user can retry its cancel and delete it.

**Workspace**:
A registered entity with an id, a name and exactly one root folder, unique per folder. Every run belongs to a workspace. The folder can be any folder, not necessarily a repository.
_Avoid_: project, repo, sandbox, working folder

**Primary checkout**:
The workspace's root folder itself, where the user's own files live. Runs there work directly, with snapshots.
_Avoid_: main worktree, root copy

**Run target**:
Where a run executes inside its workspace: the primary checkout, an existing worktree, or a new worktree created for the run. A run started without a target uses the primary checkout. The folder the target resolves to (the workspace root or one of its worktrees) is the run's _target folder_, and at most one run is active per target folder. The only exception is a parent run lending its folder to its own child runs, one at a time.
_Avoid_: run location, run mode

**Fan-out node**:
A node that takes a list from an earlier node's output and starts one child run for each item, then waits for all of them.
_Avoid_: map node, for-each node, batch node

**Parent run**:
The run that contains the fan-out node that started a child run.
_Avoid_: root run, outer run

**Child run**:
A run of a saved workflow started by a fan-out node for one item of its list. It is a full run with its own history and run target, linked to its parent run and deleted with it.
_Avoid_: subrun, spawned run, batch item

**Node override**:
A value for a node's agent, model or effort that replaces the node's own for one run only.
_Avoid_: parameter, binding, patch

**Scope**:
The level a definition (workflow, agent, execution settings) belongs to: the global scope or the workspace scope of one workspace.
_Avoid_: level, visibility, location

**Global scope**:
The level of definitions (workflows, agents, execution settings) available in every workspace.
_Avoid_: user scope, shared

**Workspace scope**:
The level of definitions that belong to one workspace and live in its folder. A workspace agent overrides a global agent of the same name.
_Avoid_: project scope, local scope

**Snapshot**:
The saved state of the run's working folder before a node, used to roll back.
_Avoid_: backup, commit

**Shadow repository**:
The isolated git repository kept outside the user's workspace where snapshots for a run are stored.
_Avoid_: shadow git, hidden repo, backup repo

**Worktree**:
A named, persistent working copy of a git workspace on its own branch. Runs can use it one at a time, and it is removed only when the user asks.
_Avoid_: clone, sandbox, temp copy

**Checkpoint**:
The saved state of the graph (position, attempts, node outputs) at the end of each node.
_Avoid_: save, snapshot (which is about files)

**Event log**:
The append-only sequence of structured lifecycle and execution events recorded for a run.
_Avoid_: trace, stdout log

**Circuit breaker**:
A safeguard that stops a run after consecutive infrastructure failures across nodes, preventing infinite crash loops.
_Avoid_: retry limit (which is per-edge `maxRetries`)

**Result contract**:
How an agent tells the backend it has finished and with which status: the `report_result` MCP tool or the `result.json` file.
_Avoid_: return value, exit status

**Pause**:
The state of a run waiting for a human answer, through an approval node or `ask_human`.
_Avoid_: block, wait

**Proposal**:
A value produced by an earlier node that an approval node shows to the human, who approves it as is, edits and approves it, or rejects it. The approved value is what later nodes receive.
_Avoid_: plan, suggestion, draft

**Active run**:
A run that has started and has not finished, failed, been cancelled, been interrupted by a backend restart, or entered `cancellationUncertain`. A paused or cancelling run is still active.
_Avoid_: live run, open run

**Active node**:
A node of an active run that is executing or paused right now.
_Avoid_: current step, live node

**Active agent**:
An agent that an active node is executing right now. An agent is never active on its own: it is only active through a node of a run.
_Avoid_: online agent, running agent (an agent is a file, not a service)

## Distribution

**Release**:
A published version of the product: a GitHub pre-release for a `vX.Y.Z` tag on `master` with one Bundle archive per released OS and a `SHA256SUMS` file.
_Avoid_: build, drop, distribution (as a noun for one version)

**Bundle**:
The folder a user runs: the app executable with the backend's `dart build cli` output in a `backend/` folder next to it (`backend/bin/server`, `backend/bin/hive_mcp`, and `backend/lib/` with SQLite and, on Linux, the executables' compiled programs).
_Avoid_: package, install folder, distribution
