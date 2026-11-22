# Harness MCP Installation Research

Research conducted on Windows against the real CLI binaries installed on the development machine to answer the six open questions in issue #52.

## Backups Created Before Probing

All user-level CLI configuration files were backed up prior to running any probe commands:

- `claude.json.bak` (`~/.claude.json`)
- `claude-settings.json.bak` (`~/.claude/settings.json`)
- `codex-config.toml.bak` (`~/.codex/config.toml`)
- `gemini-settings.json.bak` (`~/.gemini/settings.json`)
- `antigravity-cli-mcp_config.json.bak` (`~/.gemini/antigravity-cli/mcp_config.json`)
- `antigravity-mcp_config.json.bak` (`~/.gemini/antigravity/mcp_config.json`)

Backups stored outside the repository at `C:\Users\Ots\.gemini\antigravity-cli\brain\9e4a32f2-23bf-474f-8f4c-4778046e7960\scratch\cli-backups\`.

All probe entries (`hive-probe`) were removed with each CLI's own `mcp remove` command after testing.

---

## 1. Environment Variable Propagation (`HIVE_*`)

A throwaway stdio MCP server (`probe_mcp.mjs`) was registered under `hive-probe` in each CLI and triggered with `HIVE_SOCKET_PATH`, `HIVE_RUN_ID`, `HIVE_NODE_ID`, and `HIVE_ATTEMPT` set in the parent process environment.

### Claude Code (`claude`)

- **Add:** `claude mcp add -s user hive-probe -- node <probe_mcp.mjs> <out>`
- **Inspect:** `claude mcp get hive-probe` (exit `0` when present, `1` when absent; performs a live stdio health check)
- **Remove:** `claude mcp remove -s user hive-probe`
- **Observed env in `probe_mcp.mjs`:**
  ```json
  "hiveEnv": {
    "HIVE_ATTEMPT": "1",
    "HIVE_NODE_ID": "probe-node",
    "HIVE_RUN_ID": "probe-run",
    "HIVE_SOCKET_PATH": "probe-sock-claude"
  }
  ```
- **Conclusion:** Claude Code passes the full parent process environment to stdio MCP servers by default.
- **Exact install command:**
  `claude mcp add -s user hive -- <executable> [baseArgs...]`

### OpenAI Codex (`codex`)

- **Add:** `codex mcp add hive-probe -- node <probe_mcp.mjs> <out>`
- **Inspect:** `codex mcp get hive-probe --json` (exit `0` when present, `1` when absent; reads `~/.codex/config.toml` without spawning the server)
- **Remove:** `codex mcp remove hive-probe`
- **Observed env without `env_vars` (`codex exec --json --skip-git-repo-check -`):**
  ```json
  "hiveEnv": {},
  "envKeys": ["APPDATA","COMSPEC","HOMEDRIVE","HOMEPATH","LOCALAPPDATA","PATH","PATHEXT","PROGRAMDATA","PROGRAMFILES","PROGRAMFILES(X86)","PROGRAMW6432","SYSTEMDRIVE","SYSTEMROOT","TEMP","TMP","USERDOMAIN","USERNAME","USERPROFILE","WINDIR"]
  ```
- **Observed env with `mcp_servers.hive-probe.env_vars=["HIVE_SOCKET_PATH","HIVE_RUN_ID","HIVE_NODE_ID","HIVE_ATTEMPT"]`:**
  ```json
  "hiveEnv": {
    "HIVE_ATTEMPT": "1",
    "HIVE_NODE_ID": "probe-node",
    "HIVE_RUN_ID": "probe-run",
    "HIVE_SOCKET_PATH": "probe-sock-codex"
  }
  ```
- **Conclusion:** Codex strips the environment of stdio MCP servers to a minimal OS allowlist. `HIVE_*` variables are only forwarded if explicitly listed in `env_vars` under `[mcp_servers.hive]` in `~/.codex/config.toml`. Because `codex mcp add` does not expose an `--env-vars` flag, installation must run `codex mcp add hive -- <executable> [baseArgs...]` and then ensure `env_vars = ["HIVE_SOCKET_PATH", "HIVE_RUN_ID", "HIVE_NODE_ID", "HIVE_ATTEMPT"]` is present in `[mcp_servers.hive]` inside `~/.codex/config.toml` (with backup and atomic write).

### Gemini CLI (`gemini`)

- **Add:** `gemini mcp add -s user --trust hive-probe node <probe_mcp.mjs> <out>`
- **Inspect:** `gemini mcp list` (also prints validation warnings to stderr if another entry in `settings.json` has invalid fields, while still exiting `0` and listing configured servers)
- **Remove:** `gemini mcp remove -s user hive-probe`
- **Observed env (`GEMINI_CLI_TRUST_WORKSPACE=true gemini -p "Reply with just OK."`):**
  ```json
  "hiveEnv": {
    "HIVE_ATTEMPT": "1",
    "HIVE_NODE_ID": "probe-node",
    "HIVE_RUN_ID": "probe-run",
    "HIVE_SOCKET_PATH": "probe-sock-gemini"
  }
  ```
- **Conclusion:** Gemini CLI passes the full parent process environment to stdio MCP servers by default. `--trust` is included so tool calls do not prompt for confirmation in headless runs.
- **Exact install command:**
  `gemini mcp add -s user --trust hive <executable> [baseArgs...]` (note: Gemini CLI's yargs parser treats `--` as end-of-positionals, so `commandOrUrl` must precede any `--`.)

### Antigravity (`agy`)

- **Add:** `agy mcp add hive-probe node <probe_mcp.mjs> <out>` (flags must come before `<name>`; `--` before command/args starting with `-`)
- **Inspect:** `agy mcp list`
- **Remove:** `agy mcp remove hive-probe`
- **Observed env (`agy --input-format stream-json --output-format stream-json`):**
  ```json
  "hiveEnv": {
    "HIVE_ATTEMPT": "1",
    "HIVE_NODE_ID": "probe-node",
    "HIVE_RUN_ID": "probe-run",
    "HIVE_SOCKET_PATH": "probe-sock-agy"
  }
  ```
- **Conclusion:** Antigravity passes the full parent process environment to stdio MCP servers by default.
- **Exact install command:**
  `agy mcp add hive -- <executable> [baseArgs...]`

---

## 2. Behavior Outside a Run

Previously, `backend/bin/hive_mcp.dart` exited with code `64` (`_usageError`) whenever `HIVE_SOCKET_PATH`, `HIVE_RUN_ID`, `HIVE_NODE_ID`, or `HIVE_ATTEMPT` was missing. When `hive` is installed in a CLI's user config, the CLI spawns `hive-mcp` during `claude mcp get`, `claude mcp list`, and normal interactive sessions outside Agentic Hive. Exiting with code `64` causes health checks to fail and breaks the user's session.

**Decision:** When any of the four `HIVE_*` context values is absent outside a run, `hive-mcp` starts normally as a stdio MCP server, registers `report_result` and `ask_human`, and answers any tool call with an MCP tool error (`isError: true`) stating that the server is not running inside an Agentic Hive run. Explicit CLI syntax errors (unknown flags, missing option values, or a non-positive `--attempt` value) still exit with code `64`.

---

## 3. Duplicate with Per-Run Injection (`claude --mcp-config`)

`ClaudeCodeNode` passes `--mcp-config <temp-file>` defining the `hive` server with per-run arguments and `env`.

We registered `hive-probe` in Claude Code's user config (`~/.claude.json`) pointing to `outUser`, and passed `--mcp-config` defining `hive-probe` pointing to `outRun` with `PROBE_TEST=from_mcp_config`:

- `outUser`: **not created** (`NO_USER_OUT`)
- `outRun`: created with `"hiveEnv": {"PROBE_TEST": "from_mcp_config"}`

**Conclusion:** Claude Code does not start two servers with the same name; `--mcp-config` overrides the user-scoped entry of the same name. Keeping `--mcp-config` on `ClaudeCodeNode` is safe and ensures per-run context even if the user's global entry is outdated or absent.

---

## 4. Scope and Config File Locations

All installers target user-level scope only (never project scope or the user's workspace):

| Harness | CLI Scope Flag | Config File Path |
|---|---|---|
| Claude Code | `-s user` | `~/.claude.json` |
| Codex | default (user/global) | `~/.codex/config.toml` |
| Gemini CLI | `-s user` | `~/.gemini/settings.json` |
| Antigravity | default (user-only; no scope flag) | `~/.gemini/antigravity-cli/mcp_config.json` |

---

## 5. Launch Command Stability & Outdated Detection

`HiveMcpLocator.resolve()` produces `HiveMcpLaunchCommand(executable, baseArguments)`:
- Development: `dart` + `['run', '<repo>/backend/bin/hive_mcp.dart']`
- Compiled build: `<dir>/hive-mcp` (or `hive-mcp.exe` on Windows) + `[]`

An installed `hive` entry is:
- **`installed`**: `hive` is present and its configured `command` and `args` match `HiveMcpLocator.resolve()` (and for Codex, `env_vars` contains all 4 `HIVE_*` keys).
- **`outdated`**: `hive` is present, but its `command` or `args` differ from `HiveMcpLocator.resolve()` (or for Codex, `env_vars` is missing any `HIVE_*` key).
- **`notInstalled`**: `hive` is not present.
- **`unsupported`**: the harness CLI itself is not installed.
- **`unknown`**: detection timed out, failed to execute, or produced unparsable output.

---

## 6. `~/.agents`

`~/.agents/` on this machine contains `agents/`, `rules/`, `skills/`, `workflows/`, and `.skill-lock.json`. None of the four CLIs (`claude`, `codex`, `gemini`, `agy`) reads MCP server configurations from `~/.agents`. We do not use `~/.agents`.
