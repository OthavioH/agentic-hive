---
name: riverpod-di
description: Implements frontend dependency injection with Riverpod (providers for services, backend HTTP/WebSocket clients, repositories, configuration, resource lifecycle and disposal, override points for tests). Select to register or swap a dependency. Not for screen state, routes, widgets or tests.
required_skills: [flutter-validation]
required_tools: [context7]
---

# Riverpod DI

## Responsibilities
- Is the app's composition root: providers (generated with `@riverpod`) that build and expose services, repositories, the backend REST and WebSocket clients, and the connection configuration defined by the current security ADR.
- Defines abstract interfaces for each replaceable dependency and provides the concrete implementation through the provider, following the abstractions rule in `AGENTS.md`.
- Owns the lifecycle: `keepAlive` for app-wide resources (the WebSocket connection), `ref.onDispose` to close clients and cancel subscriptions.
- Makes sure everything a test needs to swap can be replaced with `overrides`.
- Does not implement screen state, routes or widgets.

## Required inputs
- Which dependency to register, its interface, the concrete implementation and who consumes it.
- Blocked if the interface is undefined or the dependency needs a `shared/` contract that does not exist.

## Reasoning loop
1. **Pre-plan (Pre-Act).** Check the current version of the Riverpod packages (pub.dev) and of any client you will use (for example, `http`, `web_socket_channel`), and the API in the docs (Context7). List the steps with goal, action, expected observation and completion criterion.
2. **ReAct loop.** Per step: justify the action, act once and record what you saw (generated code, a lint warning, a cycle detected in the provider graph).
3. **Revision.** A cycle between providers, a resource without disposal, or a different API in the docs changes the plan; say what changed.
4. **Stop.** Done when each dependency has an interface, a provider and disposal, can be overridden in tests, the generated code is up to date, and `dart analyze` and `riverpod_lint` report zero diagnostics. Escalate if the dependency needs a package that has not been approved.
5. **Report.** Final plan, revisions and reason, evidence per step, versions checked.

## Execution guidance
- The provider returns the interface type, not the implementation.
- No global singletons, no `static` with state: everything goes through Riverpod.
- Connection secrets, if any exist under the security ADR, never appear in logs or error messages.

## Ownership and collaboration
- Edits `frontend/lib/src/core/di/` and the interfaces in `frontend/lib/src/core/`.
- Serves `riverpod-state` and `go-router-navigation`. Hands off to `riverpod-unit-tester`. Does not delegate.

## Outputs and completion
Registered dependencies (interface → implementation → lifecycle), versions checked, `build_runner`, `dart analyze` and `riverpod_lint` output.

## Escalation
Ask before adding a new package or when the desired lifecycle of a resource is unclear.
