---
status: accepted
---

# Headless harness permission policy

Headless CLI harnesses (`claude`, `codex exec`, `gemini`, `agy`) deny interactive tool calls by default when no permission policy is configured, blocking `mcp__hive__report_result`, `mcp__hive__ask_human`, workspace edits, and writing the fallback `result.json` outside the workspace.

## Owner decision

- **Always**, for every harness: allow the Hive MCP tools (`report_result`, `ask_human`) and grant access to the run's results directory (`dirname(resultJsonPath)`).
- **Worktree isolation** (`isolationMode == WorkspaceIsolationMode.worktree`): bypass all permission checks because the user's checkout is isolated.
- **Direct mode** (`isolationMode == WorkspaceIsolationMode.direct`): auto-approve file edits only; shell and other tools are allowed only when listed in the agent's `allowed_tools`.
- **Agent tool lists**: apply `allowed_tools` and `denied_tools` from agent frontmatter in both modes, with `denied_tools` taking precedence over `allowed_tools`.
- **User overrides**: `HarnessNodeConfig.extraArgs` are appended last so user flags can override any generated policy flag.

## Per-CLI mapping and gaps

Each `HeadlessHarnessNode` subclass implements `buildPermissionArgs` (ADR 0006, no `switch` over harness types):

| Harness | Worktree (bypass all) | Direct (edits only) | Allow tools | Deny tools | Results dir |
|---|---|---|---|---|---|
| `claude` (`ClaudeCodeNode`) | `--dangerously-skip-permissions` | `--permission-mode acceptEdits` | `--allowedTools mcp__hive__report_result,mcp__hive__ask_human,...` | `--disallowedTools ...` | `--add-dir <dir>` |
| `codex exec` (`CodexNode`) | `--dangerously-bypass-approvals-and-sandbox` | `--sandbox workspace-write` | Gap: no CLI flag | Gap: no CLI flag | `--add-dir <dir>` |
| `gemini` (`GeminiCliNode`) | `--approval-mode yolo` | `--approval-mode auto_edit` | `--allowed-mcp-server-names hive`, `--allowed-tools ...` | Gap: no CLI flag (requires `--policy` TOML file) | `--include-directories <dir>` |
| `agy` (`AntigravityNode`) | `--dangerously-skip-permissions` | `--mode accept-edits` | Gap: no CLI flag | Gap: no CLI flag | `--add-dir <dir>` |

## Consequences

- Unsupported per-tool `allowed_tools` / `denied_tools` flags are never silently ignored: each affected node logs a warning once per `(runId, typeId, gapKey)` via `HeadlessHarnessNode.logPolicyGapOnce`.
- When `gemini` receives both `allowed_tools` and `denied_tools`, denied tools are stripped from `--allowed-tools` so `denied_tools` still wins on overlapping entries.
- Prompts continue to be delivered strictly via `stdin` (ADR 0005), never as CLI arguments.
