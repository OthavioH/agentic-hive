# Agentic Hive backend

The local server behind the Agentic Hive app. It serves a REST API and a WebSocket over a **Unix domain socket** in the user's data folder (no TCP port; see [ADR 0011](../docs/adrs/0011-unix-socket-transport.md)), keeps state in SQLite, and will run the workflow engine.

Rules for changing the code are in [`AGENTS.md`](AGENTS.md).

## Contents

- [Development](#development)
- [Production](#production)
- [Data folder, configuration and logs](#data-folder-configuration-and-logs)
- [Stopping the backend](#stopping-the-backend)
- [Troubleshooting](#troubleshooting)

## Development

### Requirements

- The latest stable Flutter/Dart SDK (Dart ^3.14). `dart --version` must report 3.14 or newer.
- Windows 10/11, Linux or macOS.

### Run

```sh
# once, from the repository root (pub workspace: installs backend and shared)
dart pub get

# from backend/
dart run bin/server.dart
```

In development the backend reads [`config/dev.yaml`](config/dev.yaml) and keeps everything in `backend/.dev-data/` (git-ignored), so it never touches your real user data. Logs are printed at `FINE` level.

| Option | Meaning |
|---|---|
| `--data-dir <folder>` | Use another data folder (overrides the config file) |
| `--config <file>` | Use another YAML configuration file |
| `-h`, `--help` | Print usage |

### Try it

The socket path is in `.dev-data/server.json`. `curl` speaks HTTP over a Unix socket on Windows 10+, Linux and macOS:

```sh
curl --unix-socket .dev-data/backend.sock http://localhost/health
curl --unix-socket .dev-data/backend.sock http://localhost/api/v1/status
```

For the WebSocket, use the bundled probe. It prints every frame, sends each line you type, and reports the close code:

```sh
dart run tool/ws_probe.dart
# <- {"type":"server.hello",...}
```

### Test and check

All four must be clean before a change is done (ADR 0014). Run them from the repository root:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart fix --dry-run                  # must print "Nothing to fix!"
cd backend && dart test             # and: cd shared && dart test
```

After changing database tables, regenerate drift code:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Production

### Build

`dart compile exe` does **not** work: the `sqlite3` package ships SQLite through a build hook. Use `dart build cli`, from `backend/`:

```sh
dart build cli
```

It produces a bundle for the current OS and CPU, for example `build/cli/windows_x64/bundle/`:

```
bundle/
├── bin/server(.exe)      # the backend
└── lib/sqlite3.(dll|so|dylib)
```

Ship the **whole bundle**: the executable loads SQLite from `../lib`. Build on each target OS (Windows, Linux, macOS); CI release builds will do this later.

The compiled executable runs in production mode: it logs at `INFO` and, unless `--data-dir` or `--config` say otherwise, uses the OS data folder below.

### How the backend gets started (planned)

> Not implemented yet. This is the intended behavior; the frontend and the installer do not exist yet.

**By the app (normal case).** The user never starts the backend by hand:

```text
app starts
  read <data folder>/server.json
  if it exists: GET /health over its socketPath
    answers  → use it
  otherwise / no answer:
    start the backend executable detached (it outlives the app)
    wait for server.json, then GET /health (with a timeout)
    connect REST + WebSocket
```

The backend keeps running when the app closes, so runs continue in the background. Starting a second backend is safe: it detects the live one on the socket and exits (code 70), so the app can always "start if not running".

**By the user, from a terminal.** The installer will put a command on the `PATH`, so the backend can be started from any terminal:

| OS | How the command is installed | Start |
|---|---|---|
| Windows | The install folder's `bin` is added to the user `PATH` | `agentic-hive-backend` |
| Linux | A symlink in `~/.local/bin` | `agentic-hive-backend` |
| macOS | A symlink in `/usr/local/bin` (or `~/.local/bin`) | `agentic-hive-backend` |

The command name is a proposal. Until the installer exists, run the bundle directly, for example `build/cli/linux_x64/bundle/bin/server`.

## Data folder, configuration and logs

| OS | Default data folder |
|---|---|
| Windows | `%LOCALAPPDATA%\AgenticHive\` |
| Linux | `$XDG_DATA_HOME/agentic-hive/`, or `~/.local/share/agentic-hive/` |
| macOS | `~/Library/Application Support/AgenticHive/` |

Inside it:

| File | Purpose |
|---|---|
| `backend.sock` | The Unix socket (only the owner can connect) |
| `server.json` | PID, version, socket path and start time of the running backend; removed on a clean stop |
| `hive.db` | SQLite database |
| `logs/backend-YYYY-MM-DD.jsonl` | One JSON object per line, one file per UTC day |
| `config.yaml` | Optional configuration (production) |

`config.yaml` is optional; every key has a default and unknown keys stop the backend with a clear error:

```yaml
paths:
  data_dir: /some/other/folder   # relative paths are relative to this file
websocket:
  ping_interval_seconds: 20      # 1–300
logs:
  retention_days: 14             # 1–365, today included
```

The log level is not configurable: `FINE` with `dart run`, `INFO` in the built executable. `INFO` never contains prompts, agent output or file content, and secrets are redacted at every level.

## Stopping the backend

Press **Ctrl+C** in its terminal (or send `SIGTERM` on Linux and macOS). The backend then closes every WebSocket with code `4001` ("Server shutting down"), stops the server, closes the database, flushes the logs, and deletes `backend.sock` and `server.json`.

On Windows, press Ctrl+C in PowerShell, Command Prompt or Windows Terminal. Git Bash (mintty) may kill the process instead of delivering Ctrl+C, which skips the cleanup.

| Exit code | Meaning |
|---|---|
| `0` | Stopped cleanly |
| `64` | Invalid arguments or configuration |
| `70` | Could not start: another backend is running, or the socket path is too long |

## Troubleshooting

| Message | Cause and fix |
|---|---|
| `Another Agentic Hive backend is already running on …` | A live backend owns that data folder. Use it, or stop it first. |
| `The socket path is longer than N bytes …` | The data folder path is too long for a Unix socket (103 bytes on macOS, 107 elsewhere). Use a shorter `--data-dir`. |
| `Invalid configuration: …` | Fix the key named in the message. |
| A `backend.sock` file exists but nothing answers | Left by a killed process. The next start removes it automatically. |
