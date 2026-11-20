# backend/AGENTS.md

Rules for the local Dart backend. The root `AGENTS.md` still applies; where this file conflicts with it, this file wins inside `backend/`.

Stack (ADR 0013): `shelf` + `shelf_router` + `shelf_web_socket`, `get_it` for dependency injection, `drift` over SQLite, `package:logging`, YAML configuration. Transport (ADR 0011): HTTP and WebSocket over a Unix domain socket only, no TCP port.

## Run

```
dart pub get                     # from the repository root (pub workspace)
dart run bin/server.dart         # from backend/; uses config/dev.yaml → backend/.dev-data/
curl --unix-socket .dev-data/backend.sock http://localhost/health
```

How to run, build and stop the backend (development and production) is in `README.md`. Production builds use `dart build cli`, never `dart compile exe` (the `sqlite3` build hook needs it).

Options: `--config <file>`, `--data-dir <folder>`, `--help`. The running backend writes `<data dir>/server.json` with its PID, version and socket path. Ctrl+C (and SIGTERM on Linux/macOS) shuts down cleanly.

## Layout

| Path | Contents |
|---|---|
| `bin/server.dart` | CLI entry point: arguments, config, start, wait for a shutdown signal |
| `lib/src/backend.dart` | `Backend.start` / `stop`: the composition entry used by `main` and by integration tests |
| `lib/src/di/dependencies.dart` | The only place that registers dependencies in `GetIt` |
| `lib/src/config/` | `AppConfig`, `ConfigLoader` (YAML), `PlatformPaths` (one implementation per OS) |
| `lib/src/logging/` | `LogEvent`, `Redactor`, `LogFormatter`, sinks (console, rotating JSONL file) |
| `lib/src/db/` | drift `AppDatabase` and repository interfaces with their drift implementations |
| `lib/src/http/` | Router (`api_handler.dart`), handlers, middlewares, JSON helpers |
| `lib/src/ws/` | `WsGateway` (upgrade and message handling) and `ConnectionRegistry` |
| `lib/src/server/` | `BackendServer`, `LocalSocket`, `ServerInfoFile` |
| `config/dev.yaml` | Development configuration (versioned; no secrets) |
| `tool/ws_probe.dart` | Development WebSocket client over the socket |
| `test/unit/`, `test/shelf/`, `test/integration/<area>/` | Tests, owned by the matching agents in `.agents/agents/` |

## Dependency injection

- Register every dependency in `registerDependencies` (`lib/src/di/dependencies.dart`), always under its interface type.
- Classes receive dependencies through constructors. Only `dependencies.dart` and `backend.dart` touch `GetIt`.
- Async resources (`AppDatabase`) use `registerSingletonAsync` with `dispose`; anything holding a resource registers a `dispose`. `GetIt.reset()` is the shutdown path.
- Tests use `GetIt.asNewInstance()` (or a pushed scope), never `GetIt.instance`.

## HTTP and WebSocket

- Every route answers JSON. Errors use the shared `ApiError` body and codes from `ApiErrorCode`; never return a stack trace.
- Middleware order is fixed in `buildApiHandler`: request id → request log → error handling → Origin rejection → routes.
- Any request with an `Origin` header is rejected (`403`). Do not add CORS.
- REST routes live under `/api/v1`. `GET /health` stays unauthenticated and content-free.
- WebSocket messages are `WsEnvelope`s defined in `shared/`. Add a message type to `WsMessageType` in `shared/` first, then handle it in `WsGateway`. Unknown types get an `error` reply; the connection stays open.

## Database

- Raise `schemaVersion` and add a migration step for every schema change. Never edit a shipped migration.
- Access goes through repository interfaces (`MetadataRepository`); handlers never touch `AppDatabase` directly.
- Generated files (`*.g.dart`) are committed. After changing tables, run `dart run build_runner build --delete-conflicting-outputs`.

## Logging

- Log `LogEvent`s through a named `Logger`. The level is fixed by the runtime mode: `FINE` with `dart run`, `INFO` in the compiled executable. It is never configurable.
- `fields` hold ids, counts, durations and statuses only. Prompts, agent output and file content go in `userContent`, which is written only below `INFO`.
- Secrets never reach a log at any level. `Redactor` hides sensitive field names, `Bearer` values and registered secrets; register every generated secret with `Redactor.addSecret`.
- Never log query strings or request bodies at `INFO`.

## Platforms

Windows and Linux are supported now; every change must also work on macOS. OS-specific behavior goes behind an abstraction with one implementation per OS (as `PlatformPaths` does). Use `package:path`, never hand-built separators.
