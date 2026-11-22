---
status: accepted
---

# Install the Hive MCP server into each harness CLI's user configuration

Harnesses without a per-run `--mcp-config` flag (such as `agy`, `codex`, and `gemini`) previously could only complete the result contract (ADR 0003) via the `result.json` fallback and could not call `report_result` or `ask_human` (ADR 0015). Installing `hive-mcp` once into each harness CLI's user-level MCP configuration gives every harness access to `report_result` and `ask_human` during runs.

## Decision

1. **User-level scope and server name.** Every harness installer registers the server under the name `hive` in the CLI's user-level configuration (never project-scoped or inside the user's workspace):
   - Claude Code: `claude mcp add -s user hive -- <cmd> [args...]` (`~/.claude.json`)
   - Codex: `codex mcp add hive -- <cmd> [args...]` plus `env_vars = ["HIVE_SOCKET_PATH", "HIVE_RUN_ID", "HIVE_NODE_ID", "HIVE_ATTEMPT"]` in `[mcp_servers.hive]` of `~/.codex/config.toml` (with backup and atomic write, because Codex strips MCP subprocess environments to a minimal OS allowlist)
   - Gemini CLI: `gemini mcp add -s user --trust hive <cmd> [args...]` (`~/.gemini/settings.json`)
   - Antigravity: `agy mcp add hive -- <cmd> [args...]` (`~/.gemini/antigravity-cli/mcp_config.json`)
2. **CLI-first, config-file fallback only where needed.** Installers use each CLI's `mcp add/get/list` subcommands. Direct config file editing is used only where the CLI lacks a flag (Codex `env_vars`) or where `mcp list` is slow/noisy.
3. **Outdated detection.** Detection compares the configured command and arguments against `HiveMcpLocator.resolve()` (and checks `env_vars` on Codex). Mismatches report `HarnessMcpStatus.outdated`; re-running install overwrites/updates the entry idempotently.
4. **Coexistence with per-run injection.** `ClaudeCodeNode` continues passing `--mcp-config` per run. Empirically, Claude Code overrides the user-scoped `hive` entry with the `--mcp-config` entry of the same name without starting a duplicate process.
5. **Graceful behavior outside a run.** When `HIVE_*` environment variables are absent, `hive-mcp` starts normally, exposes `report_result` and `ask_human`, and returns an `isError: true` tool result explaining that it is not running inside an Agentic Hive run.

## Considered options

- **Shared `~/.agents` MCP config:** none of the four CLIs reads MCP servers from `~/.agents`.
- **Distinct server name for global vs per-run injection:** unnecessary because Claude Code overrides same-named servers from `--mcp-config`, and keeping `hive` matches the result contract prompt instructions.
- **Exiting with code 64 when `HIVE_*` is missing:** breaks `claude mcp get` health checks and normal user CLI sessions.

## Consequences

- Every harness CLI can use `report_result` and `ask_human` once installed from the Harnesses page.
- Moving the checkout in development or upgrading to a compiled binary marks the entry `outdated` until updated.
