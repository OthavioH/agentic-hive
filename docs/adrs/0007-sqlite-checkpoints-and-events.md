---
status: accepted
---

# State in SQLite: a checkpoint per node and an event log

The backend writes a checkpoint of the graph state to SQLite at the end of each node, and every run event to an append-only log. A paused run (human approval, `ask_human`) keeps nothing in memory: it resumes from the checkpoint. The event log feeds the history in the UI and replaces the tracing LangGraph would provide. Postgres (used by LangConfig) was ruled out because it needs a separate server in a desktop app.

## Consequences

- Checkpoints are per node. A node interrupted midway (crash, shutdown) is redone from the start, from the workspace snapshot (ADR 0004).
- Retries happen on the same task, with a per-edge limit (`maxRetries`) and a global circuit breaker for repeated infrastructure failures, as in Orca.
