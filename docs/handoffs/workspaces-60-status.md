# Workspaces (#60): orchestration status

Snapshot taken when the owner paused the work. The integration branch is `OthavioH/feature-workspaces`, with draft PR #82 into `development`. Nothing here is in `development` yet. This file is a handoff note: delete it before the PR is marked ready.

## Tickets

| # | Ticket | State | Where |
|---|---|---|---|
| 61 | ADR 0022 + glossary | Merged | integration branch |
| 62 | Workspace entity, schema v7, CRUD API | Merged | integration branch |
| 63 | `HiveTreeItem` catalog component | Merged, owner approved in Widgetbook | integration branch |
| 64 | Global agents in `~/.agents/agents` | Merged | integration branch |
| 65 | Workspace registry UI | Merged | integration branch |
| 70 | Worktrees backend | Merged | integration branch |
| 73 | Side rail tree wireframe (pass 1) | Merged, owner approved | integration branch |
| 69 | Per-workspace execution settings | **Interrupted, unverified WIP** | branch `OthavioH/feature-workspace-settings`, commit `360e8c7` (28 files, backend + shared + frontend, with tests) |
| 67 | Workspace-scoped agents | **Interrupted, early WIP** | branch `OthavioH/feature-workspace-agents`, commit `8dc3eb9` (shared contracts only: `AgentScope`, scope on `AgentSummary`/`AgentDetail`/agents-changed payload) |
| 66 | Start Run uses a workspace | Never started | none (branch `OthavioH/start-run-workspace-2` is just the integration tip) |
| 68 | Workspace-scoped workflows | Never started | none (branch `OthavioH/workspace-workflows-2` is just the integration tip) |
| 71 | Run target + one active run per worktree | Blocked by 66 | |
| 72 | Start Run dialog: where to run | Blocked by 71 | |
| 74 | Side rail tree: live updates | Blocked by 71 | |
| 75 | Side rail tree: styling pass | Owner's (`ready-for-human`), blocked by 74 | |

After the tickets: final `code-review` of the integration branch, one fixer worker, mark PR #82 ready, remove retained worktrees.

## Resuming

- Start #66 and #68 from scratch on the current integration tip. Start #67 and #69 from their WIP branches (merge the integration tip first, then review the WIP against the issue's acceptance criteria; none of it was verified by `dart analyze`, format or tests).
- Orca Run: `run_e44499de49f7`. The Tasks for 66, 67, 68, 69 are in a stopped state; retry with `worker-start --task <id> --retry-of <dispatch>`, or start new Tasks. Each start chain is limited to three failed starts by the circuit breaker.
- Team approved by the owner: Claude Sonnet 5.5 (medium) for docs, backend/shared, scope tickets and events (#74); agy (Antigravity) with `gemini-4-hydrogen-medium` for the frontend implementer and the design-system implementer; the same Hydrogen at low for the merger; Claude Opus 5.5 (high) for the final review. Never Gemini 4 Argon.
- Merges so far were done by the coordinator (fast-forward, or `--no-ff` in a temporary worktree), not by a merger worker.

## Decisions and open points for the owner

- **Workspace DELETE cascades the finished runs' history** (#62). The spec only says "unregister, never delete files or worktrees". Confirm, or change to "refuse while the workspace has any run".
- **Worktree path is keyed by workspace id**: `<worktreesDir>/<workspaceId>/<name>`, not by workspace name (#70). Worktrees have no table; `git worktree list` is the source of truth and the id is the directory name (the primary checkout is `primary`). `DELETE ...?force=true` removes a dirty worktree (not in the issue).
- **Tree wireframe gaps** (#73): the gallery has no capture for a run with a pending pause highlighted, nor for a non-git workspace. `SideRailTree` sits beside `HiveSideRail` as a catalog-gap workaround; the design system has no tree slot yet.
- **Backend tests flake under load**: `lifecycle_test` ("stale socket ... killed process"), `process_tree_killer` and `runs_api_integration` time out on a busy machine and pass alone. Run the full backend suite on an idle machine before the final review.
- The TDD red step was not observed on #70 (tests passed on first run).

## Lessons for the next run

- `worker-list` `liveness=live` only means the terminal is open. Check `worker-show` for `activity=working` and read the terminal. Two workers (#66, #68) sat on an empty prompt after a start reported as `outcome_unknown`; the task never reached the agent.
- Starting four or more Claude workers at once may cause memory pressure (an earlier full backend run was killed). Four terminals were also closed externally once, with their worktrees; no work was lost because none had committed.
- agy start can time out on the "Introducing Gemini 4 Neon" banner; release the failed terminal and retry on the same Task in the existing worktree.
- Uncommitted edits to `GLOSSARY.md` (terms **App** and **Backend**) existed in the owner's main checkout when the work started; they are not part of this work and may conflict with the glossary merge.
