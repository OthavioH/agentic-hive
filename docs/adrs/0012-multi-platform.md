---
status: accepted
---

# Windows and Linux now, macOS designed in

Supersedes ADR 0009 and amends ADR 0005.

The product targets Windows and Linux now; every design decision must also hold on macOS, whose signing and distribution come later. Code never branches on the platform inline: each OS-specific behavior sits behind an abstraction with one implementation per operating system, chosen once at startup.

- **Paths** (`PlatformPaths`): data folder in `%LOCALAPPDATA%\AgenticHive\` (Windows), `$XDG_DATA_HOME/agentic-hive/` or `~/.local/share/agentic-hive/` (Linux), `~/Library/Application Support/AgenticHive/` (macOS).
- **Cancellation** (`ProcessTreeKiller`, replacing ADR 0009): Job Objects on Windows, process groups on Linux and macOS. The rule from ADR 0009 stays: a run is reported cancelled only after the whole tree is confirmed gone.
- **Generic terminal harness** (amending ADR 0005): ConPTY on Windows, `openpty` on Linux and macOS, behind one PTY abstraction.

## Consequences

- CI runs analysis and tests on Windows, Ubuntu and macOS, so macOS breakage shows up without owning a Mac.
- Prompts still go through stdin or a file on every platform (ADR 0005), not only because of the Windows command-line limit.
