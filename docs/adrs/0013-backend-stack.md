---
status: accepted
---

# Backend stack: shelf, get_it, drift and YAML configuration

The backend is built on `shelf` (with `shelf_router` and `shelf_web_socket`), uses `get_it` as its dependency injection container, `drift` over SQLite for persistence, `package:logging` for logs, and an optional YAML file for configuration. Dependencies are registered explicitly in one module, always under their interface type; there is no code-generated injection (`injectable`) until the number of registrations makes it worth it. The YAML file is optional (defaults live in code), lives at `<data dir>/config.yaml` in production and `backend/config/dev.yaml` in development, and holds no secrets. There is no `.env` file. The log level is not configurable: `FINE` when running from source, `INFO` in the compiled executable.

## Considered options

- **Vaden** (annotation-based framework on top of shelf, with its own DI): rejected. Its code generator (`vaden_class_scanner` 1.0.2) requires `build` ^4 and `analyzer` < 9, which cannot resolve together with current `build_runner`, `drift_dev` and `riverpod_generator`; in the shared pub workspace it would pin the frontend's generators too. It was also a year without a release at decision time (2026-11-20).
- **Other containers:** `riverpod` in the backend (one model across the stack, unusual on a server), `auto_injector` (constructor auto-wiring, small adoption), `kiwi` (unmaintained). `get_it` won on maturity.
- **Raw `sqlite3`:** fewer dependencies, but hand-written SQL and our own migration runner; `drift` gives typed queries and tested migrations.
- **TOML or JSON configuration:** TOML's Dart package is pre-1.0; JSON allows no comments.
