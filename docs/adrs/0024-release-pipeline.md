---
status: accepted
---

# Release pipeline and Bundle layout

Amends ADR 0023 (custom title bar): the app's identifier is `dev.othavioh.agentic-hive` on Linux and macOS, because Apple bundle identifiers do not allow `_`, and the macOS product name is `agentic_hive` (bundle `agentic_hive.app`), so the executable is named `agentic_hive` on every OS and the launcher and Bundle tooling can rely on one name. Users still see "Agentic Hive" everywhere: the macOS `Info.plist` sets `CFBundleDisplayName` to it.

The product had no way to be published. Pushing a tag `vX.Y.Z` on `master` now runs `.github/workflows/release.yml`, which builds a **Bundle** on Windows and Linux, smoke-tests it and publishes a GitHub pre-release. macOS is still only built in CI (ADR 0012). Spec: issue #92.

## Decision

- **Bundle layout.** The Flutter release output with the `dart build cli` output of both backend executables merged into a `backend/` folder next to the app executable: `backend/bin/server`, `backend/bin/hive_mcp` and `backend/lib/`. `lib/` holds the SQLite library and, on Linux, each executable's compiled program (`libdartaotserver.so`, `libdartaothive_mcp.so`): there `bin/<name>` is a small runtime that loads `../lib/libdartaot<name>.so` by its own name, so the executables must keep their names. On Windows the executables are self-contained. The release launcher starts `backend/bin/server` relative to the app executable (ADR 0016); `hive_mcp` sits next to it so harnesses find the MCP proxy (ADR 0015).
- **`dart build cli`, never `dart compile exe`.** The `sqlite3` package ships SQLite through a build hook, which only `dart build cli` runs. It builds one entry point per run and wipes its output folder, so `tool/build_backend_bundle.dart` builds `server` and `hive_mcp` in two runs and merges them. A library both builds produce must be byte-identical; otherwise the tool fails.
- **One product version.** `frontend`, `backend` and `shared` share one version; `frontend/pubspec.yaml` is the source of truth. Tags are `vX.Y.Z`; the workflow fails when the tag differs from that version, when the packages disagree, or when the tagged commit is not on `master`.
- **Flow.** PR `development` → `master` with green CI, then the owner pushes the tag on `master`. `workflow_dispatch` is a dry run: it builds and uploads the archives but never publishes.
- **Gate.** Each OS job runs `tool/smoke_bundle.dart` on the assembled Bundle (files present, backend starts with a temporary data folder, `GET /health` answers over the Unix socket, `hive_mcp` answers an MCP `initialize` request over stdio). The publish job needs both OS jobs, so no release ships for one OS only.
- **Artifacts.** `agentic-hive-<version>-windows-x64.zip`, `agentic-hive-<version>-linux-x64.tar.gz` and `SHA256SUMS`, each archive with the single root folder `agentic-hive-<version>/`. The Windows archive also carries the Visual C++ runtime DLLs next to the executable, as Flutter's Windows distribution guide requires. Releases are always marked pre-release until builds are code-signed; notes are generated from merged PRs and state that the build is unsigned.

## Alternatives considered

- **Backend binary as a sibling of the app executable (`agentic_hive_backend`).** Rejected: the backend executables load SQLite (and, on Linux, their compiled program) from `../lib` and need `hive_mcp` beside it, so the `dart build cli` bundle must stay intact.
- **One combined `dart build cli` run.** Not possible: the command takes a single entry point and replaces its output folder.

## Consequences

- Pending, not part of v0.1.0: code signing and notarization (dropping the pre-release mark waits for it), an installer (and the PATH command described in `backend/README.md`), auto-update, macOS release artifacts and a hand-written changelog.
- Windows SmartScreen warns on first launch until builds are signed.
- Renaming the executable, the `backend/` folder or the archive names is a breaking change for users and for the launcher; change them only with a new ADR.
