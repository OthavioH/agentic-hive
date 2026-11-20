# frontend/AGENTS.md

Rules for the Flutter desktop app. The root `AGENTS.md` still applies; where this file conflicts with it, this file wins inside `frontend/`.

Stack decisions: Riverpod with code generation for state and dependency injection, and `go_router` with typed routes (see `docs/adrs/0010-frontend-riverpod-and-go-router.md`, `0017-layered-architecture-and-result.md`, `0018-design-system-widgetbook-and-lints.md`).

## Directory Layout (Layer-First, Feature-Second)

```text
lib/
  app.dart                    # Root HiveApp widget (theme, localization, router)
  main.dart                   # ProviderScope bootstrap
  core/
    backend/                  # PlatformPaths, BackendClient, UnixSocketBackendClient, connection state
    di/                       # Use case providers
    result/                   # Sealed Result<T> and Failure hierarchy
  l10n/
    app_en.arb                # English ARB source (only locale for now)
    generated/                # Output of flutter gen-l10n (excluded from lints)
  routes/                     # Typed go_router routes and router provider
  domain/<feature>/           # Pure Dart: entities (only when shared/ lacks them), repository interfaces, one-call() use cases
  data/<feature>/             # Data sources, transport-only DTOs, repository implementations + providers
  presentation/<feature>/     # pages/, controllers/, widgets/
```

## Dependency Direction & Layer Rules

- **Strict direction:** `presentation -> domain <- data`.
- `presentation/` **never** imports `data/`.
- `domain/` is **pure Dart**: no Flutter, no Riverpod, no `data/` imports. Reuse `agentic_hive_shared` types directly instead of duplicating entities.
- Every UI action goes through a domain **use case** (a class with a single `call(...)` method). Controllers never call repositories directly, even when a use case only delegates to a repository.

## Error Handling (`Result` and `Failure`)

- Fallible domain and data operations return `Future<Result<T>>` or `Result<T>` (`Success<T>` / `FailureResult<T>`), never throw for expected failures. Exceptions are reserved for programmer bugs.
- `Failure` subtypes live in `lib/core/result/failure.dart` (`NetworkFailure`, `BackendFailure`, `NotFoundFailure`, `ValidationFailure`, `UnexpectedFailure`).
- Presentation controllers map `Failure` values into UI state (`AsyncValue` or explicit view state).

## Riverpod DI & State Management

- Use `@riverpod` / `@Riverpod(keepAlive: true)` with `riverpod_generator` and `riverpod_lint`. Keep generated `*.g.dart` files committed and up to date (`dart run build_runner build --delete-conflicting-outputs`).
- **DI providers:** Expose abstract interface types, never concrete implementations. Register data source and repository providers next to their implementations in `data/<feature>/`, use case providers in `core/di/`, and app-wide transport in `core/backend/`. Use `ref.onDispose` to close clients and cancel subscriptions.
- **No global singletons or mutable static state.** Everything goes through Riverpod so tests can swap dependencies with `overrides`.
- **Notifiers:** Use `ref.watch` for reactive dependencies in `build`, and `ref.read` only inside callbacks and action methods. Always check `if (!ref.mounted) return;` after an `await` before updating state.

## Routing (`go_router`)

- Define routes with `go_router_builder` (`@TypedGoRoute`, `@TypedShellRoute`) in `lib/routes/`.
- Create `GoRouter` inside a Riverpod provider so redirects react to app state (for example, redirecting to `/connecting` when `backendConnectionProvider` is not connected and returning to the remembered route on reconnect).

## Localization (`gen-l10n`)

- Localization files live at `frontend/lib/l10n/` (matching Flutter's default `l10n.yaml` convention) rather than `core/l10n/`.
- Every user-visible string must live in `lib/l10n/app_en.arb` and be read via `AppLocalizations.of(context)!`. Never hardcode user-visible copy in widgets or controllers.
- Localizations: take `GlobalMaterialLocalizations` from `package:material_ui/material_ui.dart` and `GlobalCupertinoLocalizations` from `package:cupertino_ui/cupertino_ui.dart`, not from `flutter_localizations` (which only provides `GlobalWidgetsLocalizations`).

## Material and Cupertino are packages, not part of the SDK

Material and Cupertino were moved out of the Flutter framework into standalone packages published by flutter.dev: `material_ui` and `cupertino_ui`. This project starts on them directly.

- Import `package:material_ui/material_ui.dart` and `package:cupertino_ui/cupertino_ui.dart`.
- Never import `package:flutter/material.dart` or `package:flutter/cupertino.dart`.
- If a third-party package still imports `package:flutter/material.dart`, wrap the app (through `MaterialApp.builder`) or the affected subtree in `MaterialUiCompatibilityBridge`. Prefer a maintained alternative package first.
- Code copied from older examples or tutorials uses the old imports. Migrate it with:

  ```
  dart fix --apply --code=migrate_design_widgets
  ```

  This rewrites `package:flutter/material.dart` imports to `package:material_ui/material_ui.dart` and adds the dependency.

Versions on 2026-11-20: `material_ui` 1.11.1 and `cupertino_ui` 1.1.7, both requiring Flutter >= 3.47.0. Check pub.dev for the current version before adding them (root `AGENTS.md`, latest stable versions rule).

## Design System, `hive_lints` & Catalog Requests

- **Consume `design_system/`, never invent locally.** Build screens exclusively from `Hive*` catalog components, `HiveIcons`, `HiveMotion`, and semantic tokens (`HiveColors`, `HiveSpacing`, `HiveRadii`, `HiveTypography`, `HiveElevation`, `HiveMotionTokens`) read from `Theme.of(context).extension<...>()` or design-system context accessors.
- **No local tokens or raw widgets.** Never use literal colors, spacing, radii, font sizes, or durations, and never import `hugeicons` directly.
- **`hive_lints` and zero tolerance:** `hive_lints` and `riverpod_lint` are enabled in `frontend/analysis_options.yaml`. Work is done only when `dart analyze --fatal-infos`, `dart format --output=none --set-exit-if-changed .`, and `dart fix --dry-run` all report zero issues.
- **Catalog & token requests:** Feature agents never define new tokens or `Hive*` widgets inside `frontend/`. When a feature needs a missing token or catalog component, add it to the **Catalog requests** section of the feature spec or file an issue for `design-system-builder`.

## Testing Rules

- **Never mock Riverpod notifiers.** Replace dependencies (clients, repositories, services) via `ProviderScope(overrides: [...])` or `ProviderContainer.test(overrides: [...])`.
- Keep unit tests in `test/core/`, `test/domain/`, `test/data/`, and widget/router tests in `test/presentation/` and `test/routes/`.
