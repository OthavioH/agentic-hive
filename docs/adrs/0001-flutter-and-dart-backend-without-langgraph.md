---
status: accepted
---

# Flutter desktop + local Dart backend, with our own graph engine

The product is a Flutter desktop app that talks to a local Dart server (shelf) running in the background. We chose Dart over Python + LangGraph because nodes do not call LLMs directly (see ADR 0002). What we would use from LangGraph (shared state, conditional edges, cycles, checkpoints, interrupts) is small enough to write in Dart. In return we get a single language, types shared between frontend and backend (`shared/`), and a backend shipped as a single executable (`dart compile exe`), without packaging Python on Windows.

## Considered options

- **Python + LangGraph:** ready-made ecosystem, but it duplicates the models in two languages and complicates distribution on Windows.
- **Engine inside the Flutter app:** simpler, but runs would die when the app closes.

## Consequences

- LangGraph features that do not come for free (tracing, "time travel", parallel fan-out) must be built on top of the event log and `Future.wait`.
- At first, the backend runs as a background process started by the app, with a tray icon. A Windows service would run in another session and would not see the user's harness sign-ins.
