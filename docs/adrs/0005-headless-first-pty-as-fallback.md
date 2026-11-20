---
status: accepted
---

# Harnesses run headless; a PTY is the generic fallback

By default, each harness runs in its headless mode (`claude -p`, `codex exec`, `gemini -p`, `agy -p`), with JSON or stream-JSON output when the CLI offers it. This gives the UI structured events. For CLIs without a headless mode, `TerminalHarnessNode` runs the program in a pseudo-terminal (ConPTY), as Orca does. In that case completion is detected through the result contract (ADR 0003), and the user can watch and take over the terminal.

## Consequences

- The generic PTY is harder to test and to interpret. It comes after the first milestone.
- In every mode, the prompt goes through stdin or a file, never as an argument, because of the command-line length limit on Windows.
