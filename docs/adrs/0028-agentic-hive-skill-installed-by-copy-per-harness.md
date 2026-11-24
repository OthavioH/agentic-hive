---
status: accepted
---

# The Agentic Hive skill is installed by copy into each harness, tracked by a sidecar file

Agents that use the `hive` MCP tools (ADR 0026) work better with a skill that teaches the workflow of use. The app ships one skill, `agentic-hive`, and installs it on first run for every harness it detects, then only warns when it becomes outdated and never updates it by itself. The backend writes real copies, not symlinks, in the places the harnesses read: `~/.agents/skills` (Codex and Gemini CLI), `~/.claude/skills` (Claude Code) and `~/.gemini/config/skills` (Antigravity CLI). Next to each `SKILL.md` it writes `hive-skill.json` with the app version and a content hash, and compares it with the one in the Bundle to report `installed`, `not_installed`, `outdated`, `modified` or `conflict`.

## Considered options

- **Version stamp in the `SKILL.md` frontmatter:** an extra `metadata` block is not verified for Gemini CLI and Antigravity CLI, and a skill that a harness rejects is silently skipped.
- **Use each harness CLI to install (`gemini skills install`):** only Gemini CLI has such a command, and probing harness CLIs is slow (ADR 0020).
- **Symlinks into one shared folder:** need extra privileges on Windows and Claude Code and Antigravity CLI do not read `~/.agents/skills` anyway.

## Consequences

- The installer is one implementation per harness behind an abstract base (ADR 0006 style), like the MCP installers, and runs in the backend.
- A folder without our `hive-skill.json` is never overwritten or removed (`conflict`); a file the user edited reports `modified` and is overwritten only after confirmation.
- Automatic installation happens once per harness, the first time it is detected; if the user removes the skill, it is not installed again by itself.
- A test checks that every workflow tool named in the skill exists in the MCP registry and the other way around.
