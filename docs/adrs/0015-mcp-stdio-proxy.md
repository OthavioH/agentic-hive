---
status: accepted
---

# Harnesses reach the MCP server through a stdio proxy

Harnesses connect to MCP servers either over stdio or through an HTTP URL on a TCP port, but the backend listens only on a Unix domain socket (ADR 0011). So the result contract tools (`report_result`, `ask_human`, ADR 0003) are served by a small proxy executable, `hive-mcp`, that the harness starts as a stdio MCP server. The proxy forwards each call to the backend over the socket and identifies the run and node it belongs to from what the backend passed when it configured the harness. The proxy lives in `backend/` and ships alongside the backend executable.

## Considered options

- **A TCP port only for MCP:** reopens what ADR 0011 closed and would need a per-run token to stay safe.
- **`result.json` only, no MCP:** works for every harness but loses an interactive `ask_human`.

## Consequences

- The proxy is a second executable to build, ship and keep version-compatible with the backend.
- The proxy holds no state; if the backend is unreachable, the tool call fails and the node fails through the result contract.
