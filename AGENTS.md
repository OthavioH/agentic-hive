# AGENTS.md

Rules for the whole product. `frontend/`, `backend/`, `shared/` and `design_system/` each have their own `AGENTS.md`. When a rule there conflicts with this one, the folder's rule wins inside that folder.

Before changing architecture, read the decisions in `docs/adrs/`. To change a decision, write a new ADR that supersedes the old one; do not edit the old one to say something else. Use the terms from `GLOSSARY.md` in code, UI and documents.

## Map

| Folder | What it is | May depend on |
|---|---|---|
| `frontend/` | Flutter desktop app: graph editor, run monitor, approvals | `shared/`, `design_system/` |
| `backend/` | Local Dart server (shelf): graph engine, nodes, harnesses, SQLite, MCP server (ADR 0015) | `shared/` |
| `shared/` | Pure Dart package: workflow schema, node types, events, DTOs | nothing in the project |
| `design_system/` | Flutter package: semantic tokens, themes, `Hive*` catalog, `HiveIcons`, motion, node visual contract (ADR 0018) | nothing in the project |
| `widgetbook/` | Flutter desktop app: visual catalog and token showcase for owner approval (ADR 0018) | `design_system/` |
| `tools/hive_lints/` | First-party `analysis_server_plugin` enforcing design-system and import rules (ADR 0018) | nothing in the project |
| `docs/adrs/` | Numbered architecture decisions (`0001-slug.md`) | — |
| `.agents/agents/` | Specialist agents for this project (one atomic role per file) | — |

`frontend/` and `backend/` never import each other. Everything both sides must agree on (workflow format, WebSocket events, node types) lives in `shared/`.

## Responsibilities

- The **backend** is the source of truth. Only it runs processes, touches workspaces and writes state. It outlives the app so runs continue when the window closes (ADR 0016).
- The **frontend** only draws, edits and sends commands (using `design_system/`, ADR 0018) and owns the system tray icon (ADR 0016). It never runs harnesses or reads SQLite directly.
- Both sides follow the layer-first, feature-second architecture with a sealed `Result` type (ADR 0017).

## Abstractions

Each family of behavior has an abstract base, and each variation is an implementation of it. Do not scatter `switch` statements over types.

- Nodes: `Node` → `HarnessNode` (abstract) → `ClaudeCodeNode`, `CodexNode`, `GeminiCliNode`, `AntigravityNode`, `TerminalHarnessNode`. The same applies to `ValidatorNode`.
- `HarnessNode` defines the common flow (prepare the workspace, build the prompt, run, collect the result through the contract). Subclasses implement only what varies: building the invocation and interpreting the CLI output.
- Adding a new harness means creating a subclass and registering it. It must not require changes to the engine.

## Invariants

- **Success comes from the result contract** (`report_result` through MCP or `result.json`). A non-zero exit code only signals an infrastructure failure; exit code zero without a report is a failure. See `docs/adrs/0003-result-contract.md`.
- **The product is generic.** Nothing in the engine may assume the workspace is code, that a user git repository exists, or that there are tests. Domain-specific validations are nodes, never engine rules.
- **Prompts go through stdin or a file**, never as a command-line argument.
- **Cancellation is only reported as done after confirming** that the process tree has exited.
- **The backend listens only on a Unix domain socket** in the user's data folder; file permissions are the authentication, and requests with an `Origin` header are rejected. No TCP port, token or session (ADR 0011).
- **Harness sign-in belongs to the user.** Detect authentication errors and show a clear message; never store harness credentials.

## Conventions

- **Always the latest stable version.** Before adding or updating a dependency (Dart, Flutter, packages), check the current version on pub.dev and the current documentation (Context7). Never write a version or an API from memory.
- **Multi-platform:** Windows and Linux now, macOS designed in (ADR 0012). OS-specific behavior lives behind an abstraction with one implementation per OS; never branch on the platform inline. Handle paths with `package:path`.
- **Zero tolerance on code quality** (ADR 0014): `very_good_analysis` with no disabled rules. Work is done only when `dart analyze --fatal-infos`, `dart format --output=none --set-exit-if-changed .` and `dart fix --dry-run` all report nothing.
- **Generated files:** Generated files (`**/*.g.dart`, `**/*.freezed.dart`, `frontend/lib/l10n/generated/`) are gitignored and never committed. **Before starting any work** in a fresh clone or worktree (before running `dart analyze`, `dart test`, or editing code), agents MUST run `dart run tool/codegen.dart` (which runs `flutter pub get`, `build_runner` in `shared/`, `backend/`, and `frontend/`, and `flutter gen-l10n` in `frontend/`).
- Code, identifiers, commit messages and all documentation (README, `AGENTS.md`, ADRs, glossary, agent definitions) are written in English.

## Agent skills

### Issue tracker

Issues live in the GitHub Issues of `OthavioH/agentic-hive`, through `gh`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single context: `GLOSSARY.md` at the root and ADRs in `docs/adrs/`. See `docs/agents/domain.md`.
