---
status: accepted
---

# Orchestrate the user's harnesses instead of calling LLM APIs

Agent nodes run CLIs the user has already installed and signed in to (Claude Code, Codex, Gemini CLI, Antigravity CLI) instead of calling model APIs. This way the user keeps the subscription and configuration they already have, and Agentic Hive stores no keys or credentials. Sign-in, quota and configuration of each harness are the user's responsibility; the backend only detects authentication errors and shows them clearly.

## Consequences

- The product depends on CLI flags and output formats that change between versions. Adapters stay thin and isolated, one per harness (see ADR 0006).
- Rate limits and exhausted quota are a separate kind of failure, distinct from task failure.
