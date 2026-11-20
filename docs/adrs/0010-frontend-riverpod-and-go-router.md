---
status: accepted
---

# Frontend with Riverpod (state and dependency injection) and go_router

The Flutter app uses Riverpod for two things: state management and dependency injection. There is no other DI container (get_it, provider, etc.): services, backend clients and repositories are exposed as providers and replaced with `overrides` in tests. Providers use code generation (`riverpod_generator` + `riverpod_annotation`), the approach recommended by the Riverpod documentation, with `riverpod_lint` enabled. Navigation uses `go_router`, with typed routes through `go_router_builder`, and the `GoRouter` itself is created in a provider so that redirects react to Riverpod state (for example, backend disconnected).

## Versions on the decision date (2026-11-20)

| Package | Version |
|---|---|
| `flutter_riverpod` | 3.5.0 |
| `riverpod_annotation` | 4.0.8 |
| `riverpod_generator` | 4.0.10 |
| `riverpod_lint` | 3.2.0 |
| `go_router` | 18.1.4 |
| `go_router_builder` | 4.5.3 |
| `build_runner` | 2.17.1 |

This table records the starting point, not a ceiling. The project rule is to always use the latest stable version (see `AGENTS.md`).

## Consequences

- `build_runner` is part of the frontend development loop; generated files (`*.g.dart`) must be up to date before analyzing or testing.
- Notifiers are not mocked: logic that must be replaced in tests sits behind an abstraction (repository, client) exposed through a provider, as the Riverpod documentation recommends.
