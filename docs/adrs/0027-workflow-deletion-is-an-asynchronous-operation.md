---
status: accepted
---

# Workflow deletion is an asynchronous operation

Deleting a workflow deletes its runs, and a forced delete first stops every active run and waits until each process tree has exited (ADR 0009). That can take longer than the app's 15 s request timeout, which would show a network error while the backend finishes and make a retry answer "not found". So `DELETE /api/v1/workflows/{id}` does only the synchronous checks (stale `revision`, active runs without `force`), then answers `202` with an operation id and works in the background. Progress and the result (`deletedRuns`, `orphanedRuns`) come through WebSocket events and a status endpoint, and the workflow stays in the list marked as deleting, refusing edits, duplicates and new runs until the operation ends.

## Considered options

- **Keep the delete synchronous and give that request a longer timeout:** any fixed limit is a guess, since the time grows with the number of runs and the size of their shadow repositories; the false failure only moves to a bigger number.
- **Raise the global timeout:** makes every slow call fail later.

## Consequences

- Operation state lives in memory, last 50 operations. If the backend restarts mid-operation the workflow returns to normal and the user repeats the delete; a repeated delete of an already deleted workflow counts as success in the app.
- Clients that cannot use WebSocket, such as the `hive-mcp` proxy (ADR 0026), poll the status endpoint; the MCP `delete_workflow` waits a bounded time and otherwise answers that the deletion is in progress.
- A run that ends in, or already was in, `cancellationUncertain` is kept as an orphaned run so the user can retry its cancel.
