---
status: accepted
---

# Workspaces are registered entities, with scoped resources and first-class worktrees

Supersedes the definition of workspace in ADR 0004 ("one workspace per run, any folder"). The rest of ADR 0004 stands: snapshots in a shadow git repository, direct mode for non-git folders, and worktree isolation for git repositories. ADR 0004 is not edited; where it says "workspace" it means the folder a run works in, which this ADR calls the run's **target folder** (the root of a workspace, or one of its worktrees).

Before, a run carried a path typed at Start Run, and workflows and agents were global only. Now a **workspace** is a named, registered entity with exactly one root folder, every run belongs to one, and definitions can be global or workspace-scoped. We chose entities over "remember recent paths" because scoped definitions, a live tree of worktrees and runs, and the one-active-run guard all need a stable identity.

## Decisions

- **Workspace**: id, name and exactly one root folder, unique per folder (two workspaces cannot share a folder). Multi-root is out of scope.
- **Every run belongs to a workspace.** There are no global runs. Only definitions (workflows, agents, settings) can be global.
- **Non-git folders** are valid workspaces. They have only the primary checkout, no worktrees, and runs use direct mode with shadow-repo snapshots (ADR 0004). The worktree option is hidden with an explanation.
- **Ad-hoc terminals** outside runs are out of scope. Terminals of `TerminalHarnessNode` stay grouped under their run.

### Scope table

| Resource | Scope |
|---|---|
| Workflows | global or workspace |
| Agents | global or workspace; a workspace agent overrides a global one with the same `name` |
| Execution settings (default isolation mode, snapshot `ignorePatterns`, default shell) | global, with per-workspace override |
| App settings (CLI paths, theme) | global only |
| Runs, pauses, run terminals | always workspace |
| Hive MCP install into harnesses (ADR 0020) | global only |

Workflows never override each other: a global and a workspace workflow with the same name are both listed, with a scope badge. Agents resolve at run time from `<root>/.agents/agents` first, then `~/.agents/agents`.

### Storage layout

| Data | Location |
|---|---|
| Workspace registry, runs, worktree records, global workflows | SQLite (app data) |
| Workspace agents | `<root>/.agents/agents/*.md` |
| Global agents | `~/.agents/agents/*.md` (the user's shared library) |
| Workspace workflows | `<root>/.agentic-hive/workflows/<slug>.json` |
| Workspace setting overrides | `<root>/.agentic-hive/settings.json` |
| Worktree directories | `<app data>/worktrees/<workspace>/<name>` |

Files inside a workspace are versionable. Machine-specific settings stay global in SQLite. The backend watches the workspace folders so external edits (for example `git pull`) update the app live.

### Worktree rules

- A worktree belongs to a git workspace and has a name, branch and path. It is created from a base branch (default: the primary checkout's current branch) on a branch named by the user.
- Start Run targets the **primary checkout** (direct), an **existing worktree**, or a **new worktree** created on the fly (default branch `hive/<runId>`). This replaces the throwaway per-run worktree of ADR 0004.
- A worktree is removed only when the user asks, with confirmation, and never while a run is active in it. Its branch is deleted only if merged (`git branch -d`); otherwise it is kept with a notice. Nothing outside the worktree directory is ever deleted.
- **At most one active run per worktree**, the primary checkout included. This extends the direct-mode 409 guard and keeps snapshots and restore consistent. Parallel work uses separate worktrees.

### Workspace lifecycle

- **Add**: pick a folder; the name defaults to the folder name and is editable; git is auto-detected.
- **Remove**: unregisters only. It never deletes files or worktrees, and warns when runs are active.
- The app remembers the last open workspace across restarts.

### Migration

- Existing workflows (SQLite) become global.
- For each distinct run `workspacePath`, create a workspace named after the folder and attach those runs.
- Worktrees of old runs that still exist on disk appear under their workspace.
- Global agents move from the app-data `agents` folder into `~/.agents/agents` without overwriting existing files; conflicts are reported.
- `Settings.defaultWorkspaceDir` is retired, or used only to suggest the first workspace.
- The Drift `schemaVersion` bump uses the next free number at implementation time, and every schema-version assertion in tests is updated.

## Considered options

- **Keep a path per run, add recent-path history:** no scoping, no tree, no stable identity for the one-run-per-worktree guard.
- **Store workspace workflows and agents only in SQLite:** not versionable and invisible to other agents; rejected in favor of files in the folder.

## Consequences

- The Start Run request carries `workspaceId` and a target instead of `workspacePath`.
- Two sources of truth for workspace definitions (files and SQLite index) need watchers to stay consistent.
