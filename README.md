# Agentic Hive

A visual orchestrator for AI agents on the desktop. You build a workflow as a graph, and each node runs on the agent harnesses you already have installed and signed in: Claude Code, Codex, Gemini CLI, Antigravity CLI. A workflow can keep running on its own in the background.

> **Status:** planning. There is no code yet. Architecture decisions live in [`docs/adrs/`](docs/adrs/).

## Why it exists

Frameworks such as LangGraph solve agent orchestration, but they require writing and running code for each task, and they call model APIs directly (with their own keys and billing). Agentic Hive reuses what the user already pays for and configures: their own agent CLIs. The app only lays the track between them.

The product is not limited to software development. A workflow can research, write, review documents or process files. Any task that a terminal agent can do in a folder fits.

## How it works

```
┌──────────────────────┐   HTTP + WebSocket    ┌──────────────────────────────┐
│  Frontend (Flutter)  │ ◄──────────────────►  │  Backend (Dart + shelf)      │
│  graph editor,       │      local only       │  graph engine, checkpoints   │
│  monitor, approvals  │                       │  (SQLite), MCP server        │
└──────────────────────┘                       └──────────────┬───────────────┘
                                                              │ Process / PTY
                                          ┌───────────────────┼───────────────────┐
                                          ▼                   ▼                   ▼
                                     claude -p           codex exec            agy -p   ...
                                          └────────── run workspace ──────────────┘
```

1. **Agents** are `.md` files (frontmatter + prompt) in the user's agents folder.
2. **Workflows** are graphs: nodes linked by `onSuccess` / `onFailure` edges, which can form cycles with a retry limit.
3. Each **run** gets its own **workspace**. Before each node, the backend snapshots the folder so it can roll back.
4. Each agent reports its result through the **result contract**: it calls the backend's `report_result` MCP tool or writes a `result.json`. The exit code only detects infrastructure failures.
5. Validator nodes decide the route: a command, an LLM judge answering in JSON, a file check, or human approval.
6. Human nodes and the `ask_human` tool pause the run. The state is saved in SQLite, and the run resumes when you answer in the app.

## Node types

The code follows a hierarchy of abstractions. Each harness is a subclass of `HarnessNode`:

```
Node
├── HarnessNode (abstract)
│   ├── ClaudeCodeNode       claude -p --output-format stream-json
│   ├── CodexNode            codex exec
│   ├── GeminiCliNode        gemini -p
│   ├── AntigravityNode      agy -p --output-format stream-json
│   └── TerminalHarnessNode  any CLI, through a pseudo-terminal (PTY)
├── CommandNode              runs a command or script
├── ValidatorNode (abstract)
│   ├── CommandValidatorNode
│   ├── LlmJudgeNode
│   └── FileCheckNode
└── HumanApprovalNode
```

The exact flags of each CLI must be confirmed when each adapter is implemented. They change between versions.

## Repository layout

| Folder | Contents |
|---|---|
| `frontend/` | Flutter desktop app, with Riverpod (state and DI) and go_router |
| `backend/` | Local Dart server (shelf): engine, harnesses, persistence |
| `shared/` | Dart package with the workflow schema, events and models used by both sides |
| `docs/adrs/` | Architecture decision records |

## Requirements (planned)

- Windows 10/11
- At least one harness installed and signed in by the user (Agentic Hive does not manage sign-in)
- Git, used internally for workspace snapshots

## First milestone

A backend-only spike, without UI, that proves the highest-risk points on Windows:

- [ ] Read a workflow from JSON and run coder → validator → reviewer, looping back to the coder on rejection
- [ ] Headless `ClaudeCodeNode`, with the prompt sent through stdin
- [ ] Result contract through MCP and `result.json`
- [ ] SQLite checkpoint and workspace snapshot per node
- [ ] Pause on a `HumanApprovalNode` and resume over HTTP
- [ ] Cancellation that terminates the whole process tree

## Documentation

- [`AGENTS.md`](AGENTS.md): general rules for anyone (human or agent) working on the code
- [`GLOSSARY.md`](GLOSSARY.md): domain vocabulary
- [`docs/adrs/`](docs/adrs/): architecture decisions and their reasons
