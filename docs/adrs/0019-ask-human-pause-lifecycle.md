---
status: accepted
---

# Hybrid lifecycle for `ask_human` pauses across live sessions and backend restarts

ADR 0007 states that a paused run keeps nothing in memory and resumes from a SQLite checkpoint, while ADR 0015 and the result contract introduce `ask_human` as a blocking MCP tool call inside a running harness process. Keeping the harness process alive avoids losing in-flight conversation context when the human answers quickly, whereas surviving a backend restart requires durable checkpoint recovery.

When a `HarnessNode` calls `ask_human`:

- The backend persists a `Pause` record and a `Checkpoint` in SQLite, transitions the run to `paused`, and holds the `hive-mcp` HTTP request open in memory via `HumanPauseGateway` while the backend stays up. When the human answers, `HumanPauseGateway` returns the answer to `hive-mcp` so the agent continues in the same process.
- If the backend restarts while the run is `paused` on `ask_human`, the harness process and the in-memory HTTP waiter are gone, while the `Pause` remains `pending` in SQLite. When the human later answers that `Pause`, the backend detects that no live waiter exists, rolls the workspace back to the pre-node snapshot (ADR 0004), and re-runs the `HarnessNode` from the checkpoint with `humanAnswer` injected into `NodeExecutionContext`.

`HumanApprovalNode` pauses remain purely checkpoint-driven with nothing kept in memory (ADR 0007).

## Considered options

- **Always terminate the harness on `ask_human` and re-run on resume:** Keeps nothing in memory even during live sessions, but forfeits in-process agent continuity and contradicts the blocking `hive-mcp` tool contract.
- **In-memory only for `ask_human`:** Preserves the live session, but loses the pause or leaves the run unrecoverable across a backend restart.

## Consequences

- `ask_human` preserves in-process agent context during normal operation while remaining durable across backend restarts.
- Prompts and `HarnessNode` execution must handle receiving `humanAnswer` in `NodeExecutionContext` when resuming after a restart.
- This refines ADR 0007 specifically for live `ask_human` sessions; ADR 0007 remains in effect for `HumanApprovalNode` and post-restart recovery.
