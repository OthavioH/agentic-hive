# Agentic Hive

A visual orchestrator that chains terminal AI agents (harnesses) into a graph and runs the result locally.

## Definitions

**Agent**:
A `.md` file with frontmatter and a prompt that describes a role (for example, "reviewer"). It does not know which harness it will run on.
_Avoid_: bot, persona, assistant

**Harness**:
An agent CLI installed by the user that does an agent's work, such as Claude Code or Antigravity CLI.
_Avoid_: provider, model, engine

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

## Execution

**Run**:
One execution of a workflow, with its own state and history, belonging to one workspace and working in one of its worktrees or its primary checkout.
_Avoid_: job, instance, execution

**Pinned workflow**:
The copy of a workflow that a run takes when it starts and executes until it ends. Editing the workflow never changes the pinned workflow of a run that is active or already finished; only runs started after the edit use the new version.
_Avoid_: snapshot (which is about files), version, run workflow

**Run input**:
Optional free-text task input provided when starting a run and passed to the entry node.

**Workspace**:
A registered entity with an id, a name and exactly one root folder, unique per folder. Every run belongs to a workspace. The folder can be any folder, not necessarily a repository.
_Avoid_: project, repo, sandbox, working folder

**Primary checkout**:
The workspace's root folder itself, where the user's own files live. Runs there work directly, with snapshots.
_Avoid_: main worktree, root copy

**Run target**:
Where a run executes inside its workspace: the primary checkout, an existing worktree, or a new worktree created for the run. A run started without a target uses the primary checkout. The folder the target resolves to (the workspace root or one of its worktrees) is the run's _target folder_, and at most one run is active per target folder.
_Avoid_: run location, run mode

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
