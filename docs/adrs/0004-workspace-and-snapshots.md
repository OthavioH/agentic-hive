---
status: partially superseded by ADR-0022 (the definition of workspace)
---

# One workspace per run, with snapshots in a shadow git repository

Stepping back in the graph does not undo what the agent changed in the files. Each run has a workspace (any folder), and before each node the backend snapshots it into a shadow git repository kept outside the user's folder (its own `--git-dir`, with `--work-tree` pointing at the workspace). Rollback then works for any kind of file, not just code, and does not interfere with the user's git. When the workspace is already a user repository and the run needs isolation, we use a separate git worktree.

## Considered options

- **Require the workspace to be a git repository:** would limit the product to software development.
- **Copy the whole folder before each node:** simple, but slow and costly on disk for large folders.

## Consequences

- Git becomes an installation requirement, even for people who do not program.
- Very large or binary files can make snapshots slow; we will need exclusion rules per workspace.
